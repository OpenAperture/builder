require Logger

defmodule OpenAperture.Builder.Github do
  alias OpenAperture.Builder.Util
  @moduledoc """
  This module contains the logic for interacting with Github.
  """

  @doc """
  Method to return the project name of a repository

  ## Options

  The `src_repo` option defines the fully qualified repository name.

  ## Return values

  String
  """  
  @spec get_project_name(String.t()) :: String.t()
  def get_project_name(src_repo) do
    URI.parse(src_repo).path
      |> get_after_last_forward_slash
  end

  @doc false
  #Method to return the project name of a repository
  #
  ## Options
  #
  # The `src_repo` option defines the fully qualified repository name.
  #
  ## Return values
  #
  #String
  # 
  @spec get_after_last_forward_slash(String.t()) :: String.t()
  defp get_after_last_forward_slash(str) do
    String.split(str, ~r{/}) |> List.last
  end

  @doc """
  Method to create a fully-qualified github repo URL from a relative repository name.

  ## Options

  The `github_repo` option defines the relative repository name.

  ## Return values

  String
  """  
  @spec resolve_github_repo_url(String.t()) :: String.t()
  def resolve_github_repo_url(github_repo) do
    "https://#{Application.get_env(:openaperture_builder, :github_user_credentials)}:x-oauth-basic@github.com/#{github_repo}"
  end

  @doc """
  Creates an Agent representing Github.

  ## Options

  The `github_options` option defines the Map of configuration options that should be 
  passed to Github.  The following values are required:
    * :repo_url - the fully qualified github repo URL (i.e. Perceptive-Cloud/<repo>)
    * :output_dir - the directory containing the git repo
    * :branch - github branch

  ## Return values

  If the server is successfully created and initialized, the function returns
  `{:ok, pid}`, where pid is the pid of the server. If there already exists a
  process with the specified server name, the function returns
  `{:error, {:already_started, pid}}` with the pid of that process.

  If the `init/1` callback fails with `reason`, the function returns
  `{:error, reason}`. Otherwise, if it returns `{:stop, reason}`
  or `:ignore`, the process is terminated and the function returns
  `{:error, reason}` or `:ignore`, respectively.
  """
  @spec create(Map) :: {:ok, pid} | {:error, String.t()}
  def create(github_options) do
    Agent.start_link(fn -> github_options end)
  end

  @doc """
  Method to generate a new deployment repo

  ## Options
  
  The `github_options` option defines the Map of configuration options that should be 
  passed to Github.  The following values are required:
    * :repo_url - the fully qualified github repo URL (i.e. Perceptive-Cloud/<repo>)
    * :output_dir - the directory containing the git repo
    * :branch - github branch

  ## Return Values

  pid
  """
  @spec create!(Map) :: pid
  def create!(github_options) do
    case CloudosBuildServer.Agents.Github.create(github_options) do
      {:ok, github} -> github
      {:error, reason} -> raise "Failed to create CloudosBuildServer.Agents.Github:  #{reason}"
    end
  end  

  @doc """
  Method to get options from a Github agent.
   
  ## Options
   
  The `github` option defines Github agent.
   
  ## Return values
   
  Map
  """
  @spec get_options(pid) :: Map
  def get_options(github) do
    if (github == nil) do
      Logger.error("Unable to retrieve github options - github agent is invalid!")
      nil
    else
      Logger.debug("Retrieve options for github agent #{inspect github}...")
      Agent.get(github, fn options -> options end)      
    end
  end   

  @doc """
  Method to execute a git clone against a specified Github agent.

  ## Options

  The `github` option defines the Github agent against which the commands should be executed.

  ## Return values

  :ok or {:error, reason}
  """
  @spec clone(pid) :: :ok | {:error, String.t()}
  def clone(github) do
    Logger.debug ("Attempting to clone github agent #{inspect github}")
    github_options = get_options(github)
    Logger.debug("Github options: #{inspect github_options}")

    if (github_options == nil) do
      {:error, "invalid github agent!"}
    else
      Logger.debug("Cloning #{github_options[:repo_url]} into directory #{github_options[:output_dir]}...")
      case Util.execute_command("git clone #{github_options[:repo_url]} #{github_options[:output_dir]}", "#{github_options[:output_dir]}") do
        {message, 0} ->
          Logger.debug ("Successfully cloned repository")
          Logger.debug(message)
          :ok
        {message, _} ->
          error_msg = "An error occurred cloning repository:\n#{message}"
          Logger.error(error_msg)
          {:error, error_msg}
      end      
    end
  end

  @doc """
  Method to execute a git checkout against a specified Github agent.

  ## Options

  The `github` option defines the Github agent against which the commands should be executed.

  ## Return values

  :ok or {:error, reason}
  """
  @spec checkout(pid) :: :ok | {:error, String.t()}
  def checkout(github) do
    github_options = get_options(github)
    if (github_options == nil) do
      {:error, "invalid github agent!"}
    else
      Logger.info("Switching to branch/tag #{github_options[:branch]} into directory #{github_options[:output_dir]}...")
      case Util.execute_command("git checkout #{github_options[:branch]}", "#{github_options[:output_dir]}") do
        {message, 0} ->
          Logger.debug ("Successfully performed git checkout")
          Logger.debug(message)
          :ok
        {message, _} ->
          error_msg = "An error occurred performing git checkout:\n#{message}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    end
  end

  @doc """
  Method to execute a git add against a specified Github agent.

  ## Options

  The `github` option defines the Github agent against which the commands should be executed.

  ## Return values

  :ok or {:error, reason}
  """
  @spec add(pid, String.t()) :: :ok | {:error, String.t()}
  def add(github, filepath) do
    github_options = get_options(github)
    if (github_options == nil) do
      {:error, "invalid github agent!"}
    else
      Logger.info("Staging file #{github_options[:output_dir]} for commit...")
      case Util.execute_command("git add #{filepath}", "#{github_options[:output_dir]}") do
        {message, 0} ->
          Logger.debug ("Successfully performed git add")
          Logger.debug(message)
          :ok
        {message, _} ->
          error_msg = "An error occurred performing git add:\n#{message}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    end
  end

  @doc """
  Method to execute a git add -A for a directory, against a specified Github agent.

  ## Options

  The `github` option defines the Github agent against which the commands should be executed.

  The `dir` option defines the desired directory to add

  ## Return values

  :ok or {:error, reason}
  """
  @spec add_all(pid, String.t()) :: :ok | {:error, String.t()}
  def add_all(github, dir) do
    github_options = get_options(github)
    if (github_options == nil) do
      {:error, "invalid github agent!"}
    else
      Logger.info("Staging file #{github_options[:output_dir]} for commit...")
      case Util.execute_command("git add -A #{dir}", "#{github_options[:output_dir]}") do
        {message, 0} ->
          Logger.debug ("Successfully performed git add all")
          Logger.debug(message)
          :ok
        {message, _} ->
          error_msg = "An error occurred performing git add all:\n#{message}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    end
  end  

  @doc """
  Method to execute a git commit against a specified Github agent.

  ## Options

  The `github` option defines the Github agent against which the commands should be executed.

  ## Return values

  :ok or {:error, reason}
  """
  @spec commit(pid, String.t()) :: :ok | {:error, String.t()}
  def commit(github, message) do
    github_options = get_options(github)
    if (github_options == nil) do
      {:error, "invalid github agent!"}
    else
      Logger.info ("Committing changes...")
      case Util.execute_command("git commit -m \"#{message}\"", "#{github_options[:output_dir]}") do
        {message, 0} ->
          Logger.debug ("Successfully performed git commit")
          Logger.debug(message)
          :ok
        {message, _} ->
          error_msg = "An error occurred performing git commit:\n#{message}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    end
  end

  @doc """
  Method to execute a git push against a specified Github agent.

  ## Options

  The `github` option defines the Github agent against which the commands should be executed.

  ## Return values

  :ok or {:error, reason}
  """
  @spec push(pid) :: :ok | {:error, String.t()}
  def push(github) do
    github_options = get_options(github)
    if (github_options == nil) do
      {:error, "invalid github agent!"}
    else
      Logger.info ("Pushing staged commit to repository #{github_options[:repo_url]}...")
      case Util.execute_command("git push", "#{github_options[:output_dir]}") do
        {message, 0} ->
          Logger.debug ("Successfully performed git push")
          Logger.debug(message)
          :ok
        {message, _} ->
          error_msg = "An error occurred performing git push:\n#{message}"
          Logger.error(error_msg)
          {:error, error_msg}
      end
    end
  end
end
