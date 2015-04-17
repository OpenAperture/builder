defmodule OpenAperture.Builder.AllRepos.Test do
  use ExUnit.Case, async: true

  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Builder.DockerfileRepo

  alias OpenAperture.Builder.Github
  alias OpenAperture.Builder.Docker

  # setup do
  #   repo = SourceRepo.create!(%{ 
  #     repo: "myorg/myrepo", 
  #     repo_branch: "master"
  #   }) 

  #   deploy_repo = DeploymentRepo.create!(%{ 
  #     docker_repo: "myorg/myrepo_docker",
  #     docker_repo_branch: "master"
  #   })

  #   {:ok, repo: repo, deploy_repo: deploy_repo}
  # end

  # test "get_deployment_repo(pid) returns proper JSON if cloudos.json is OK", %{repo: repo} do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :exists?, fn _ -> true end)
  #   :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
  #     deployments: %{
  #       docker_repo: "myorg/myrepo_docker",
  #       docker_repo_branch: "master"
  #     }
  #   }) end)
  #   :meck.expect(File, :ls!, fn _ -> [] end)
    
  #   {:ok, pid} = SourceRepo.get_deployment_repo(repo)
  #   assert is_pid pid
  # after
  #   :meck.unload(File)
  # end

  # test "get_deployment_repo(repo) returns an error when cloudos.json is invalid ", %{repo: repo} do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :exists?, fn _ -> true end)
  #   :meck.expect(File, :read!, fn _ -> "this isn't actually json" end)

  #   # bad json
  #   {result, message} = SourceRepo.get_deployment_repo(repo)
  #   assert result  == :error
  #   assert message == "cloudos.json is either missing or invalid!"

  # after
  #   :meck.unload(File)
  # end

  # test "get_deployment_repo(repo) returns an error when repo is missing ", %{repo: repo} do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :exists?, fn _ -> true end)
  #   :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
  #     :deployments => 
  #       %{
  #         docker_repo_branch: "master"
  #     }      
  #   }) end)

  #   # no repo
  #   {result, message} = SourceRepo.get_deployment_repo(repo)
  #   assert result  == :error
  #   assert message == "cloudos.json is invalid! Make sure both the repo and default branch are specified"
  # after
  #   :meck.unload(File)      
  # end  

  # test "get_deployment_repo(repo) returns an error when file is missing ", %{repo: repo} do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :exists?, fn _ -> false end)

  #   # no file
  #   {result, message} = SourceRepo.get_deployment_repo(repo)
  #   assert result  == :error
  #   assert message == "cloudos.json is either missing or invalid!"
  # after
  #   :meck.unload(File)
  # end

  # test "get_deployment_repo(repo) returns ok when branch is missing ", %{repo: repo} do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :exists?, fn _ -> true end)
  #   :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
  #     :deployments => 
  #       %{
  #         docker_repo: "myorg/myrepo"
  #     }
  #   }) end)

  #   # no branch
  #   {result, repo} = SourceRepo.get_deployment_repo(repo)
  #   assert result  == :ok
  #   assert is_pid repo
  # after
  #   :meck.unload(File)
  # end  

  # test "get_deployment_repo(repo) returns ok", %{repo: repo} do
  #   :meck.new(File, [:unstick])
  #   :meck.expect(File, :exists?, fn _ -> true end)
  #   :meck.expect(File, :read!, fn _ -> JSON.encode!(%{
  #     :deployments => 
  #       %{
  #         docker_repo: "myorg/myrepo",
  #         docker_repo_branch: "dev"
  #     }
  #   }) end)

  #   {result, repo} = SourceRepo.get_deployment_repo(repo)
  #   assert result  == :ok
  #   assert is_pid repo
  # after
  #   :meck.unload(File)
  # end  

end