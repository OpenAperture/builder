defmodule OpenAperture.Builder.Milestones.VerifyBuildExists do
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.Request, as: BuilderRequest
  alias OpenAperture.WorkflowOrchestratorApi.Workflow

  @spec execute(BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute(request) do
	tag = "#{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}"
	:ok = Docker.cleanup_image(request.deployment_repo.docker_repo, tag)
	case Docker.pull(request.deployment_repo.docker_repo, tag) do
        :ok -> 
          {:ok, add_message(request, "Verified #{tag} exists in docker hub")}
        {:error, error_msg} ->
          {:error, "Docker image (#{tag}) not found in docker hub: #{error_msg}", request}
    end
  end

  defp add_message(request, msg) do
  	orchestrator_request = Workflow.add_event_to_log(request.orchestrator_request, msg)
    %{request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow}          
  end
end