require Logger

defmodule OpenAperture.Builder.Milestones.Build do

  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Request, as: BuilderRequest

  @moduledoc """
  This module contains the logic for the "Build" Workflow milestone
  """  

  @doc """
  Method to wrap the execute call in a check that kills the docker build if the workflow is manually killed
  Agent contains the request and then :completed when the request completes
  
  """
  @spec execute(BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute(request) do
    IO.puts "request outside task:"
    IO.inspect request
    {:ok, agent_pid} = Agent.start_link(fn -> request end)
    task = Task.async(fn ->
        req = Agent.get(agent_pid, &(&1))
        IO.puts "request inside task:"
        IO.inspect req
        tmp = execute_internal(req)
        Agent.update(agent_pid, fn _ -> :completed end)
        tmp
      end)
    monitor_build(agent_pid, task.pid, request)
  end

  @spec monitor_build(pid, pid, BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  defp monitor_build(agent_pid, task_pid, request) do
    :timer.sleep(10000)
    case Agent.get(agent_pid, &(&1)) do
      :completed  -> Task.await(task_pid, 5000)
      _ ->
        case workflow_error?(request) do
          false -> monitor_build(agent_pid, task_pid, request)
          true  ->
            case Agent.get(agent_pid, &(&1)) do
              :completed  -> Task.await(task_pid, 5000)
              _ ->
                Process.exit(task_pid, :kill)
                {:error, "Workflow is in error state", request}
            end
        end
    end
  end

  @spec workflow_error?(BuilderRequest.t) :: true | false
  defp workflow_error?(request) do
    case OpenAperture.ManagerApi.Workflow.get_workflow(request.workflow.id).body.workflow_error do
      true -> true
      _ -> false
    end
  end

  @spec execute_internal(BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  defp execute_internal(request) do
    Logger.info ("Beginning docker image build of #{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}...")    
    case DeploymentRepo.create_docker_image(request.deployment_repo, "#{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}") do
      {:ok, status_messages} -> 
        request = Enum.reduce status_messages, request, fn(status_message, request) ->
          BuilderRequest.publish_success_notification(request, status_message)
        end
        
        {:ok, request}
      {:error, reason, status_messages} -> 
        request = Enum.reduce status_messages, request, fn(status_message, request) ->
          BuilderRequest.publish_success_notification(request, status_message)
        end        
        {:error, "Failed to build docker image #{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}:  #{inspect reason}", request}
    end
  end
end