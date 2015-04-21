require Logger
require Timex.Date

defmodule OpenAperture.Builder.Milestones.Config do
  use Timex
  
  alias OpenAperture.WorkflowOrchestratorApi.Workflow
  alias OpenAperture.Builder.DeploymentRepo

  @moduledoc """
  This module contains the logic for the "Config" Workflow milestone
  """    

  def execute(request) do
  	request = %{request | orchestrator_request: Workflow.publish_success_notification(request.workflow, "Requesting configuration of repository #{request.workflow.deployment_repo}...")}

    dockerfile_commit_required = DeploymentRepo.resolve_dockerfile_template(request.deployment_repo, [commit_hash: request.workflow.source_repo_git_ref, timestamp: get_timestamp])
    units_commit_required = DeploymentRepo.resolve_service_file_templates(request.deployment_repo, [commit_hash: request.workflow.source_repo_git_ref, timestamp: get_timestamp, dst_port: "<%= dst_port %>"])

    if (dockerfile_commit_required || units_commit_required) do
      commit_result = case DeploymentRepo.checkin_pending_changes(request.deployment_repo, "Deployment for commit #{request.workflow.source_repo_git_ref}") do
        :ok -> {:ok, request}
        {:error, reason} -> {:error, "Failed to commit changes:  #{inspect reason}", request}
      end
    else
      Logger.debug ("There are no files to commit (templating required no file changes)")
      {:ok, request}
    end
  end

  @spec get_timestamp() :: String.t()
  defp get_timestamp() do
    date = Date.now()
    DateFormat.format!(date, "{RFC1123}")
  end  
end