require Logger
require Timex.Date

defmodule OpenAperture.Builder.Milestones.Config do
  use Timex
  
  alias OpenAperture.Builder.Request, as: BuilderRequest
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.WorkflowOrchestratorApi.Workflow

  @moduledoc """
  This module contains the logic for the "Config" Workflow milestone
  """    

  @doc """
  Method to execute the milestone

  ## Options

  The `builder_request` option defines the Map containing the BuilderRequest

  ## Return Values

  {:ok, BuilderRequest} | {:error, String.t, BuilderRequest}
  """
  @spec execute(BuilderRequest) :: {:ok, BuilderRequest} | {:error, String.t, BuilderRequest}
  def execute(builder_request) do
    case get_source_repo_ref(builder_request) do
      {:error, builder_request, reason} ->
        {:error, builder_request, reason}
      {:ok, builder_request} ->
        builder_request = set_notifications_config(builder_request)
        builder_request = BuilderRequest.set_fleet_config(builder_request, DeploymentRepo.get_fleet_config!(builder_request.deployment_repo))
        builder_request = BuilderRequest.set_aws_config(builder_request, DeploymentRepo.get_aws_config!(builder_request.deployment_repo))        
        builder_request = BuilderRequest.publish_success_notification(builder_request, "Requesting configuration of repository #{builder_request.workflow.deployment_repo}...")
        builder_request = BuilderRequest.save_workflow(builder_request)
        do_resolve_files(builder_request)
    end
  end

  defp get_source_repo_ref(builder_request) do
    source_ref = case builder_request.deployment_repo.source_repo do
      nil ->
        builder_request.workflow.source_repo_git_ref
      _ ->
        Logger.debug "Checking source repo for current commit hash"
        new_ref = SourceRepo.get_current_commit_hash!(builder_request.deployment_repo.source_repo)
        if new_ref == builder_request.workflow.source_repo_git_ref do
          Logger.debug "Source repo commit hash matches builder request workflow git ref: #{builder_request.workflow.source_repo_git_ref}"
          builder_request.workflow.source_repo_git_ref
        else
          msg = "Git commit hash resolved from checkout: #{builder_request.workflow.source_repo_git_ref} -> #{new_ref}"
          Logger.debug msg
          orchestrator_request = Workflow.add_event_to_log(builder_request.orchestrator_request, msg)
          builder_request = %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow}
          new_ref
        end
    end
    if source_ref == nil || String.length(source_ref) == 0 do
      {:error, builder_request, "Missing source_repo_git_ref"}
    else
      orchestrator_request = builder_request.orchestrator_request
      orchestrator_request = update_in(orchestrator_request.workflow.source_repo_git_ref, fn _ -> source_ref end)
      builder_request = %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow}
      {:ok, builder_request}
    end
  end

  defp set_notifications_config(builder_request) do
    unless builder_request.deployment_repo.source_repo == nil do
      case SourceRepo.get_openaperture_info(builder_request.deployment_repo.source_repo) do
        nil -> builder_request
        info -> BuilderRequest.set_notifications_config(builder_request, info["deployments"]["notifications"])
      end
    else
      builder_request
    end
  end

  def do_resolve_files(builder_request) do
    dockerfile_commit_required = DeploymentRepo.resolve_dockerfile_template(builder_request.deployment_repo, [commit_hash: builder_request.workflow.source_repo_git_ref, timestamp: get_timestamp])
    units_commit_required = DeploymentRepo.resolve_service_file_templates(builder_request.deployment_repo, [commit_hash: builder_request.workflow.source_repo_git_ref, timestamp: get_timestamp, dst_port: "<%= dst_port %>"])

    if (dockerfile_commit_required || units_commit_required) do
      case DeploymentRepo.checkin_pending_changes(builder_request.deployment_repo, "Deployment for commit #{builder_request.workflow.source_repo_git_ref}") do
        :ok -> {:ok, builder_request}
        {:error, reason} -> {:error, "Failed to commit changes:  #{inspect reason}", builder_request}
      end
    else
      Logger.debug ("There are no files to commit (templating required no file changes)")
      {:ok, builder_request}
    end
  end

  @spec get_timestamp() :: String.t()
  defp get_timestamp() do
    date = Date.now()
    DateFormat.format!(date, "{RFC1123}")
  end  
end