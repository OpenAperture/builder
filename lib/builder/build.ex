require Logger

defmodule OpenAperture.Builder.Build do
	use GenServer

  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Workflow

  @spec start_link :: {:ok, pid} | {:error, String.t}
	def start_link do
		GenServer.start_link(__MODULE__, nil)
	end

  @spec build(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, String.t()}
  def build(deploy_repo) do
    GenServer.call(__MODULE__, {:build, deploy_repo})
  end

  @spec handle_call(term, term, term) :: {:ok, DeploymentRepo} | {:error, String.t()}
  def handle_call({:build, deploy_repo}, _from, state) do
    {:reply, build_impl(deploy_repo), state}
  end

  @spec build_impl(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, String.t}
  defp build_impl(deploy_repo) do
    cloudos_workflow   = "workflow"
		Logger.info ("Beginning docker image build of #{deploy_repo.docker_repo_name}:#{deploy_repo.source_repo_git_ref}...")
    
    case DeploymentRepo.create_docker_image(deploy_repo, ["#{deploy_repo.docker_repo_name}:#{deploy_repo.source_repo_git_ref}"]) do
      {:ok, deploy_repo} ->
        Workflow.next_step(cloudos_workflow, %{})
        {:ok, deploy_repo}
      {:error, reason} -> 
        Logger.info("Failed to build docker image #{deploy_repo.docker_repo_name}:#{deploy_repo.source_repo_git_ref}:  #{inspect reason}")
        Workflow.step_failed(cloudos_workflow, "Failed to create the docker image:  #{inspect reason}", reason)
        {:error, reason}
    end
	end

end