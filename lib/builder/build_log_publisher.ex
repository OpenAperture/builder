defmodule OpenAperture.Builder.BuildLogPublisher do
	use GenServer
  @connection_options nil
  use OpenAperture.Messaging
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.ConnectionOptions

  alias OpenAperture.ManagerApi

  @spec publish_build_logs(String.t, [String.t], Integer.t, Integer.t) :: :ok
  def publish_build_logs(workflow_id, logs, exchange_id, broker_id) do
    GenServer.cast(__MODULE__, {:publish, workflow_id, logs, exchange_id, broker_id})
  end

  @spec start_link() :: GenServer.on_start
	def start_link() do
		GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
	end

  @spec init(:ok) :: {:ok, HashDict.t}
	def init(:ok) do
		{:ok, HashDict.new}
	end

  @spec handle_cast({:publish, String.t, [String.t], Integer.t, Integer.t}, HashDict.t) :: {:noreply, HashDict.t}
  def handle_cast({:publish, workflow_id, logs, exchange_id, broker_id}, queue_and_options_dict) do
    {queue_and_options_dict, queue, options} = __MODULE__.get_queue_and_options(queue_and_options_dict, exchange_id, broker_id)
    payload = %{workflow_id: workflow_id, logs: logs}
    case __MODULE__.publish(options, queue, payload) do
      :ok -> nil
      {:error, reason} -> Logger.error("[BuildLogPublisher] Failed to publish BuildLog event:  #{inspect reason}")
    end
    {:noreply, queue_and_options_dict}
  end

  @spec get_queue_and_options(HashDict.t, Integer.t, Integer.t) :: {HashDict.t, Queue.t, ConnectionOptions.t}
  def get_queue_and_options(queue_and_options_dict, exchange_id, broker_id) do
    case Dict.get(queue_and_options_dict, {exchange_id, broker_id}) do
      nil ->
        routing_key = "build_logs"
        queue = QueueBuilder.build(ManagerApi.get_api, routing_key, exchange_id)
        options = ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, broker_id)
        queue_and_options_dict = Dict.put(queue_and_options_dict, {exchange_id, broker_id}, {queue, options})
        {queue_and_options_dict, queue, options}
      {queue, options} ->
        {queue_and_options_dict, queue, options}
    end    
  end
end