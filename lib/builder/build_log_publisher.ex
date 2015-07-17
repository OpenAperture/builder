defmodule OpenAperture.Builder.BuildLogPublisher do
	use GenServer
  @connection_options nil
  use OpenAperture.Messaging
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.ConnectionOptionsResolver

  alias OpenAperture.ManagerApi

  def publish_build_logs(workflow_id, logs, exchange_id, broker_id) do
    GenServer.cast(__MODULE__, {:publish, workflow_id, logs, exchange_id, broker_id})
  end

	def start_link() do
		GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
	end

	def init(:ok) do
		{:ok, HashDict.new}
	end

  def handle_cast({:publish, workflow_id, logs, exchange_id, broker_id}, queue_and_options_dict) do
    {queue_and_options_dict, queue, options} = get_queue_and_options(queue_and_options_dict, exchange_id, broker_id)
    payload = %{workflow_id: workflow_id, logs: logs}
    case publish(options, queue, payload) do
      :ok -> nil
      {:error, reason} -> Logger.error("[BuildLogPublisher] Failed to publish BuildLog event:  #{inspect reason}")
    end
    {:noreply, queue_and_options_dict}
  end

  defp get_queue_and_options(queue_and_options_dict, exchange_id, broker_id) do
    case Dict.get(queue_and_options_dict, {exchange_id, broker_id}) do
      nil ->
        routing_key = "build_logs"
        queue = QueueBuilder.build(ManagerApi.get_api, routing_key, exchange_id)
        IO.inspect queue
        options = ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, broker_id)
        queue_and_options_dict = Dict.put(queue_and_options_dict, {exchange_id, broker_id}, {queue, options})
        {queue_and_options_dict, queue, options}
      {queue, options} ->
        {queue_and_options_dict, queue, options}
    end    
  end
end