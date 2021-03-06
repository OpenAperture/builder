defmodule OpenAperture.Builder.Dispatcher do
	use GenServer
  
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler

  alias OpenAperture.Builder.Request, as: BuilderRequest
  alias OpenAperture.WorkflowOrchestratorApi.Workflow
  alias OpenAperture.Builder.MessageManager
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Configuration

  alias OpenAperture.ManagerApi
  alias OpenAperture.ManagerApi.SystemEvent

  alias OpenAperture.Builder.Milestones.Config, as: ConfigMilestone
  alias OpenAperture.Builder.Milestones.Build, as: BuildMilestone
  alias OpenAperture.Builder.Milestones.VerifyBuildExists, as: VerifyBuildExistsMilestone

  alias OpenAperture.Builder.MilestoneMonitor, as: Monitor
  alias OpenAperture.WorkflowOrchestratorApi.Request, as: OrchestratorRequest

  @moduledoc """
  This module contains the logic to dispatch Builder messsages to the appropriate GenServer(s) 
  """  

  @connection_options nil
  use OpenAperture.Messaging  

  @event_data %{
                component:   :builder,
                exchange_id: Configuration.get_current_exchange_id,
                hostname:    System.get_env("HOSTNAME")
              }

  @event      %{
                unique:   true,
                type:     :unhandled_exception,
                severity: :error,
                data:     @event_data,
                message:  nil
              }
  @doc """
  Specific start_link implementation (required by the supervisor)

  ## Options

  ## Return Values

  {:ok, pid} | {:error, reason}
  """
  @spec start_link() :: {:ok, pid} | {:error, String.t()}   
  def start_link do
    case GenServer.start_link(__MODULE__, %{}, name: __MODULE__) do
      {:error, reason} -> 
        Logger.error("Failed to start OpenAperture Builder:  #{inspect reason}")
        {:error, reason}
      {:ok, pid} ->
        try do
          if Application.get_env(:autostart, :register_queues, false) do
            case register_queues do
              {:ok, _} -> {:ok, pid}
              {:error, reason} -> 
                Logger.error("Failed to register Builder queues:  #{inspect reason}")
                {:ok, pid}
            end       
          else
            {:ok, pid}
          end
        rescue e in _ ->
          Logger.error("An error occurred registering Builder queues:  #{inspect e}")
          {:ok, pid}
        end
    end
  end

  @doc """
  Method to register the Builder queues with the Messaging system

  ## Return Value

  :ok | {:error, reason}
  """
  @spec register_queues() :: :ok | {:error, String.t()}
  def register_queues do
    Logger.debug("Registering Builder queues...")
    workflow_orchestration_queue = QueueBuilder.build(ManagerApi.get_api, Configuration.get_current_queue_name, Configuration.get_current_exchange_id)

    options = OpenAperture.Messaging.ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, Configuration.get_current_broker_id)
    subscribe(options, workflow_orchestration_queue, fn(payload, _meta, %{delivery_tag: delivery_tag} = async_info) -> 
      MessageManager.track(async_info)

      builder_request = BuilderRequest.from_payload(payload)
      builder_request = %{builder_request | delivery_tag: delivery_tag}

      try do
        Logger.debug("Starting to process request #{delivery_tag} (workflow #{payload[:id]})")
        builder_request = BuilderRequest.publish_success_notification(builder_request, "Build/Config request is being processed by Builder #{System.get_env("HOSTNAME")}")
        builder_request = BuilderRequest.save_workflow(builder_request)
        process_request(builder_request)
      catch
        :exit, code   ->
          error_msg = "Message #{delivery_tag} (workflow #{payload[:id]}) Exited with code #{inspect code}.  Payload:  #{inspect payload}" 
          Logger.error(error_msg)
          Workflow.step_failed(builder_request.orchestrator_request, "An unexpected error occurred executing build request", "Exited with code #{inspect code}")
          event = make_event(error_msg)
          SystemEvent.create_system_event!(ManagerApi.get_api, event)              
          acknowledge(delivery_tag)
        :throw, value -> 
          error_msg = "Message #{delivery_tag} (workflow #{payload[:id]}) Throw called with #{inspect value}.  Payload:  #{inspect payload}"
          Logger.error(error_msg)
          Workflow.step_failed(builder_request.orchestrator_request, "An unexpected error occurred executing build request", "Throw called with #{inspect value}")
          event = make_event(error_msg)
          SystemEvent.create_system_event!(ManagerApi.get_api, event)  
          acknowledge(delivery_tag)
        what, value   -> 
          error_msg = "Message #{delivery_tag} (workflow #{payload[:id]}) Caught #{inspect what} with #{inspect value}.  Payload:  #{inspect payload}"
          Logger.error(error_msg)
          Workflow.step_failed(builder_request.orchestrator_request, "An unexpected error occurred executing build request", "Caught #{inspect what} with #{inspect value}")
          Logger.error("Error stack trace: #{Exception.format_stacktrace}")
          event = make_event(error_msg)
          SystemEvent.create_system_event!(ManagerApi.get_api, event)            
          acknowledge(delivery_tag)
      end      
    end)
  end

  @doc """
  Method to process an incoming Builder request

  ## Options

  The `request` option defines the BuilderRequest

  """
  @spec process_request(BuilderRequest.t) :: term
  def process_request(builder_request) do
    Logger.debug("Creating DeploymentRepo for request #{builder_request.delivery_tag} (workflow #{builder_request.workflow.id})")
    case DeploymentRepo.init_from_request(builder_request.orchestrator_request) do
      {:error, reason} -> 
        Workflow.step_failed(builder_request.orchestrator_request, "Failed to create DeploymentRepo!", reason)
        {:error, reason}
      {:ok, deployment_repo} ->
        try do
          builder_request = %{builder_request | deployment_repo: deployment_repo}
          Logger.debug("Executing milestones for request #{builder_request.delivery_tag} (workflow #{builder_request.workflow.id})")
          execute_milestone(:config, {:ok, builder_request})
        after
          Logger.debug("Cleaning up DeploymentRepo for request #{builder_request.delivery_tag} (workflow #{builder_request.workflow.id})")
          DeploymentRepo.cleanup(deployment_repo)
        end
    end
  after
    acknowledge(builder_request.delivery_tag)
  end

  @doc """
  Method to finish executing the Builder request flow (failure)

  ## Options

  The `reason` option defines the String reason for the failure

  The `request` option defines the BuilderRequest

  """
  @spec execute_milestone(term, {:error, String.t, BuilderRequest.t}) :: term
  def execute_milestone(_, {:error, reason, request}) do
    Logger.debug("Executing :error milestone for request #{request.delivery_tag} (workflow #{request.workflow.id})")
    Workflow.step_failed(request.orchestrator_request, "Milestone has failed", reason)
  end

  @doc """
  Method to execute the Config milestone
  After a config milestone, we skip build if the "workflow" milestone was config, not build.
  ## Options

  The `request` option defines the BuilderRequest

  ## Return Value

  {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  """
  @spec execute_milestone(:config, {:ok, BuilderRequest.t}) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute_milestone(:config, {:ok, request}) do
    Logger.debug("Executing :config milestone for request #{request.delivery_tag} (workflow #{request.workflow.id})")
    next_milestone = case request.workflow.current_step do
      :config -> :verify_build_exists
      :build ->  :build
      _ -> :error
    end
    case next_milestone do
      :error -> Workflow.step_failed(request.orchestrator_request, "Unknown next step: #{request.workflow.current_step}", "")
      _      ->
        request = Monitor.monitor(request, :config, fn -> ConfigMilestone.execute(request) end)
        execute_milestone(next_milestone, request)
    end
  end

  @doc """
  Method to execute the Build milestone

  ## Options

  The `request` option defines the BuilderRequest

  ## Return Value

  {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  """
  @spec execute_milestone(:build, {:ok, BuilderRequest.t}) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute_milestone(:build, {:ok, request}) do
    Logger.debug("Executing :build milestone for request #{request.delivery_tag} (workflow #{request.workflow.id})")
    request = Monitor.monitor(request, :build, fn -> BuildMilestone.execute(request) end)
    execute_milestone(:verify_build_exists, request)
  end

  @doc """
  Method to execute the verify_build_exists milestone

  ## Options

  The `request` option defines the BuilderRequest

  ## Return Value

  {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  """
  @spec execute_milestone(:verify_build_exists, {:ok, BuilderRequest.t}) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute_milestone(:verify_build_exists, {:ok, request}) do
    Logger.debug("Executing :verify_build_exists milestone for request #{request.delivery_tag} (workflow #{request.workflow.id})")
    request = Monitor.monitor(request, :verify_build_exists, fn -> VerifyBuildExistsMilestone.execute(request) end)
    execute_milestone(:completed, request)
  end

  @doc """
  Method to finish executing the Builder request flow (successfully)

  ## Options

  The `request` option defines the BuilderRequest
  """
  @spec execute_milestone(:completed, {:ok, BuilderRequest.t}) :: term
  def execute_milestone(:completed, {:ok, request}) do
    Logger.debug("Executing :completed milestone for request #{request.delivery_tag} (workflow #{request.workflow.id})")

    orchestrator_request = make_orchestrator_request(request)
    Workflow.step_completed(orchestrator_request)
  end  

  @doc """
  Method to acknowledge a message has been processed

  ## Options

  The `delivery_tag` option is the unique identifier of the message
  """
  @spec acknowledge(String.t()) :: term
  def acknowledge(delivery_tag) do
    message = MessageManager.remove(delivery_tag)
    unless message == nil do
      SubscriptionHandler.acknowledge(message[:subscription_handler], message[:delivery_tag])
    end
  end

  @doc """
  Method to reject a message has been processed

  ## Options

  The `delivery_tag` option is the unique identifier of the message

  The `redeliver` option can be used to requeue a message
  """
  @spec reject(String.t(), term) :: term
  def reject(delivery_tag, redeliver \\ false) do
    message = MessageManager.remove(delivery_tag)
    unless message == nil do
      SubscriptionHandler.reject(message[:subscription_handler], message[:delivery_tag], redeliver)
    end
  end

  @spec make_event(String.t) :: map
  defp make_event(error_msg), do: %{@event | message: error_msg}

  #gather all of the required info from the BuilderRequest
  @spec make_orchestrator_request(BuilderRequest.t) :: OrchestratorRequest.t
  defp make_orchestrator_request(request) do
    %{request.orchestrator_request |  etcd_token:       request.deployment_repo.etcd_token,
                                      deployable_units: DeploymentRepo.get_units(request.deployment_repo),
                                      ecs_task_definition: DeploymentRepo.get_ecs_task_definition(request.deployment_repo)}
  end
end
