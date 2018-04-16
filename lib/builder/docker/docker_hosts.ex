require Logger

defmodule OpenAperture.Builder.DockerHosts do

  alias OpenAperture.Fleet.EtcdCluster

  @moduledoc """
  This module provides methods to resolve a specific host IP
  """

  @doc """
  Method to retrieve the next available docker host

  ## Return Values

  {:ok, docker_host} | {:error, reason}
  """
  @spec next_available() :: {:ok, String.t()} | {:error, String.t()}
  def next_available() do
    Logger.debug("[DockerHosts] Retrieving next available docker host...")

    hosts = String.split(Application.get_env(:openaperture_builder, :build_slave_ips), ",")
    if hosts == nil || length(hosts) == 0 do
      {:error, "Unable to find a valid docker host - No hosts are available!"}
    else
      cur_hosts_cnt = length(hosts)
      if cur_hosts_cnt == 1 do
        {:ok, List.first(hosts)}
      else
        :random.seed(:os.timestamp)
        {:ok, List.first(Enum.shuffle(hosts))}
      end        
    end
  end
end