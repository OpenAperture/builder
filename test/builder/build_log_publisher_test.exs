defmodule OpenAperture.Builder.BuildLogPublisherTest do
	use ExUnit.Case

  alias OpenAperture.Builder.BuildLogPublisher
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.ConnectionOptionsResolver

  test "get_queue_and_options cache populates" do
    :meck.new(QueueBuilder)
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> :my_queue end)
    :meck.new(ConnectionOptionsResolver)
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _,_ -> :my_options end)

    {cache, queue, options} = BuildLogPublisher.get_queue_and_options(HashDict.new, 99, 99)
    assert queue == :my_queue
    assert options == :my_options
    assert Dict.has_key?(cache, {99,99})

    {q, ops} = Dict.get(cache, {99,99})
    assert q == :my_queue
    assert ops == :my_options
  after
    :meck.unload
  end

  test "get_queue_and_options cache used" do
    :meck.new(QueueBuilder)
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> :my_queue end)
    :meck.new(ConnectionOptionsResolver)
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _,_ -> :my_options end)

    {cache, _queue, _options} = BuildLogPublisher.get_queue_and_options(HashDict.new, 99, 99)

    :meck.unload
    :meck.new(QueueBuilder)
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> raise "Shouldn't get here" end)
    :meck.new(ConnectionOptionsResolver)
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _,_ -> raise "Shouldn't get here" end)

    {cache, queue, options} = BuildLogPublisher.get_queue_and_options(cache, 99, 99)


    assert queue == :my_queue
    assert options == :my_options
    assert Dict.has_key?(cache, {99,99})

    {q, ops} = Dict.get(cache, {99,99})
    assert q == :my_queue
    assert ops == :my_options
  after
    :meck.unload
  end

  test "publish - success" do
    :meck.new(BuildLogPublisher, [:passthrough])
    :meck.expect(BuildLogPublisher, :get_queue_and_options, fn _,_,_ -> {:my_queue_and_options_dict, :my_queue, :my_options} end)
    :meck.expect(BuildLogPublisher, :publish, fn options, queue, payload ->
                                                  assert options == :my_options
                                                  assert queue == :my_queue
                                                  assert payload.workflow_id == :workflow_id
                                                  assert payload.logs == :logs
                                                  :ok end)
    
    {status, cache} = BuildLogPublisher.handle_cast({:publish, :workflow_id, :logs, :exchange_id, :broker_id}, :my_queue_and_options_dict)
    assert status == :noreply
    assert cache == :my_queue_and_options_dict
  after
    :meck.unload
  end
end