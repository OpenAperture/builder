require Logger

defmodule OpenAperture.Builder.Milestones.Build do

  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Request, as: BuilderRequest
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.BuildLogPublisher

  @moduledoc """
  This module contains the logic for the "Build" Workflow milestone
  """  

  @doc """
  Method to wrap the execute call in a check that kills the docker build if the workflow is manually killed
  Agent contains the request and then :completed when the request completes
  
  """
  @spec execute(BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute(request) do
    execute_internal(request)
  end

  @spec workflow_error?(BuilderRequest.t) :: true | false
  defp workflow_error?(request) do
    case OpenAperture.ManagerApi.Workflow.get_workflow(request.workflow.id).body["workflow_error"] do
      true -> true
      _ -> false
    end
  end

  @spec execute_internal(BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  defp execute_internal(request) do
    request = start_build_output_monitor request
    try do    
      request = BuilderRequest.publish_success_notification(request, "Beginning docker image build of #{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref} on docker host #{request.deployment_repo.docker_repo.docker_host}...")
      request = BuilderRequest.save_workflow(request)
      case DeploymentRepo.create_docker_image(
        request.deployment_repo, 
        "#{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}",
        fn -> 
          if !workflow_error?(request) do
            :timer.sleep(9_000)
            true
          else
            false
          end
        end
      ) do
        {:ok, status_messages, image_found} ->
          request = %{request | image_found: image_found}
          request = Enum.reduce status_messages, request, fn(status_message, request) ->
            BuilderRequest.publish_success_notification(request, status_message)
          end
          request = BuilderRequest.save_workflow(request)
          {:ok, request}
        {:error, reason, status_messages} -> 
          request = Enum.reduce status_messages, request, fn(status_message, request) ->
            BuilderRequest.publish_success_notification(request, status_message)
          end        
          request = BuilderRequest.save_workflow(request)
          {:error, "Failed to build docker image #{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}:  #{inspect reason}", request}
      end
    after
      end_build_output_monitor request
    end
  end

  @spec start_build_output_monitor(BuilderRequest.t) :: BuilderRequest.t
  defp start_build_output_monitor(request) do
    {:ok, stdout_pid} = Tail.start_link(Docker.log_file_from_uuid(request.deployment_repo.docker_repo.stdout_build_log_uuid), &notify_build_log(&1, request))
    {:ok, stderr_pid} = Tail.start_link(Docker.log_file_from_uuid(request.deployment_repo.docker_repo.stderr_build_log_uuid), &notify_build_log(&1, request))
    %{request | stdout_build_log_tail_pid: stdout_pid, stderr_build_log_tail_pid: stderr_pid}
  end

  @spec end_build_output_monitor(BuilderRequest.t) :: term
  defp end_build_output_monitor(request) do
    if request.stdout_build_log_tail_pid != nil do
      Tail.stop(request.stdout_build_log_tail_pid)
    else
      Logger.warn("stdout_build_log_tail_pid was nil")
    end
    if request.stderr_build_log_tail_pid != nil do
      Tail.stop(request.stderr_build_log_tail_pid)
    else
      Logger.warn("stderr_build_log_tail_pid was nil")
    end
  end

  @spec notify_build_log([String.t], BuilderRequest.t) :: term
  defp notify_build_log(msg_list, request) do
    Enum.each(msg_list, &Logger.debug("Docker Build Tail (#{length(msg_list)}): #{&1}"))
    BuildLogPublisher.publish_build_logs(request.workflow.workflow_id,
                                         msg_list)
  end
end