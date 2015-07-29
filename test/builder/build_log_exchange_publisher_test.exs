defmodule OpenAperture.Builder.BuildLogPublisher.ExchangePublisherTest do
  use ExUnit.Case

  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Builder.BuildLogPublisher.ExchangePublisher

  test "init" do
    exchange_id = 42
    queue = :queue
    connection_options = :connection_options

    :meck.new(QueueBuilder)
    :meck.expect(QueueBuilder, :build, fn _, queue_name, eid ->
        assert eid == exchange_id
        assert queue_name == "build_logs"
        queue
      end)
    :meck.new(ConnectionOptionsResolver)
    :meck.expect(ConnectionOptionsResolver, :resolve, fn _,_,_, eid ->
        assert eid == exchange_id
        connection_options
      end)
    {:ok, {q, co}} = ExchangePublisher.init(exchange_id)
    assert q == queue
    assert co == connection_options
  after
    :meck.unload
  end

  test "publish" do
    workflow_id = 42
    logs = [:logs]
    queue = :queue
    connection_options = :connection_options

    :meck.new(ExchangePublisher, [:passthrough])
    :meck.expect(ExchangePublisher, :publish, fn o, q, payload ->
        assert o == connection_options
        assert q == queue
        assert payload == %{workflow_id: workflow_id, logs: logs}
        :ok
      end)

    {:noreply, {q, o}} = ExchangePublisher.handle_cast({:publish, workflow_id, logs}, {queue, connection_options})
    assert q == queue
    assert o == connection_options
  after
    :meck.unload
  end
end