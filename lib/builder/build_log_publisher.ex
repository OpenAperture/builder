defmodule OpenAperture.Builder.BuildLogPublisher do
	use GenServer

  alias OpenAperture.ManagerApi
  alias OpenAperture.Builder.BuildLogPublisher.ExchangePublisher

  @moduledoc """
  BuildLogPublisher tracks a list of current exchange_id's, which is cleared and recreated periodically.
  Additionally, it tracks a hashdict of ExchangePublisher Genserver pids, which is only ever appended to.
  When publish_build_logs is called, it sends the logs to the ExchangePublisher for each entry in the current
  exchange list.
  """

  @spec publish_build_logs(String.t, [String.t]) :: :ok
  def publish_build_logs(workflow_id, logs) do
    GenServer.cast(__MODULE__, {:publish, workflow_id, logs})
  end

  @spec start_link() :: GenServer.on_start
	def start_link() do
    case (Application.get_env(:openaperture_builder, :build_log_publisher_autostart, true)) do
      true -> GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
      _    -> Agent.start_link(fn -> false end)
    end
  end

  @spec init(:ok) :: {:ok, {Timestamp.t, [{Integer.t, Integer.t}], HashDict.t}}
	def init(:ok) do
    {exchanges, exchange_publishers} = get_exchanges_and_publishers(HashDict.new)
		{:ok, {:os.timestamp, exchanges, exchange_publishers}}
	end

  @spec handle_cast({:publish, String.t, [String.t]}, {Timestamp.t, [Integer.t], HashDict.t}) :: {:noreply, {Timestamp.t, [{Integer.t, Integer.t}], HashDict.t}}
  def handle_cast({:publish, workflow_id, logs}, {last_update, exchanges, exchange_publishers}) do
    #todo: check last_update and rerun get_exchanges_and_publishers if they are old
    Enum.map(exchanges, fn key ->
                            ExchangePublisher.publish_build_logs(Dict.get(exchange_publishers, key), workflow_id, logs)
                         end)
    {:noreply, {last_update, exchanges, exchange_publishers}}
  end

  @spec get_exchanges_and_publishers(HashDict.t) :: {[Integer.t], HashDict.t}
  def get_exchanges_and_publishers(current_exchange_publishers) do
    exchanges = get_exchanges
    exchange_publishers = add_new_exchange_publishers(exchanges, current_exchange_publishers)
    {exchanges, exchange_publishers}
  end

  #gets a new list of exchanges from the list of managers
  @spec get_exchanges() :: [Integer.t]
  def get_exchanges() do
    managers = ManagerApi.SystemComponent.list!(ManagerApi.get_api, %{type: "manager"})
    Enum.reduce(managers, [], fn manager, list ->
                                case has_item(list, manager["messaging_exchange_id"]) do
                                  true -> list
                                  _    -> [manager["messaging_exchange_id"] | list]
                                end
                              end)
  end

  #takes the full list of exchanges and the current list of exchange publishers and makes sure all exchanges
  #exist in the publisher list, creating new ones if they don't
  @spec add_new_exchange_publishers([Integer.t], HashDict.t) :: Hashdict.t
  def add_new_exchange_publishers(exchanges, current_exchange_publishers) do
    Enum.reduce(exchanges, current_exchange_publishers,
                             fn exchange_id = key, exchange_publishers ->
                              case Dict.has_key?(exchange_publishers, key) do
                                true -> exchange_publishers
                                _    ->
                                  {:ok, pid} = ExchangePublisher.start_link(exchange_id)
                                  Dict.put(exchange_publishers, key, pid)
                              end
                             end)
  end

  def has_item(list, item), do: length(Enum.filter(list, fn list_item -> list_item == item end)) > 0

end
