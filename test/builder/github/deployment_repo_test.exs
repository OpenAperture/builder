defmodule OpenAperture.Builder.DeploymentRepo.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.SourceRepo

  alias OpenAperture.WorkflowOrchestratorApi.Workflow

  setup do
    #:meck.new(Github, [:passthrough])
    #:meck.expect(Github, :clone, fn _ -> :ok end)
    #:meck.expect(Github, :checkout, fn _ -> :ok end)

    deploy_repo = %DeploymentRepo{
      docker_repo_name: "testreponame"
    }

    on_exit fn ->
      :meck.unload
    end

    {:ok, deploy_repo: deploy_repo}
  end

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
end