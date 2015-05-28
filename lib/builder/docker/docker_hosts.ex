require Logger

defmodule OpenAperture.Builder.DockerHosts do

  alias OpenAperture.Fleet.EtcdCluster

  @moduledoc """
  This module provides methods to resolve a specific host IP from an etcd token
  """

  @doc """
  Method to retrieve the next available host for an Etcd Cluster

  ## Options

  The `etcd_token` option is the String etcd token

  ## Return Values

  {:ok, docker_host} | {:error, reason}
  """
  @spec next_available(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def next_available(etcd_token) do
    if etcd_token == nil || String.length(etcd_token) == 0 do
      {:error, "Unable to resolve host because the etcd_token is invalid!"}
    else
      Logger.debug("[DockerHosts] Retrieving next available docker host...")

      hosts = EtcdCluster.get_hosts(etcd_token)
      if hosts == nil || length(hosts) == 0 do
        {:error, "Unable to find a valid docker host - No hosts are available!"}
      else
        cur_hosts_cnt = length(hosts)
        if cur_hosts_cnt == 1 do
          host = List.first(hosts)
        else
          host_idx = :random.uniform(cur_hosts_cnt)-1
          {host, _cur_idx} = Enum.reduce hosts, {nil, 0}, fn (current_host, {host, cur_idx}) ->
            if cur_idx == host_idx do
              {current_host, cur_idx+1}
            else
              {host, cur_idx+1}
            end
          end
        end

        if (host != nil && host.primaryIP != nil) do
          {:ok, host.primaryIP}
        else
          {:error, "Host does not have a valid primaryIP:  #{inspect host}"}
        end
      end
    end
  end
end