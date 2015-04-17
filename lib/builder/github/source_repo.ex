require Logger

defmodule OpenAperture.Builder.SourceRepo do

  alias OpenAperture.Builder.Github
  alias OpenAperture.Builder.DeploymentRepo

  @doc """
  This module contains the logic for interacting with an OpenAperture source code repo.
  """
  @spec create(Map) :: {:ok, pid} | {:error, String.t()}	
  def create(options) do
    request_id = "#{UUID.uuid1()}"
    output_dir = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/source_repos/#{request_id}" 
    resolved_options = Map.merge(options, %{output_dir: output_dir})
    
    if (resolved_options[:request_id] == nil) do
      resolved_options = Map.merge(resolved_options, %{request_id: request_id})
    end    

    if (resolved_options[:repo_branch] == nil) do
      resolved_options = Map.merge(options, %{repo_branch: "master"})
    end

    Agent.start_link(fn -> resolved_options end)
  end

  @doc """
  Method to generate a new source repo
  """
  @spec create!(Map) :: pid
  def create!(options) do
    case OpenAperture.Builder.SourceRepo.create(options) do
      {:ok, source_repo} -> source_repo
      {:error, reason} -> raise "Failed to create OpenAperture.Builder.SourceRepo:  #{reason}"
    end
  end  

  @doc """
  Method to get the unique request id for the repository
   
  ## Return Values
   
  String
  """
  @spec get_request_id(pid) :: String.t()
  def get_request_id(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    repo_options[:request_id]
  end

  @doc """
  Method to cleanup any artifacts associated with the deploy repo PID
   
  ## Options
   
  The `repo` option defines the repo PID
  """
  @spec cleanup(pid) :: term
  def cleanup(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    File.rm_rf(repo_options[:output_dir])
  end

  @doc """
  Method to get the deploy repo name associated with the PID
   
  ## Return Values
   
  String
  """
  @spec get_repo_name(pid) :: String.t()
  def get_repo_name(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    repo_options[:repo]
  end

  @doc """
  Method to get the git ref (commit, branch, tag) associated with the repo
   
  ## Return Values
   
  String
  """
  @spec get_git_ref(pid) :: String.t()
  def get_git_ref(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    repo_options[:repo_branch]
  end
  
  @doc """
  Method to download a local copy of the deployment repo and checkout to the correct version.
  To prevent parallel downloads we store the download status in the Agent's repo storage
   
  ## Options
   
  The `repo` option defines the repo PID
   
  ## Return values
   
  :ok or tuple with {:error, reason}
  """
  @spec download(pid) :: :ok | {:error, String.t()}
  def download(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    
    case repo_options[:download_status] do
      nil -> 
        try do
          repo_options = Map.merge(repo_options, %{download_status: :in_progress})
          Agent.update(repo, fn _ -> repo_options end)
          
          case Github.create(%{output_dir: repo_options[:output_dir], repo_url: Github.resolve_github_repo_url(repo_options[:repo]), branch: repo_options[:repo_branch]}) do
            {:ok, github} ->
              repo_options = Map.merge(repo_options, %{github: github})
              Agent.update(repo, fn _ -> repo_options end)

              case Github.clone(github) do
                :ok ->
                  case Github.checkout(github) do
                    :ok -> 
                      downloaded_files = File.ls!(repo_options[:output_dir])
                      Logger.debug("Git clone and checkout of repository #{repo_options[:docker_repo]} has downloaded the following files:  #{inspect downloaded_files}")
                      :ok
                    {:error, reason} -> 
                      repo_options = Map.merge(repo_options, %{download_error: reason})
                      Agent.update(repo, fn _ -> repo_options end)                       
                      {:error, reason}
                  end
                {:error, reason} -> 
                  repo_options = Map.merge(repo_options, %{download_error: reason})
                  Agent.update(repo, fn _ -> repo_options end)                   
                  {:error, reason}
              end
            {:error, reason} -> 
              repo_options = Map.merge(repo_options, %{download_error: reason})
              Agent.update(repo, fn _ -> repo_options end)               
              {:error, reason}
          end
        after
          # make sure that we have all of the options that were saved during recursion 
          final_options = Agent.get(repo, fn options -> options end)
          final_options = %{final_options | download_status: :finished}
          Agent.update(repo, fn _ -> final_options end)  
        end
      :in_progress ->
        Logger.debug("Download is already in progress. Sleeping for 1s...")
        :timer.sleep(1000)
        download(repo)
      :finished -> 
        Logger.debug("The sources have already been downloaded")
        final_options = Agent.get(repo, fn options -> options end)
        if final_options[:download_error] == nil do
          :ok
        else
          {:error, final_options[:download_error]}
        end
    end
  end

  @doc """
  Method to retrieve an OpenAperture repo info from the output directory

  ## Options

  The 'repo' option defines the repo PID

  ## Return values

  Map
  """
  @spec get_openaperture_info(pid) :: {:ok, pid} | {:error, String.t()}
  def get_openaperture_info(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    resolve_openaperture_info(repo_options[:output_dir])
  end

  @doc """
  Method to determine the OpenAperture deployment repo from the source repo.
     
  ## Options
   
  The `repo` option defines the repo PID
   
  ## Return values
   
  tuple with {:ok, pid} or {:error, reason}
  """
  @spec get_deployment_repo(pid) :: {:ok, pid} | {:error, String.t()}
  def get_deployment_repo(repo) do
    repo_options = Agent.get(repo, fn options -> options end)
    if (repo_options[:deployment_repo] != nil) do
      repo_options[:deployment_repo]
    else
      openaperture_info = resolve_openaperture_info(repo_options[:output_dir])

      if (openaperture_info != nil) do
        docker_repo = openaperture_info["deployments"]["docker_repo"]
        docker_repo_branch = openaperture_info["deployments"]["docker_repo_branch"]          
        if (docker_repo != nil) do
          #docker_repo_branch will default to master if not present
          deployment_repo = DeploymentRepo.create(%{docker_repo: docker_repo, docker_repo_branch: docker_repo_branch})
          repo_options = Map.merge(repo_options, %{deployment_repo: deployment_repo})
          Agent.update(repo, fn _ -> repo_options end)
          deployment_repo          
        else
          {:error, "openaperture.json is invalid! Make sure both the repo and default branch are specified"}
        end
      else
        {:error, "source_dir.json is either missing or invalid!"}
      end      
    end    
  end

  @doc false
  # Method to retrieve the OpenAperture repo info from source repository
  #
  ## Options
  #
  # The `github` option defines the github PID
  #
  # The `source_dir` option defines where the source files exist
  #
  ## Return Values
  # 
  # Map
  #
  @spec resolve_openaperture_info(String.t()) :: Map
  defp resolve_openaperture_info(source_dir) do
    output_path = "#{source_dir}/openaperture.json"

    if File.exists?(output_path) do
      Logger.info("Resolving OpenAperture info from #{output_path}...")
      openaperture_json = case File.read!(output_path) |> JSON.decode do
        {:ok, json} -> json
        {:error, reason} ->  
          Logger.error("An error occurred parsing OpenAperture JSON! #{inspect reason}")
          nil
      end
      openaperture_json      
    else
      nil
    end
  end
end
