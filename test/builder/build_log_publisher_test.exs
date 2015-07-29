defmodule OpenAperture.Builder.BuildLogPublisherTest do
	use ExUnit.Case

  alias OpenAperture.Builder.BuildLogPublisher
  alias OpenAperture.Builder.BuildLogPublisher.ExchangePublisher
  alias OpenAperture.ManagerApi

  test "has_item" do
    assert BuildLogPublisher.has_item([:item], :item)
    assert BuildLogPublisher.has_item([:item, :another_item], :item)
    refute BuildLogPublisher.has_item([:another_item], :item)
    refute BuildLogPublisher.has_item([], :item)
  end

  test "get_exchanges" do
    :meck.new(ManagerApi)
    :meck.expect(ManagerApi, :get_api, fn -> :api end)
    :meck.new(ManagerApi.SystemComponent)
    :meck.expect(ManagerApi.SystemComponent, :list!, fn _, opts ->
        assert opts == %{type: "manager"}
        [%{"messaging_exchange_id" => 402},
         %{"messaging_exchange_id" => 402},
         %{"messaging_exchange_id" => 4102}]
      end)
    ret = BuildLogPublisher.get_exchanges()
    assert ret == [4102, 402]
  after
    :meck.unload
  end

  test "add_new_exchange_publishers" do
    :meck.new(ExchangePublisher)
    :meck.expect(ExchangePublisher, :start_link, &{:ok, "pid#{&1}"})

    exchange_publishers = BuildLogPublisher.add_new_exchange_publishers([7,8,9], Dict.put(HashDict.new, 6, "pid6"))

    assert Dict.size(exchange_publishers) == 4
    assert Dict.get(exchange_publishers, 6) == "pid6"
    assert Dict.get(exchange_publishers, 7) == "pid7"
    assert Dict.get(exchange_publishers, 8) == "pid8"
    assert Dict.get(exchange_publishers, 9) == "pid9"
  after
    :meck.unload
  end

  test "handle_cast" do
    workflow_id = 42
    logs = [:logs]
    {:ok, agent_pid} = Agent.start_link(fn -> 0 end)
    :meck.new(ExchangePublisher)
    :meck.expect(ExchangePublisher, :publish_build_logs, fn _, wid, ls ->
        assert wid == workflow_id
        assert ls == logs
        Agent.update(agent_pid, &(&1+1))
      end)
    exchange_publishers = HashDict.new
    |> HashDict.put(1, :one)
    |> HashDict.put(2, :two)
    BuildLogPublisher.handle_cast({:publish, workflow_id, logs}, {:os.timestamp, [1, 2], exchange_publishers})
    assert Agent.get(agent_pid, &(&1)) == 2
  after
    :meck.unload
  end
end