require Logger

defmodule OpenAperture.Builder.Docker do
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.Util

  alias OpenAperture.Builder.Docker.AsyncCmd

  defstruct docker_repo_url: nil,
            docker_host: nil,
            output_dir: nil,
            image_id: nil,
            authenticated: false,
            registry_url: nil,
            registry_username: nil,
            registry_email: nil,
            registry_password: nil,
            stdout_build_log_uuid: UUID.uuid1(),
            stderr_build_log_uuid: UUID.uuid1()

  @type t :: %__MODULE__{}

  @moduledoc """
  This module contains the logic for interacting with Docker.
  """

  @doc """
  Method to initialize a Docker struct. Validates required values are populated.
  """
  @spec init(Docker) :: {:ok, Docker} | {:error, String.t()}
  def init(docker) do
    cond do
      empty(docker.docker_repo_url) -> {:error, "Missing docker_repo_url"}
      empty(docker.docker_host) -> {:error, "Missing docker_host"}
      empty(docker.output_dir) -> {:error, "Missing output_dir"}
      empty(docker.registry_url) -> {:error, "Missing registry_url"}
      empty(docker.registry_username) -> {:error, "Missing registry_username"}
      empty(docker.registry_email) -> {:error, "Missing registry_email"}
      empty(docker.registry_password) -> {:error, "Missing registry_password"}
      true -> {:ok, docker}
    end
  end

  @spec empty(String.t()) :: Boolean
  defp empty(val) do
    val == nil || val == ""
  end

  @doc """
  Method to cleanup any cache associated with an image id
  """
  @spec cleanup_image_cache(Docker, String.t()) :: :ok | {:error, String.t()}
  def cleanup_image_cache(docker, _image_id \\ nil) do
    Logger.debug ("Executing docker cache cleanup commands...")
    try do
      Logger.debug ("Cleaning up exited containers...")
      case execute_async(docker, "docker rm $(DOCKER_HOST=#{docker.docker_host}  docker ps -f status=exited -q)", nil) do
        {:ok, result, docker_output} -> Logger.debug ("Successfully cleaned up exited containers:\n#{result}\n\nDocker Tag Output:  #{docker_output}")
        {:error, reason, stdout, stderr} -> Logger.error("Failed to clean up exited containers:  #{inspect reason}\n\nStandard Out:\n#{stdout}\n\nStandard Error:\n#{stderr}")
      end

      Logger.debug ("Cleaning up dangling images...")
      case execute_async(docker, "docker rmi $(DOCKER_HOST=#{docker.docker_host}  docker images -q -f dangling=true)", nil) do
        {:ok, result, docker_output} -> Logger.debug ("Successfully cleaned up dangling images:\n#{result}\n\nDocker Tag Output:  #{docker_output}")
        {:error, reason, stdout, stderr} -> Logger.error("Failed to clean up dangling images:  #{inspect reason}\n\nStandard Out:\n#{stdout}\n\nStandard Error:\n#{stderr}")
      end
         
      Logger.debug ("Successfully completed docker cache cleanup commands")
      :ok
    rescue e in _ -> {:error, "An error occurred cleaning up docker cache:  #{inspect e}"}
    end
  end

  @doc """
  Method to execute a docker build.
  """
  @spec build(Docker, Fun) :: {:ok, String.t()} | {:error, String.t()}
  def build(docker, interrupt_handler \\ nil) do
    Logger.info ("Requesting docker build...")

    result = execute_async(docker, "docker build --force-rm=true --no-cache=true --rm=true -t #{docker.docker_repo_url} .", interrupt_handler, docker.stdout_build_log_uuid, docker.stderr_build_log_uuid)
    case result do  
      {:ok, stdout, stderr} ->
        IO.puts "stdout: "
        IO.inspect stdout
        # Step 0 : FROM ubuntu
        # ---> 9cbaf023786c
        # ...
        # Successfully built 87793b8f30d9
        # stdout will look like the above!
        
        # ["Step 0 : FROM ubuntu\n ---> 9cbaf023786c ... ---> 87793b8f30d9\n", "87793b8f30d9\n"]
        parsed_output = String.split(stdout, "Successfully built ")
        # "87793b8f30d9"
        image_id = List.last(Regex.run(~r/^[a-zA-Z0-9]*/, List.last(parsed_output)))
        Logger.debug ("Successfully built docker image #{image_id}\nDocker Build Output:  #{stdout}\n\n#{stderr}")
        {:ok, image_id}
      {:error, reason, stdout, stderr} ->
        error_msg = "Failed to build docker image:  #{inspect reason}\n\nStandard Out:\n#{stdout}\n\nStandard Error:\n#{stderr}"
        Logger.error(error_msg)
        {:error, error_msg}        
    end
  end

  @doc """
  Method to execute add a docker tag.
  """
  @spec tag(Docker, String.t(), [String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def tag(docker, image_id, [tag|remaining_tags]) do   
    Logger.info ("Requesting docker tag #{tag}...")
    case execute_async(docker, "docker tag --force=true #{image_id} #{tag}", nil) do
      {:ok, result, docker_output} ->
        Logger.debug ("Successfully tagged docker image #{result}\nDocker Tag Output:  #{docker_output}")
        tag(docker, image_id,remaining_tags)
      {:error, reason, stdout, stderr} ->
        error_msg = "Failed to tag docker image #{image_id}: #{inspect reason}\n\nStandard Out:\n#{stdout}\n\nStandard Error:\n#{stderr}"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  @doc """
  Method to execute add a docker tag.
  """
  @spec tag(Docker, String.t(), [String.t()]) :: :ok | :error
  def tag(_, _, []) do
    {:ok, ""}
  end  

  @doc """
  Method to execute a docker push to a specified Docker registry.
  """
  @spec push(Docker) :: :ok | :error
  def push(docker) do
    Logger.info ("Requesting docker push...")
    case execute_async(docker, "docker push #{docker.docker_repo_url}", nil) do
      {:ok, image_id, docker_output} ->
        Logger.debug ("Successfully pushed docker image\nDocker Push Output:  #{docker_output}")
        {:ok, image_id}
      {:error, reason, stdout, stderr} ->
        error_msg = "Failed to push docker image: #{inspect reason}\n\nStandard Out:\n#{stdout}\n\nStandard Error:\n#{stderr}"
        Logger.error(error_msg)
        {:error, error_msg}        
    end
  end

  @doc """
  Method to execute a docker pull from a specified Docker registry.
  """
  @spec pull(Docker, String.t()) :: :ok | {:error, String.t()}
  def pull(docker, image_name) do
    Logger.info ("Requesting docker pull...")
    case execute_async(docker, "docker pull #{image_name}", nil) do
      {:ok, _, docker_output} ->
        Logger.debug ("Successfully pulled docker image\nDocker Pull Output:  #{docker_output}")
        :ok
      {:error, reason, stdout, stderr} ->
        error_msg = "Failed to pull docker image: #{inspect reason}\n\nStandard Out:\n#{stdout}\n\nStandard Error:\n#{stderr}"
        Logger.error(error_msg)
        {:error, error_msg}        
    end
  end

  @doc """
  Method to execute a docker login against a specified Docker registry.
  """
  @spec login(Docker) :: :ok | :error
  def login(docker) do
    Logger.info ("Requesting docker login...")

    if docker.authenticated == true do
      :ok
    else
      docker_cmd = "DOCKER_HOST=#{docker.docker_host} docker login -e=\"#{docker.registry_email}\" -u=\"#{docker.registry_username}\" -p=\"#{docker.registry_password}\" #{docker.registry_url}"
      Logger.debug ("Executing Docker command:  #{docker_cmd}")
      case Util.execute_command(docker_cmd) do
        {_, 0} -> :ok
        {login_message, _} -> {:error, "Docker login has failed:  #{login_message}"}
      end
    end
  end  

  @spec log_file_from_uuid(String.t) :: String.t
  def log_file_from_uuid uuid do
    "#{Application.get_env(:openaperture_builder, :tmp_dir)}/docker/#{uuid}.log"
  end

  @spec execute_async(Docker.t, String.t, Fun, String.t, String.t)  :: {:ok, String.t, String.t} | {:error, String.t, String.t, String.t}
  def execute_async(docker, docker_cmd, interrupt_handler, stdout_log_uuid \\ UUID.uuid1(), stderr_log_uuid \\ UUID.uuid1()) do
    File.mkdir_p("#{Application.get_env(:openaperture_builder, :tmp_dir)}/docker")

    stdout_file = log_file_from_uuid stdout_log_uuid
    stderr_file = log_file_from_uuid stderr_log_uuid
    resolved_cmd = "DOCKER_HOST=#{docker.docker_host} #{docker_cmd} 2> #{stderr_file} > #{stdout_file}"

    opts = case docker.output_dir do
      nil -> []
      output_dir   ->
        File.mkdir_p(output_dir)
        [dir: output_dir]
    end
    cmd_ret = AsyncCmd.execute(resolved_cmd, opts, %{
      on_startup: fn -> 
        Logger.debug ("Executing Docker command:  #{resolved_cmd}")
      end,
      on_completed: fn ->      
      end,
      on_interrupt: interrupt_handler
      })
    out_text = read_output_file(stdout_file)
    err_text = read_output_file(stderr_file)
    File.rm_rf(stdout_file)
    File.rm_rf(stderr_file)  
    case cmd_ret do
      {:error, reason} -> {:error, reason, out_text, err_text}
      :ok -> {:ok, out_text, err_text}
    end
  end

  @doc false
  # Method to read in a file and return contents
  @spec read_output_file(String.t()) :: String.t()
  defp read_output_file(docker_output_file) do
    if File.exists?(docker_output_file) do
      File.read!(docker_output_file)
    else
      raise "Unable to read docker output file #{docker_output_file} - file does not exist!"
    end
  end
end
