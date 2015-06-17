defmodule OpenAperture.Builder.DeploymentRepo.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.DockerHosts
  alias OpenAperture.Builder.Git
  alias OpenAperture.Builder.GitRepo, as: GitRepo
  alias OpenAperture.Builder.Request, as: BuilderRequest

  alias OpenAperture.Fleet.ServiceFileParser

  alias OpenAperture.WorkflowOrchestratorApi.Workflow
  alias OpenAperture.WorkflowOrchestratorApi.Request

  setup do
    deploy_repo = %DeploymentRepo{
      docker_repo_name: "testreponame",
      docker_build_etcd_token: "123abc",
      output_dir: "/tmp",
      github_deployment_repo: %GitRepo{}
    }

    workflow = %Workflow{}

    request = %Request{
      workflow: workflow
    }

    on_exit fn ->
      :meck.unload
    end

    {:ok, deploy_repo: deploy_repo, workflow: workflow, request: request}
  end

  #========================
  # init_from_request tests

  test "init_from_request - actual request" do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn path -> 
      cond do
        String.ends_with?(path, "source.json") ->
          Poison.encode!(%{
            source_repo: "myorg/myrepo", 
            source_repo_git_ref: "master"
          }) 
        String.ends_with?(path, "etcd.json") ->
          Poison.encode!(%{
            token: "123abc"
          })         
        String.ends_with?(path, "docker.json") ->
          Poison.encode!(%{
            docker_url: "testorg/testrepo"
          })                   
        true ->
          ""
      end
    end)
    :meck.expect(File, :ls!, fn _ -> [] end)

    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ ->
                                        {:ok, pid} = Agent.start_link(fn -> %{} end)
                                        pid
                                       end) 

    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)

    payload = %{
      current_step: :build,
      deployable_units: nil,
      deployment_repo: "testorg/testrepo_docker",
      deployment_repo_git_ref: "master",
      docker_build_etcd_token: "123abc",
      elapsed_step_time: nil,
      elapsed_workflow_time: nil,
      etcd_token: nil,
      event_log: [
          "[OpenAperture Workflow][aecc9150-000000000000] Starting workflow...",
          "[OpenAperture Workflow][aecc9150-000000000000] Starting Workflow Milestone:  :build"
      ],
      force_build: nil,
      id: "aecc9150--000000000000",
      milestones: [
          "build",
          "deploy"
      ],
      notifications_broker_id: "1",
      notifications_config: nil,
      notifications_exchange_id: "1",
      orchestration_queue_name: "workflow_orchestration",
      source_commit_hash: nil,
      source_repo: "testorg/testrepo",
      source_repo_git_ref: "master",
      workflow_completed: false,
      workflow_duration: nil,
      workflow_error: nil,
      workflow_id: nil,
      workflow_orchestration_broker_id: "1",
      workflow_orchestration_exchange_id: "1",
      workflow_step_durations: nil
    }

    builder_request = BuilderRequest.from_payload(payload)
    builder_request = %{builder_request | delivery_tag: "delivery_tag"}

    {:ok, repo} = DeploymentRepo.init_from_request(builder_request.orchestrator_request)
    assert repo != nil
  after
    :meck.unload(File)
    :meck.unload(Git)
    :meck.unload(GitRepo)
    :meck.unload(SourceRepo)
    :meck.unload(DockerHosts)
  end

  test "init_from_request - no deployment_repo", %{request: request} do
    workflow = %{request.workflow | source_repo_git_ref: "123abc"} 
    request = %{request | workflow: workflow}

    assert DeploymentRepo.init_from_request(request) == {:error, "Missing deployment_repo"}
  end

  test "init_from_request - download failed", %{request: request} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> {:error, "bad news bears"} end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    workflow = %{request.workflow | source_repo_git_ref: "123abc"} 
    workflow = %{workflow | deployment_repo: "myorg/myrepo"} 
    request = %{request | workflow: workflow}
    
    {:error, message} = DeploymentRepo.init_from_request(request)
    assert message != nil
  after
    :meck.unload(Git)
    :meck.unload(GitRepo)    
  end

  test "init_from_request - populate_source_repo failed", %{request: request} do 
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    workflow = %{request.workflow | source_repo_git_ref: "123abc"} 
    workflow = %{workflow | deployment_repo: "myorg/myrepo"} 
    request = %{request | workflow: workflow}

    {:error, message} = DeploymentRepo.init_from_request(request)
    assert message != nil
  after
    :meck.unload(Git)
    :meck.unload(GitRepo)
  end

  test "init_from_request - populate_etcd_token failed", %{request: request} do 
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    workflow = %{request.workflow | source_repo_git_ref: "123abc"} 
    workflow = %{workflow | deployment_repo: "myorg/myrepo"} 
    request = %{request | workflow: workflow}

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
      source_repo: "myorg/myrepo", 
      source_repo_git_ref: "master"
    }) end)
    :meck.expect(File, :ls!, fn _ -> [] end)
    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ ->
                                        {:ok, pid} = Agent.start_link(fn -> %{} end)
                                        pid
                                       end)    

    {:error, message} = DeploymentRepo.init_from_request(request)
    assert message != nil
  after
    :meck.unload(Git)
    :meck.unload(GitRepo)
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end

  test "init_from_request - populate_docker_repo_name failed", %{request: request} do 
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    workflow = %{request.workflow | source_repo_git_ref: "123abc"} 
    workflow = %{workflow | deployment_repo: "myorg/myrepo"} 
    request = %{request | workflow: workflow}

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn path -> 
      cond do
        String.ends_with?(path, "source.json") ->
          Poison.encode!(%{
            source_repo: "myorg/myrepo", 
            source_repo_git_ref: "master"
          }) 
        String.ends_with?(path, "etcd.json") ->
          Poison.encode!(%{
            token: "123abc"
          })         
        true ->
          ""
      end
    end)
    :meck.expect(File, :ls!, fn _ -> [] end)
    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ ->
                                        {:ok, pid} = Agent.start_link(fn -> %{} end)
                                        pid
                                       end)    

    {:error, message} = DeploymentRepo.init_from_request(request)
    assert message != nil
  after
    :meck.unload(Git)
    :meck.unload(GitRepo)
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end

  test "init_from_request - success", %{request: request} do 
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    workflow = %{request.workflow | source_repo_git_ref: "123abc"} 
    workflow = %{workflow | deployment_repo: "myorg/myrepo"} 
    request = %{request | workflow: workflow}
    request = %{request | docker_build_etcd_token: "build_cluster"}

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn path -> 
      cond do
        String.ends_with?(path, "source.json") ->
          Poison.encode!(%{
            source_repo: "myorg/myrepo", 
            source_repo_git_ref: "master"
          }) 
        String.ends_with?(path, "etcd.json") ->
          Poison.encode!(%{
            token: "123abc"
          })   
        String.ends_with?(path, "docker.json") ->
          Poison.encode!(%{
            docker_url: "testorg/testrepo"
          })                   
        true ->
          ""
      end
    end)
    :meck.expect(File, :ls!, fn _ -> [] end)
    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ ->
                                        {:ok, pid} = Agent.start_link(fn -> %{} end)
                                        pid
                                       end)    

    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)

    {:ok, repo} = DeploymentRepo.init_from_request(request)
    assert repo != nil
  after
    :meck.unload(Git)
    :meck.unload(GitRepo)
    :meck.unload(File)
    :meck.unload(SourceRepo)
    :meck.unload(DockerHosts)
  end

  #========================
  # get_docker_repo_name tests

  test "get_docker_repo_name(repo) file does not exist" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)
    
    assert_raise RuntimeError,
                 "Unable to get the docker repo name, docker_repo_name not specified and /docker.json does not exist!",
                 fn -> %DeploymentRepo{} |> DeploymentRepo.populate_docker_repo_name! end
  after
    :meck.unload(File)
  end

  test "get_docker_repo_name(repo) bad json" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "this is not json" end)

    assert_raise RuntimeError,
                 "{:unexpected_token, \"this is not json\"}",
                 fn -> %DeploymentRepo{} |> DeploymentRepo.populate_docker_repo_name! end
  after
    :meck.unload(File)
  end

  test "get_docker_repo_name(repo) success" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> JSON.encode!(%{docker_url: "testreponame"}) end)

    docker_repo_name = DeploymentRepo.populate_docker_repo_name!(%DeploymentRepo{})
    assert docker_repo_name == "testreponame"
  after
    :meck.unload(File)
  end  

  test "get_docker_repo_name(repo) not in json" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> JSON.encode!(%{}) end)

    assert_raise RuntimeError,
                 "Unable to get the docker repo name, docker_repo_name not specified and docker_url not specified in docker.json",
                 fn -> %DeploymentRepo{} |> DeploymentRepo.populate_docker_repo_name! end
  after
    :meck.unload(File)
  end  

  test "get_source_repo(repo) returns the PID of created SourceRepo 
    instance when source.json is OK", %{deploy_repo: deploy_repo} do

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
      source_repo: "myorg/myrepo", 
      source_repo_git_ref: "master"
    }) end)
    :meck.expect(File, :ls!, fn _ -> [] end)
    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ ->
                                        {:ok, pid} = Agent.start_link(fn -> %{} end)
                                        pid
                                       end)

    source_repo = DeploymentRepo.populate_source_repo!(deploy_repo, %Workflow{})
    assert is_pid source_repo
  after
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end  

  test "get_source_repo(repo) returns an error when source.json is invalid json",
    %{deploy_repo: deploy_repo} do

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "this isn't actually json" end)

    assert_raise RuntimeError,
                 "An error occurred parsing source.json JSON! {:unexpected_token, \"this isn't actually json\"}",
                 fn -> DeploymentRepo.populate_source_repo!(deploy_repo, %Workflow{}) end
  after
    :meck.unload(File)   
  end   

  test "get_source_repo(repo) returns :ok when source.json has no branch",
    %{deploy_repo: deploy_repo} do

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
      source_repo: "myorg/myrepo"
    }) end)

    :meck.expect(SourceRepo, :create!, fn _,_,_ ->
                                        {:ok, pid} = Agent.start_link(fn -> %{} end)
                                        pid
                                       end)    

    # no branch
    source_repo = DeploymentRepo.populate_source_repo!(deploy_repo, %Workflow{})
    assert is_pid source_repo
  after
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end

  #========================
  # cleanup tests

  test "cleanup", %{deploy_repo: deploy_repo} do

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :rm_rf, fn _ -> :ok end)
 
    DeploymentRepo.cleanup(deploy_repo)
  after
    :meck.unload(File)
  end

  #========================
  # download! tests

  test "download! - success", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    repo = DeploymentRepo.download!(deploy_repo, workflow)
    assert repo != nil
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)
  end

  test "download! - clone fails", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> {:error, "bad news bears"} end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    assert_raise RuntimeError,
                 "bad news bears",
                 fn -> DeploymentRepo.download!(deploy_repo, workflow) end    
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)
  end

  test "download! - checkout fails", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> {:error, "bad news bears"} end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    assert_raise RuntimeError,
                 "bad news bears",
                 fn -> DeploymentRepo.download!(deploy_repo, workflow) end    
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)
  end  

  #========================
  # populate_source_repo! tests

  test "populate_source_repo! - success from file", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      source_repo: "https://github.com/OpenAperture/test",
      source_repo_git_ref: "123abc"
    }) end)

    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ -> %SourceRepo{} end)

    repo = DeploymentRepo.populate_source_repo!(deploy_repo, workflow)
    assert repo != nil
  after
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end

  test "populate_source_repo! - success, no source_repo_git_ref in file", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      source_repo: "https://github.com/OpenAperture/test"
    }) end)

    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ -> %SourceRepo{} end)

    repo = DeploymentRepo.populate_source_repo!(deploy_repo, workflow)
    assert repo != nil
  after
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end  

  test "populate_source_repo! - success, no file", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)

    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :create!, fn _,_,_ -> %SourceRepo{} end)

    repo = DeploymentRepo.populate_source_repo!(deploy_repo, workflow)
    assert repo == nil
  after
    :meck.unload(File)
    :meck.unload(SourceRepo)
  end  

  test "populate_source_repo! - bad json", %{deploy_repo: deploy_repo, workflow: workflow} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "https://github.com/OpenAperture/test" end)

    assert_raise RuntimeError,
                 "An error occurred parsing source.json JSON! {:unexpected_token, \"https://github.com/OpenAperture/test\"}",
                 fn -> DeploymentRepo.populate_source_repo!(deploy_repo, workflow) end
  after
    :meck.unload(File)
  end  

  #========================
  # populate_docker_repo_name! tests

  test "populate_docker_repo_name! - success", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      docker_url: "user/repo",
    }) end)

    name = DeploymentRepo.populate_docker_repo_name!(deploy_repo)
    assert name == "user/repo"
  after
    :meck.unload(File)
  end

  test "populate_docker_repo_name! - no json entry", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      source_repo: "https://github.com/OpenAperture/test"
    }) end)

    assert_raise RuntimeError,
                 "Unable to get the docker repo name, docker_repo_name not specified and docker_url not specified in docker.json",
                 fn -> DeploymentRepo.populate_docker_repo_name!(deploy_repo) end
  after
    :meck.unload(File)
  end   

  test "populate_docker_repo_name! - bad json", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "user/repo" end)

    assert_raise RuntimeError,
                 "{:unexpected_token, \"user/repo\"}",
                 fn -> DeploymentRepo.populate_docker_repo_name!(deploy_repo) end
  after
    :meck.unload(File)
  end  

  #========================
  # populate_docker_repo_name! tests

  test "populate_docker_repo! - no file, default to dockerhub", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)

    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)

    repo = DeploymentRepo.populate_docker_repo!(deploy_repo)
    assert repo != nil
    assert repo.output_dir != nil
    assert repo.docker_repo_url != nil
    assert repo.docker_host != nil
    assert repo.registry_url != nil
    assert repo.registry_username != nil
    assert repo.registry_email != nil
    assert repo.registry_password != nil   
  after
    :meck.unload(File)
    :meck.unload(DockerHosts)
  end

  test "populate_docker_repo! - file with no entry, default to dockerhub", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      docker_url: "user/repo",
    }) end)

    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)

    repo = DeploymentRepo.populate_docker_repo!(deploy_repo)
    assert repo != nil
    assert repo.output_dir != nil
    assert repo.docker_repo_url != nil
    assert repo.docker_host != nil
    assert repo.registry_url != nil
    assert repo.registry_username != nil
    assert repo.registry_email != nil
    assert repo.registry_password != nil   
  after
    :meck.unload(File)
    :meck.unload(DockerHosts)
  end

  test "populate_docker_repo! - invalid file, default to dockerhub", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "user/repo" end)

    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)    

    repo = DeploymentRepo.populate_docker_repo!(deploy_repo)
    assert repo != nil
    assert repo.output_dir != nil
    assert repo.docker_repo_url != nil
    assert repo.docker_host != nil
    assert repo.registry_url != nil
    assert repo.registry_username != nil
    assert repo.registry_email != nil
    assert repo.registry_password != nil   
  after
    :meck.unload(File)
    :meck.unload(DockerHosts)
  end  

  test "populate_docker_repo! - valid file", %{deploy_repo: deploy_repo} do
    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      docker_registry_url: "docker_registry_url",
      docker_registry_username: "docker_registry_username",
      docker_registry_email: "docker_registry_email",
      docker_registry_password: "docker_registry_password"
    }) end)

    repo = DeploymentRepo.populate_docker_repo!(deploy_repo)
    assert repo != nil
    assert repo.output_dir != nil
    assert repo.docker_repo_url != nil
    assert repo.docker_host != nil
    assert repo.registry_url != nil
    assert repo.registry_username != nil
    assert repo.registry_email != nil
    assert repo.registry_password != nil   
  after
    :meck.unload(File)
    :meck.unload(DockerHosts)
  end  

  test "populate_docker_repo! - file missing data", %{deploy_repo: deploy_repo} do
    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:ok, "123.456.789.0123"} end)

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      docker_registry_url: "docker_registry_url",
    }) end)

    assert_raise RuntimeError,
                 "Missing registry_username",
                 fn -> DeploymentRepo.populate_docker_repo!(deploy_repo) end

  after
    :meck.unload(File)
    :meck.unload(DockerHosts)
  end

  test "populate_docker_repo! - docker host resolution fails", %{deploy_repo: deploy_repo} do
    :meck.new(DockerHosts, [:passthrough])
    :meck.expect(DockerHosts, :next_available, fn _ -> {:error, "bad news bears"} end)

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
      docker_registry_url: "docker_registry_url",
    }) end)

    assert_raise RuntimeError,
                 "Failed to resolve docker host for etcd cluster 123abc:  \"bad news bears\"",
                 fn -> DeploymentRepo.populate_docker_repo!(deploy_repo) end

  after
    :meck.unload(File)
    :meck.unload(DockerHosts)
  end  

  #========================
  # resolve_dockerfile_template tests

  test "resolve_dockerfile_template - no files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)

    assert DeploymentRepo.resolve_dockerfile_template(deploy_repo, []) == false
  after
    :meck.unload(File)
  end

  test "resolve_dockerfile_template - identical files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "123abc" end)
    :meck.expect(File, :write!, fn _,_ -> :ok end)

    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :add, fn _,_ -> :ok end)

    assert DeploymentRepo.resolve_dockerfile_template(deploy_repo, []) == false
  after
    :meck.unload(File)
    :meck.unload(Git)
  end  

  #========================
  # resolve_service_file_templates tests

  test "resolve_service_file_templates - no files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :ls, fn _ -> {:ok, []} end)

    assert DeploymentRepo.resolve_service_file_templates(deploy_repo, []) == false
  after
    :meck.unload(File)
  end

  test "resolve_service_file_templates - no service files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :ls, fn _ -> {:ok, ["junk.txt"]} end)

    assert DeploymentRepo.resolve_service_file_templates(deploy_repo, []) == false
  after
    :meck.unload(File)
  end

  test "resolve_service_file_templates - identical files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :ls, fn _ -> {:ok, ["my@.service.eex"]} end)
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "123abc" end)
    :meck.expect(File, :write!, fn _,_ -> :ok end)

    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :add, fn _,_ -> :ok end)

    assert DeploymentRepo.resolve_service_file_templates(deploy_repo, []) == false
  after
    :meck.unload(File)
    :meck.unload(Git)
  end  

  #========================
  # checkin_pending_changes tests

  test "checkin_pending_changes - success", %{deploy_repo: deploy_repo} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :commit, fn _,_ -> :ok end)
    :meck.expect(Git, :push, fn _ -> :ok end)

    assert DeploymentRepo.checkin_pending_changes(deploy_repo, "test changes") == :ok
  after
    :meck.unload(Git)
  end  

  test "checkin_pending_changes - push fails", %{deploy_repo: deploy_repo} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :commit, fn _,_ -> :ok end)
    :meck.expect(Git, :push, fn _ -> {:error, "bad news bears"} end)

    assert DeploymentRepo.checkin_pending_changes(deploy_repo, "test changes") == {:error, "bad news bears"}
  after
    :meck.unload(Git)
  end    

  test "checkin_pending_changes - commit fails", %{deploy_repo: deploy_repo} do
    :meck.new(Git, [:passthrough])
    :meck.expect(Git, :commit, fn _,_ -> {:error, "bad news bears"} end)

    assert DeploymentRepo.checkin_pending_changes(deploy_repo, "test changes") == {:error, "bad news bears"}
  after
    :meck.unload(Git)
  end      

  #========================
  # get_units tests

  test "get_units - no files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :ls, fn _ -> {:ok, []} end)

    assert DeploymentRepo.get_units(deploy_repo) == []
  after
    :meck.unload(File)
  end

  test "get_units - no service files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :ls, fn _ -> {:ok, ["junk.txt"]} end)

    assert DeploymentRepo.get_units(deploy_repo) == []
  after
    :meck.unload(File)
  end

  test "get_units - service files", %{deploy_repo: deploy_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :ls, fn _ -> {:ok, ["my@.service"]} end)

    :meck.new(ServiceFileParser, [:passthrough])
    :meck.expect(ServiceFileParser, :parse_unit, fn _,_ -> %OpenAperture.Fleet.SystemdUnit{name: "my@.service"} end)

    returned_units = DeploymentRepo.get_units(deploy_repo) 
    assert returned_units != nil
    assert length(returned_units) == 1

    returned_unit = List.first(returned_units)
    assert returned_unit != nil
    assert returned_unit.name == "my@.service"
    assert returned_unit.options == nil
  after
    :meck.unload(File)
    :meck.unload(ServiceFileParser)
  end  

  #========================
  # create_docker_image tests

  test "create_docker_image - force build fails", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :build, fn _ -> {:error, "bad news bears"} end)

    deploy_repo = %{deploy_repo | force_build: true}
    {:error, reason, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert reason == "bad news bears"
    assert length(status_messages) > 0
  after
    :meck.unload(Docker)
  end  

  test "create_docker_image - force build produces bad image", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :build, fn _ -> {:ok, ""} end)
    :meck.expect(Docker, :cleanup_image_cache, fn _,_ -> :ok end)

    deploy_repo = %{deploy_repo | force_build: true}
    {:error, reason, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert reason == "Docker build failed to produce a valid image!"
    assert length(status_messages) > 0    
  after
    :meck.unload(Docker)
  end

  test "create_docker_image - force build tag fails", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :build, fn _ -> {:ok, "123"} end)
    :meck.expect(Docker, :tag, fn _,_,_ -> {:error, "bad news bears"} end)
    :meck.expect(Docker, :cleanup_image_cache, fn _,_ -> :ok end)

    deploy_repo = %{deploy_repo | force_build: true}
    {:error, reason, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert reason == "bad news bears"
    assert length(status_messages) > 0
  after
    :meck.unload(Docker)
  end

  test "create_docker_image - force build push fails", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :build, fn _ -> {:ok, "123"} end)
    :meck.expect(Docker, :tag, fn _,_,_ -> {:ok, "123"} end)
    :meck.expect(Docker, :push, fn _ -> {:error, "bad news bears"} end)
    :meck.expect(Docker, :cleanup_image_cache, fn _,_ -> :ok end)

    deploy_repo = %{deploy_repo | force_build: true}
    deploy_repo = %{deploy_repo | docker_repo: %Docker{
        registry_url: Application.get_env(:openaperture_builder, :docker_registry_url),
      }
    }    
    {:error, reason, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert reason == "bad news bears"
    assert length(status_messages) > 0
  after
    :meck.unload(Docker)
  end

  test "create_docker_image - force build success", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :build, fn _ -> {:ok, "123"} end)
    :meck.expect(Docker, :tag, fn _,_,_ -> {:ok, "123"} end)
    :meck.expect(Docker, :push, fn _ -> {:ok, "123"} end)
    :meck.expect(Docker, :cleanup_image_cache, fn _,_ -> :ok end)

    deploy_repo = %{deploy_repo | force_build: true}
    deploy_repo = %{deploy_repo | docker_repo: %Docker{
        registry_url: Application.get_env(:openaperture_builder, :docker_registry_url),
      }
    }    
    {:ok, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert length(status_messages) > 0
  after
    :meck.unload(Docker)
  end  

  test "create_docker_image - build success", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :pull, fn _,_ -> {:error, "image does not exist"} end)
    :meck.expect(Docker, :build, fn _ -> {:ok, "123"} end)
    :meck.expect(Docker, :tag, fn _,_,_ -> {:ok, "123"} end)
    :meck.expect(Docker, :push, fn _ -> {:ok, "123"} end)
    :meck.expect(Docker, :cleanup_image_cache, fn _,_ -> :ok end)

    deploy_repo = %{deploy_repo | force_build: false}
    deploy_repo = %{deploy_repo | docker_repo: %Docker{
        registry_url: Application.get_env(:openaperture_builder, :docker_registry_url),
      }
    }

    {:ok, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert length(status_messages) > 0
  after
    :meck.unload(Docker)
  end  

  test "create_docker_image - build cache success", %{deploy_repo: deploy_repo} do
    :meck.new(Docker, [:passthrough])
    :meck.expect(Docker, :pull, fn _,_ -> :ok end)
    :meck.expect(Docker, :cleanup_image_cache, fn _,_ -> :ok end)

    deploy_repo = %{deploy_repo | force_build: false}
    {:ok, status_messages} = DeploymentRepo.create_docker_image(deploy_repo, "tag")
    assert length(status_messages) > 0    
  after
    :meck.unload(Docker)
  end  

  #=============================
  # populate_etcd_token! tests

  test "populate_etcd_token! - success", %{deploy_repo: deploy_repo} do 
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn path -> 
      cond do
        String.ends_with?(path, "etcd.json") ->
          Poison.encode!(%{
            token: "123abc"
          })   
               
        true ->
          ""
      end
    end)

    "123abc" == DeploymentRepo.populate_etcd_token!(deploy_repo)
  after
    :meck.unload(File)
  end

  test "populate_etcd_token! - failure", %{deploy_repo: deploy_repo} do 
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)

    assert_raise RuntimeError,
                 "No etcd JSON file is present in this repository!",
                 fn -> DeploymentRepo.populate_etcd_token!(deploy_repo) end    
  after
    :meck.unload(File)
  end  

  #========================
  # get_fleet_config tests

  test "get_fleet_config(repo) file does not exist" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)
    
    assert DeploymentRepo.get_fleet_config!(%DeploymentRepo{}) == nil
  after
    :meck.unload(File)
  end

  test "get_fleet_config(repo) bad json" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "this is not json" end)

    assert_raise RuntimeError,
                 "An error occurred parsing Fleet JSON!  {:unexpected_token, \"this is not json\"}",
                 fn -> %DeploymentRepo{} |> DeploymentRepo.get_fleet_config! end
  after
    :meck.unload(File)
  end

  test "get_fleet_config(repo) success" do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> JSON.encode!(%{instance_cnt: 10}) end)

    config = DeploymentRepo.get_fleet_config!(%DeploymentRepo{})
    assert config["instance_cnt"] == 10
  after
    :meck.unload(File)
  end   
end