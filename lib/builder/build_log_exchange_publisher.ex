defmodule OpenAperture.Builder.BuildLogPublisher.ExchangePublisher do
  use GenServer

  @connection_options nil
  use OpenAperture.Messaging

  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.ConnectionOptions
  alias OpenAperture.Messaging.AMQP.Queue
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.ManagerApi

  @spec start_link(Integer.t) :: GenServer.on_start
  def start_link(exchange_id) do
    GenServer.start_link(__MODULE__, exchange_id)
  end

  @spec publish_build_logs(pid, String.t, [String.t]) :: :ok
  def publish_build_logs(pid, workflow_id, logs) do
    GenServer.cast(pid, {:publish, workflow_id, logs})
  end

  @spec init(Integer.t) :: {:ok, {Queue.t, ConnectionOptions.t}}
  def init(exchange_id) do
    queue = QueueBuilder.build(ManagerApi.get_api, "build_logs", exchange_id)
    options = ConnectionOptionsResolver.resolve(ManagerApi.get_api,
                                                Application.get_env(:openaperture_builder, :broker_id),
                                                Application.get_env(:openaperture_builder, :exchange_id),
                                                exchange_id)
    {:ok, {queue, options}}
  end

  @spec handle_cast({:publish, String.t, [String.t]}, {Queue.t, ConnectionOptions.t}) :: {:noreply, {Queue.t, ConnectionOptions.t}}
  def handle_cast({:publish, workflow_id, logs}, {queue, options}) do
    payload = %{workflow_id: workflow_id, logs: logs}
    case __MODULE__.publish(options, queue, payload) do
      :ok -> nil
      {:error, reason} -> Logger.error("[BuildLogPublisher] Failed to publish BuildLog event:  #{inspect reason}")
    end
    {:noreply, {queue, options}}
  end

end