defmodule OpenAperture.Builder.BuildLogPublisher do
	use GenServer

  alias OpenAperture.ManagerApi

  @moduledoc """
  BuildLogPublisher tracks a list of current {broker_id, exchange_id} tuples, which is cleared and recreated periodically.
  Additionally, it tracks a hashdict of BrokerExchangePublisher Genserver pids, which is only ever appended to.
  When publish_build_logs is called, it sends the logs to the BrokerExchangePublisher for each entry in the current
  broker-exchange tuple list.
  """

  @spec publish_build_logs(String.t, [String.t]) :: :ok
  def publish_build_logs(workflow_id, logs) do
    GenServer.cast(__MODULE__, {:publish, workflow_id, logs})
  end

  @spec start_link() :: GenServer.on_start
	def start_link() do
		GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
	end

  @spec init(:ok) :: {:ok, {Timestamp.t, [{Integer.t, Integer.t}], HashDict.t}}
	def init(:ok) do
    {broker_exchanges, broker_exchange_publishers} = get_broker_exchanges_and_publishers(HashDict.new)
		{:ok, {:os.timestamp, broker_exchanges, broker_exchange_publishers}}
	end

  @spec handle_cast({:publish, String.t, [String.t]}, {Timestamp.t, [{Integer.t, Integer.t}], HashDict.t}) :: {:noreply, {Timestamp.t, [{Integer.t, Integer.t}], HashDict.t}}
  def handle_cast({:publish, workflow_id, logs}, {_last_update, broker_exchanges, broker_exchange_publishers}) do
    Enum.map(broker_exchanges, fn key ->
                                  BrokerExchangePublisher.publish_logs(Dict.get(broker_exchange_publishers, key), workflow_id, logs)
                               end)
  end

  #gets a new list of broker_exchanges ({broker_id, exchange_id} tuples), adding any new publishers to the existing publisher list
  @spec get_broker_exchanges_and_publishers(HashDict.t) :: {[{Integer.t, Integer.t}], HashDict.t}
  defp get_broker_exchanges_and_publishers(current_broker_exchange_publishers) do
    managers = ManagerApi.SystemComponent.list!(ManagerApi.get_api, %{type: "manager"})
    broker_exchanges = Enum.reduce(managers, [], fn manager, list ->
                                if has_item(list, {manager.broker_id, manager.messaging_exchange_id}) do
                                  list
                                else
                                  [{manager.broker_id, manager.exchange_id} | list]
                                end
                              end)
    broker_exchange_publishers = Enum.reduce(broker_exchanges, current_broker_exchange_publishers,
                             fn {broker_id, exchange_id} = key, broker_exchange_publishers ->
                              if Dict.has_key?(broker_exchange_publishers, key) do
                                broker_exchange_publishers
                              else
                                {:ok, pid} = BrokerExchangePublisher.start_link(broker_id, exchange_id)
                                Dict.put(broker_exchange_publishers, key, pid)
                              end
                             end)
    {broker_exchanges, broker_exchange_publishers}
  end

  defp has_item(list, item), do: Enum.filter(list, fn list_item -> list_item == item end)

end