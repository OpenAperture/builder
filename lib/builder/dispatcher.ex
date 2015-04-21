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

  alias OpenAperture.Builder.Milestones.Config, as: ConfigMilestone
  alias OpenAperture.Builder.Milestones.Build, as: BuildMilestone

  @moduledoc """
  This module contains the logic to dispatch Builder messsages to the appropriate GenServer(s) 
  """  

  @connection_options nil
  use OpenAperture.Messaging  

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
    workflow_orchestration_queue = QueueBuilder.build(ManagerApi.get_api, "builder", Configuration.get_current_exchange_id)

    options = OpenAperture.Messaging.ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, Configuration.get_current_broker_id)
    subscribe(options, workflow_orchestration_queue, fn(payload, _meta, %{delivery_tag: delivery_tag} = async_info) -> 
      MessageManager.track(async_info)

      request = BuilderRequest.from_payload(payload)
      request = %{request | delivery_tag: delivery_tag}
      process_request(request)
    end)
  end

  @doc """
  Method to process an incoming Builder request

  ## Options

  The `request` option defines the BuilderRequest

  """
  @spec process_request(BuilderRequest.t) :: term
  def process_request(request) do
    case DeploymentRepo.init_from_workflow(request.workflow) do
      {:error, reason} -> {:error, reason}
      {:ok, deployment_repo} -> 
        try do
          request = %{request | deployment_repo: deployment_repo}
          execute_milestone(:config, {:ok, request})
        after
          DeploymentRepo.cleanup(deployment_repo)
        end
    end
  after
    acknowledge(request.delivery_tag)
  end

  @doc """
  Method to finish executing the Builder request flow (failure)

  ## Options

  The `reason` option defines the String reason for the failure

  The `request` option defines the BuilderRequest

  """
  @spec execute_milestone(term, {:error, String.t, BuilderRequest.t}) :: term
  def execute_milestone(_, {:error, reason, request}) do
    Workflow.step_failed(request.orchestrator_request, "Milestone has failed", reason)
  end

  @doc """
  Method to execute the Config milestone

  ## Options

  The `request` option defines the BuilderRequest

  ## Return Value

  {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  """
  @spec execute_milestone(:config, {:ok, BuilderRequest.t}) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute_milestone(:config, {:ok, request}) do
    execute_milestone(:build, ConfigMilestone.execute(request))
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
    execute_milestone(:completed, BuildMilestone.execute(request))
  end

  @doc """
  Method to finish executing the Builder request flow (successfully)

  ## Options

  The `request` option defines the BuilderRequest
  """
  @spec execute_milestone(:completed, {:ok, BuilderRequest.t}) :: term
  def execute_milestone(:completed, {:ok, request}) do
    #gather all of the required info from the BuilderRequest
    orchestrator_request = request.orchestrator_request
    orchestrator_request = %{orchestrator_request | etcd_token: request.deployment_repo.etcd_token}
    orchestrator_request = %{orchestrator_request | deployable_units: DeploymentRepo.get_units(request.deployment_repo)}

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
end