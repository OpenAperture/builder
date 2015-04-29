defmodule OpenAperture.Builder.DockerHostsTests do
  use ExUnit.Case

  alias OpenAperture.Builder.DockerHosts
  alias OpenAperture.Fleet.EtcdCluster

  #==================
  #next_available tests

  test "next_available - nil token" do
  	{:error, reason} = DockerHosts.next_available(nil)
  	assert reason != nil
  end

  test "next_available - empty token" do
  	{:error, reason} = DockerHosts.next_available("")
  	assert reason != nil
  end

  test "next_available - no hosts" do
  	:meck.new(EtcdCluster, [:passthrough])
  	:meck.expect(EtcdCluster, :get_hosts, fn _ -> [] end)

  	{:error, reason} = DockerHosts.next_available("123abc")
  	assert reason != nil
  after
  	:meck.unload(EtcdCluster)
  end

  test "next_available - 1 invalid host" do
  	:meck.new(EtcdCluster, [:passthrough])
  	:meck.expect(EtcdCluster, :get_hosts, fn _ -> [%{}] end)

  	{:error, reason} = DockerHosts.next_available("123abc")
  	assert reason != nil
  after
  	:meck.unload(EtcdCluster)
  end

  test "next_available - 1 host" do
  	:meck.new(EtcdCluster, [:passthrough])
  	:meck.expect(EtcdCluster, :get_hosts, fn _ -> [%{"primaryIP" => "123.456.789.0123"}] end)

  	{:ok, host} = DockerHosts.next_available("123abc")
  	assert host == "123.456.789.0123"
  after
  	:meck.unload(EtcdCluster)
  end

  test "next_available - 2 host" do
  	:meck.new(EtcdCluster, [:passthrough])
  	:meck.expect(EtcdCluster, :get_hosts, fn _ -> [%{"primaryIP"=> "123.456.789.0123"}, %{"primaryIP"=> "234.456.789.0123"}] end)

  	{:ok, host} = DockerHosts.next_available("123abc")
  	assert (host == "123.456.789.0123" || host == "234.456.789.0123")
  after
  	:meck.unload(EtcdCluster)
  end  
end