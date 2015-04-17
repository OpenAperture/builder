require Logger

defmodule OpenAperture.Builder.Docker do
  alias OpenAperture.Builder.Util
  defstruct docker_repo_url: nil,
            docker_host: nil,
            output_dir: nil,
            image_id: nil,
            authenticated: false

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
      true -> {:ok, docker}
    end
  end

  @spec empty(String.t()) :: Boolean
  defp empty(val) do
    val == nil || val == ""
  end

  @doc """
  Method to cleanup any Docker cache files that were generated during builds
  """
  #@spec cleanup_cache(Docker)
  def cleanup_cache(docker) do
    Logger.info ("Cleaning up docker cache...")

    Logger.info ("Stopping containers..")
    case  execute_docker_cmd(docker, "docker stop $(DOCKER_HOST=#{docker.docker_host} docker ps -a -q)") do
      {:ok, stdout, stderr} ->
        Logger.debug ("Successfully stopped containers")
        Logger.debug("#{stdout}\n#{stderr}")
      {:error, _, _} ->
        Logger.debug("No containers to stop")
    end

    #http://jimhoskins.com/2013/07/27/remove-untagged-docker-images.html
    Logger.info ("Cleaning up stopped containers...")
    case  execute_docker_cmd(docker, "docker rm $(DOCKER_HOST=#{docker.docker_host} docker ps -a -q)") do
      {:ok, stdout, stderr} ->
        Logger.debug ("Successfully cleaned up stopped containers")
        Logger.debug("#{stdout}\n#{stderr}")
      {:error, _, _} ->
        Logger.debug("No containers to clean up")
    end

    Logger.info ("Cleaning up untagged images...")
    case  execute_docker_cmd(docker, "docker rmi $(DOCKER_HOST=#{docker.docker_host} docker images | grep \"^<none>\" | awk \"{print $3}\")") do
      {:ok, stdout, stderr} ->
        Logger.debug ("Successfully cleaned up untagged images")
        Logger.debug("#{stdout}\n#{stderr}")
      {:error, _, _} ->
        Logger.debug("No untagged images to clean up")
    end

    #http://jonathan.bergknoff.com/journal/building-good-docker-images
    Logger.info ("Cleaning up remaining images...")
    case  execute_docker_cmd(docker, "docker rmi $(DOCKER_HOST=#{docker.docker_host} docker images -q)") do
      {:ok, stdout, stderr} ->
        Logger.debug ("Successfully cleaned up remaining images")
        Logger.debug("#{stdout}\n#{stderr}")
      {:error, _, _} ->
        Logger.debug("No remaining images to clean up")
    end

    :ok
  end 

  @doc """
  Method to cleanup any cache associated with an image id
  """
  @spec cleanup_image_cache(Docker, String.t()) :: :ok | {:error, String.t()}
  def cleanup_image_cache(docker, image_id \\ nil) do
    try do
      cond do
        image_id != nil -> cleanup_image(docker, image_id)
        docker.image_id != nil -> cleanup_image(docker, docker.image_id)
        true -> {:error, "docker image id not specified in cleanup_image_cache"}
      end
    rescue e in _ -> {:error, "An error occurred cleaning up cache for image #{image_id}:  #{inspect e}"}
    end
  end

  @doc """
  Method to cleanup any dangling images that remain on the host
  """
  @spec cleanup_image(Docker, String.t()) :: :ok | {:error, String.t()}
  def cleanup_image(docker, image_id) do
    Logger.info ("Cleaning up image #{image_id}...")

    #cleanup containers
    all_containers = get_containers(docker)
    image_containers = find_containers_for_image(docker, image_id, all_containers)
    cleanup_container(docker, image_containers)

    #cleanup the image
    case  execute_docker_cmd(docker, "docker rmi #{image_id}") do
      {:ok, _, _} -> Logger.debug("Successfully removed image #{image_id}")
      {:error, stdout, stderr} -> {:error, "An error occurred removing image #{image_id}:  #{stdout}\n#{stderr}"}
    end 

    #cleanup dangling images
    cleanup_dangling_images(docker) 
  end

  @doc """
  Method to cleanup any dangling images that remain on the host
  """
  @spec cleanup_dangling_images(pid) :: :ok
  def cleanup_dangling_images(docker) do
    Logger.debug("Disabled dangling image cleanup")
    cleanup_exited_containers(docker)
    #http://jonathan.bergknoff.com/journal/building-good-docker-images
    Logger.info ("Cleaning up dangling images...")
    dangling_images = case  execute_docker_cmd(docker, "docker images -q --filter \"dangling=true\"") do
        {:ok, stdout, _stderr} ->
          if String.length(stdout) > 0 do
            images = String.split(stdout, "\n")
            if images == nil || length(images) == 0 do
              nil
            else
              Enum.reduce images, "", fn(image, dangling_images) ->
                "#{dangling_images} #{image}"
              end
            end
          else
            nil
          end
        {:error, stdout, stderr} -> 
          Logger.debug("An error occurred retrieving dangling images:  #{stdout}\n#{stderr}")
          nil
      end

    if dangling_images != nil do
      Logger.debug("Removing the following dangling images:  #{dangling_images}")
      case  execute_docker_cmd(docker, "docker rmi #{dangling_images}") do
        {:error, stdout, stderr} -> Logger.debug("An error occurred deleting dangling images:  #{stdout}\n#{stderr}")
        _ -> Logger.debug("Successfully cleaned up dangling images")
      end     
    end
    :ok
  end

  @doc """
  Method to remove all exited containers
  """
  @spec cleanup_exited_containers(Docker) :: List
  def cleanup_exited_containers(docker) do
    Logger.info ("Cleaning up existed containers...")

    exited_containers = get_exited_containers(docker)
    if length(exited_containers) > 0 do
      container_list = Enum.reduce exited_containers, "docker rm ", fn(container, container_list) ->
        "#{container_list} #{container}"
      end 

      case  execute_docker_cmd(docker, container_list) do
        {:ok, _, _} -> Logger.debug("Successfully removed the stopped containers")
        {:error, stdout, stderr} -> Logger.debug("An error occurred stopping containers:  #{stdout}\n#{stderr}")
      end               
    else
      Logger.debug("There are no exited containers to cleanup")
    end

    :ok
  end

  @doc """
  Method to retrieve all exited containers
  """
  @spec get_exited_containers(Docker) :: List
  def get_exited_containers(docker) do
    Logger.info ("Retrieving all exited containers...")
    case  execute_docker_cmd(docker, "docker ps -a | grep Exited | awk '{print$1}'") do
      {:ok, stdout, _} ->
        if String.length(stdout) == 0 do
          []
        else
          containers = String.split(stdout, "\n")
          Logger.debug("The following exited containers were found:  #{inspect containers}")
          containers
        end
      {:error, stdout, stderr} -> 
        Logger.error("An error occurred retrieving the containers:  #{stdout}\n#{stderr}")
      []
    end
  end

  @doc """
  Method to stop and remove the running containers
  """
  @spec cleanup_container(Docker, List) :: :ok
  def cleanup_container(docker, [container|remaining_containers]) do
    Logger.debug("Stopping container #{container}...")
    case  execute_docker_cmd(docker, "docker stop #{container}") do
      {:ok, _, _} -> Logger.debug("Successfully stopped container #{container}")
      {:error, stdout, stderr} -> Logger.debug("An error occurred stopping container #{container}:  #{stdout}\n#{stderr}")
    end

    Logger.debug("Removing container #{container}...")
    case  execute_docker_cmd(docker, "docker rm #{container}") do
      {:ok, _, _} -> 
        Logger.debug("Successfully removed container #{container}")
      {:error, stdout, stderr} -> 
        Logger.error("An error occurred removing container #{container}:  #{stdout}\n#{stderr}")
    end 
    cleanup_container(docker, remaining_containers)   
  end

  @doc """
  Method to stop and remove the running containers
  """
  @spec cleanup_container(Docker, List) :: :ok
  def cleanup_container(_docker, []) do
    Logger.debug("Successfully cleaned up all containers")
    :ok
  end

  @doc """
  Method to find all of the containers running on a docker host
  """
  @spec get_containers(pid) :: List
  def get_containers(docker) do
    Logger.info ("Retrieving all containers...")
    case  execute_docker_cmd(docker, "docker ps -aq") do
      {:ok, stdout, _} ->
        if String.length(stdout) == 0 do
          []
        else
          containers = String.split(stdout, "\n")
          Logger.debug("The following containers were found:  #{inspect containers}")
          containers
        end
      {:error, stdout, stderr} -> 
        Logger.error("An error occurred retrieving the containers:  #{stdout}\n#{stderr}")
      []
    end    
  end

  @doc """
  Method to parse through a list of containers to determine if any are running against an image
  """
  @spec find_containers_for_image(Docker, String.t(), List) :: List
  def find_containers_for_image(docker, image_id, containers) do
    Logger.info ("Finding containers for image #{image_id}...")
    if containers == nil || length(containers) == 0 do
      []
    else
      inspect_cmd = Enum.reduce containers, "docker inspect", fn(container, inspect_cmd) ->
        "#{inspect_cmd} #{container}"
      end

      case execute_docker_cmd(docker, inspect_cmd) do
        {:ok, stdout, _} ->
          Enum.reduce JSON.decode!(stdout), [], fn(container_info, containers_for_image) ->
            if (container_info["Image"] != nil && String.contains?(container_info["Image"], image_id)) do
              Logger.debug("Container #{container_info["Id"]} is using image #{image_id}")
              containers_for_image ++ [container_info["Id"]]
            else
              containers_for_image
            end
          end
        {:error, stdout, stderr} -> 
          Logger.error("An error occurred retrieving the containers:  #{stdout}\n#{stderr}")
          []
      end
    end
  end

  @doc """
  Method to execute a docker build against a specified Docker agent.
  """
  @spec build(Docker) :: {:ok, String.t()} | {:error, String.t()}
  def build(docker) do
    Logger.info ("Requesting docker build...")
    case  execute_docker_cmd(docker, "docker build --force-rm=true --no-cache=true --rm=true -t #{docker.docker_repo_url} .") do
      {:ok, stdout, stderr} ->

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
      {:error, stdout, stderr} ->
        error_msg = "Failed to build docker image:\n#{stdout}\n\n#{stderr}"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  @doc """
  Method to execute add a docker tag against a specified Docker agent.
  """
  @spec tag(Docker, String.t(), [String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def tag(docker, image_id, [tag|remaining_tags]) do   
    Logger.info ("Requesting docker tag #{tag}...")
    case execute_docker_cmd(docker, "docker tag --force=true #{image_id} #{tag}") do
      {:ok, result, docker_output} ->
        Logger.debug ("Successfully tagged docker image #{result}\nDocker Tag Output:  #{docker_output}")
        tag(docker, image_id,remaining_tags)
      {:error, result, docker_output} ->
        error_msg = "Failed to tag docker image #{image_id}:\n#{result}\n\n#{docker_output}"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end

  @doc """
  Method to execute add a docker tag against a specified Docker agent.
  """
  @spec tag(pid, String.t(), [String.t()]) :: :ok | :error
  def tag(_, _, []) do
    {:ok, ""}
  end  

  @doc """
  Method to execute a docker push against a specified Docker agent.
  """
  @spec push(Docker) :: :ok | :error
  def push(docker) do
    Logger.info ("Requesting docker push...")
    case  execute_docker_cmd(docker, "docker push #{docker.docker_repo_url}") do
      {:ok, image_id, docker_output} ->
        Logger.debug ("Successfully pushed docker image\nDocker Push Output:  #{docker_output}")
        {:ok, image_id}
      {:error, result, docker_output} ->
        error_msg = "Failed to push docker image:\n#{result}\n\n#{docker_output}"
        Logger.error(error_msg)
        {:error, error_msg}        
    end
  end

  @doc """
  Method to execute a docker pull against a specified Docker agent.
  """
  @spec pull(Docker, String.t()) :: :ok | {:error, String.t()}
  def pull(docker, image_name) do
    Logger.info ("Requesting docker pull...")
    case  execute_docker_cmd(docker, "docker pull #{image_name}") do
      {:ok, _, docker_output} ->
        Logger.debug ("Successfully pulled docker image\nDocker Pull Output:  #{docker_output}")
        :ok
      {:error, result, docker_output} ->
        error_msg = "Failed to pull docker image:\n#{result}\n\n#{docker_output}"
        Logger.error(error_msg)
        {:error, error_msg}        
    end
  end

  @doc """
  Method to execute a docker login against a specified Docker agent.
  """
  @spec login(Docker) :: :ok | :error
  def login(docker) do
    Logger.info ("Requesting docker login...")
    case dockerhub_login(docker) do
      {_, 0} -> :ok
      {login_message, _} -> {:error, "Docker login has failed:  #{login_message}"}      
    end
  end  

  @doc false
  # Method to execute a Docker login to Docker Hub
  @spec dockerhub_login(Docker) :: {Collectable.t, exit_status :: non_neg_integer}
  defp dockerhub_login(docker) do
    if docker.authenticated == true do
      {"Login Successful", 0}
    else
      docker_cmd = "DOCKER_HOST=#{docker.docker_host} docker login #{Application.get_env(:openaperture_builder, :docker_registry_url)} -e=\"#{Application.get_env(:openaperture_builder, :docker_registry_email)}\" -u=\"#{Application.get_env(:openaperture_builder, :docker_registry_username)}\" -p=\"#{Application.get_env(:openaperture_builder, :docker_registry_password)}\""
      Logger.debug ("Executing Docker command:  #{docker_cmd}")
      Util.execute_command(docker_cmd)
    end
  end

  @doc false
  # Method to execute a Docker command.  Will wrap the command with a Docker login and store stdout and stderr
  @spec execute_docker_cmd(pid, String.t()) :: {:ok, String.t(), String.t()} | {:error, String.t(), String.t()}
  defp execute_docker_cmd(docker, docker_cmd) do
    case dockerhub_login(docker) do
      {_, 0} ->
        File.mkdir_p("#{Application.get_env(:openaperture_builder, :tmp_dir)}/docker")

        stdout_file = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/docker/#{UUID.uuid1()}.log"
        stderr_file = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/docker/#{UUID.uuid1()}.log"
        resolved_cmd = "DOCKER_HOST=#{docker.docker_host} #{docker_cmd} 2> #{stderr_file} > #{stdout_file}"

        Logger.debug ("Executing Docker command:  #{resolved_cmd}")
        try do
          case Util.execute_command(resolved_cmd, "#{docker.output_dir}") do
            {stdout, 0} ->
              {:ok, read_output_file(stdout_file), read_output_file(stderr_file)}
            {stdout, _} ->
              {:error, read_output_file(stdout_file), read_output_file(stderr_file)}
          end
        after
          File.rm_rf(stdout_file)
          File.rm_rf(stderr_file)
        end
      {login_message, _} ->
        {:error, "Dockerhub login has failed.", login_message}
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
