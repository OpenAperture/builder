require Logger

defmodule OpenAperture.Builder.DeploymentRepo do
  alias OpenAperture.Builder.Github
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Fleet.EtcdCluster

  defstruct request_id: nil,
            output_dir: nil,
            source_commit_hash: nil,
            source_repo: nil,
            source_repo_git_ref: nil,
            deployment_repo: nil,
            deployment_repo_git_ref: "master",
            docker_repo_name: nil,
            docker: nil,
            github: nil,
            etcd_cluster: nil,
            download_status: nil,
            download_error: nil

  @moduledoc """
  This module provides a data struct to represent an openaperture project_docker repository. Initializing the struct
  will download the contents of the repo and populate the struct with all available information
  """

  @spec init(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, term}
  def init(repo) do
    cond do
      repo.source_repo_git_ref == nil -> {:error, "Missing source_repo_git_ref"}
      repo.deployment_repo == nil -> {:error, "Missing deployment_repo"}
      true ->
        request_id = "#{UUID.uuid1()}"
        output_dir = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/deployment_repos/#{request_id}"
        try do
          repo = %{repo | output_dir: output_dir, request_id: request_id}
               |> download!
               |> populate_source_repo!
               |> populate_etcd_cluster!
               |> populate_docker_repo_name!
          {:ok, repo}
        rescue
          e in RuntimeError -> {:error, e.message}
        end
    end
  end

  @doc """
  Method to cleanup any artifacts associated with the deploy repo PID
  """
  @spec cleanup(DeploymentRepo) :: term
  def cleanup(repo) do
    if (repo.output_dir != nil && String.length(repo.output_dir) > 0), do: File.rm_rf(repo.output_dir)
  end

  @spec download!(DeploymentRepo) :: DeploymentRepo
  def download!(repo) do
    case download(repo) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec download(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, String.t()}
  defp download(repo) do
		Logger.info "Beginning to download the deployment repo..."
    case Github.create(%{output_dir: repo.output_dir, repo_url: Github.resolve_github_repo_url(repo.deployment_repo), branch: repo.deployment_repo_git_ref}) do
      {:ok, github} ->
        repo =  %{repo | github: github}
        case Github.clone(github) do
          :ok ->
            case Github.checkout(github) do
              :ok ->
                downloaded_files = File.ls!(repo.output_dir)
                Logger.debug("Git clone and checkout of repository #{repo.deployment_repo} has downloaded the following files:  #{inspect downloaded_files}")
                {:ok, repo}
              {:error, reason} -> {:error, reason}
            end
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @spec populate_source_repo!(DeploymentRepo) :: DeploymentRepo
  def populate_source_repo!(repo) do
    case populate_source_repo(repo) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec populate_source_repo(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, String.t()}
  defp populate_source_repo(repo) do
    if (repo.source_repo != nil) do
      {:ok, %{repo | source_repo: SourceRepo.create!(%{repo: repo.source_repo, repo_branch: repo.source_repo_git_ref})}}
    else
      {status, source_info_or_reason}  = resolve_source_info(repo.output_dir)
      if (status == :ok) do
        source_repo_option = source_info_or_reason["source_repo"]

        #if source_commit_hash was passed in, override what's in the source.json (if present)
        source_repo_git_ref_option = case repo.source_commit_hash do
          nil -> repo.source_commit_hash
          _   -> source_info_or_reason["source_repo_git_ref"]
        end

        case source_repo_option do
          nil -> {:ok, repo}
          _   -> {:ok, %{repo | source_repo: SourceRepo.create!(%{repo: source_repo_option, repo_branch: source_repo_git_ref_option})}}
        end
      else
        {:error, source_info_or_reason}
      end
    end
  end

  @spec resolve_source_info(String.t()) :: {:ok, Map} | {:error, term}
  defp resolve_source_info(source_dir) do
    output_path = "#{source_dir}/source.json"

    if File.exists?(output_path) do
      Logger.info("Resolving source info from #{output_path}...")
      case output_path |> File.read! |> JSON.decode do
        {:ok, json} -> {:ok, json}
        {:error, reason} -> {:error, "An error occurred parsing source.json JSON! #{inspect reason}"}
      end
    else
      {:ok, %{}}
    end
  end

  defp update_file(template_path, output_path, template_options, github, type) do
    Logger.info("Resolving #{inspect type} from template #{template_path}...")

    if File.exists?(template_path) do
      new_version = EEx.eval_file(template_path, template_options)

      if File.exists?(output_path) do
        if new_version != File.read!(output_path) do
          # The new version is different from the existing file, so we need to
          # replace the existing file's contents with the new contents.
          File.write!(output_path, new_version)
          Github.add(github, output_path)
          true
        else
          # The template is the same as what's already there
          Logger.info("New version of #{inspect type} matches contents at #{inspect output_path}. File not updated.")
          false
        end
      else
        Logger.info("#{inspect output_path} doesn't exist. Creating it with template contents.")
        File.write!(output_path, new_version)
        Github.add(github, output_path)
        true
      end
    else
      Logger.info("Template #{template_path} does not exist!")
      false
    end
  end

  @doc """
  Method to run the templating engine against the templated Dockerfile. Returns true if any changes are made.
  """
  @spec resolve_dockerfile_template(DeploymentRepo, List) :: term
  def resolve_dockerfile_template(repo, template_options) do
    github = repo.github
    output_dir = repo.output_dir

    updated_dockerfile? = update_file(output_dir <> "/Dockerfile.eex", output_dir <> "/Dockerfile", template_options, github, :dockerfile)

    updated_install? = update_file(output_dir <> "/install.sh.eex", output_dir <> "/install.sh", template_options, github, :install_sh)

    updated_update? = update_file(output_dir <> "/update.sh.eex", output_dir <> "/update.sh", template_options, github, :update_sh)

    updated_dockerfile? || updated_install? || updated_update?
  end

  @doc """
  Method to run the templating engine against any service files in the repo. Returns true if any changes are made.
  """
  @spec resolve_service_file_templates(DeploymentRepo, List) :: term
  def resolve_service_file_templates(repo, template_options) do
    github = repo.github
    output_dir = repo.output_dir

    case File.ls("#{output_dir}") do
      {:ok, files} ->
        resolve_service_file(files, github, output_dir, template_options, false)
      {:error, reason} ->
        Logger.error("Unable to find any service files in #{output_dir}:  #{reason}!")
        false
    end
  end

  @spec checkin_pending_changes(DeploymentRepo, String.t()) :: :ok | {:error, String.t()}
  def checkin_pending_changes(repo, message) do
    github = repo.github

    case Github.commit(github, message) do
      :ok -> Github.push(github)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_etcd_token(DeploymentRepo) :: {:ok, String.t()} | {:error, term}
  defp get_etcd_token(repo) do
    output_dir = repo.output_dir
    etcd_json = "#{output_dir}/etcd.json"
    if File.exists?(etcd_json) do
      Logger.info("Retrieving the etcd token...")
      case JSON.decode(File.read!(etcd_json)) do
        {:ok, json} -> case json["token"] do
                          nil -> {:error, "token missing from etcd.json"}
                          "" -> {:error, "invalid token in etcd.json"}
                          _ -> {:ok, json["token"]}
                       end
        {:error, reason} -> {:error, "An error occurred parsing etcd JSON!  #{reason}"}
      end
    else
      {:error, "No etcd JSON file is present in this repository!"}
    end
  end

  @spec populate_etcd_cluster!(DeploymentRepo) :: DeploymentRepo
  defp populate_etcd_cluster!(repo) do
    case populate_etcd_cluster(repo) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec populate_etcd_cluster(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, String.t()}
  defp populate_etcd_cluster(repo) do
    case get_etcd_token(repo) do
      {:error, reason} ->
        {:error, reason}
      {:ok, token} ->   
        Logger.debug("Creating an EtcdCluster for token #{token}")
        case EtcdCluster.create(token) do
          {:ok, etcd_cluster} -> {:ok, %{repo | etcd_cluster: etcd_cluster}}
          {:error, reason} -> {:error, "Failed to create etcd cluster:  #{inspect reason}"}
        end
    end
  end

  @doc """
  Method to retrieve all of the currently associated Units
  """
  @spec get_units(DeploymentRepo) :: List
  def get_units(repo) do
    output_dir = repo.output_dir
    Logger.debug("Retrieving Units for repo #{output_dir}...")
    case File.ls("#{output_dir}") do
      {:ok, files} ->
        get_unit(files, output_dir, [])
      {:error, reason} ->
        Logger.error("there are no service files in #{output_dir}:  #{reason}!")
        []
    end
  end

  @spec populate_docker_repo_name!(DeploymentRepo) :: DeploymentRepo
  def populate_docker_repo_name!(repo) do
    case populate_docker_repo_name(repo) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec populate_docker_repo_name(DeploymentRepo) :: {:ok, DeploymentRepo} | {:error, String.t()}
  defp populate_docker_repo_name(repo) do
    if repo.docker_repo_name != nil do
      {:ok, repo}
    else
      output_dir = repo.output_dir
      if File.exists?("#{output_dir}/docker.json") do
        case JSON.decode(File.read!("#{output_dir}/docker.json")) do
          {:ok, json} -> 
            case json["docker_url"] do
              nil -> {:error, "Unable to get the docker repo name, docker_repo_name not specified and docker_url not specified in docker.json"}
              _   -> {:ok, %{repo | docker_repo_name: json["docker_url"]}}
            end
          {:error, reason} -> {:error, inspect reason}
        end
      else
        {:error, "Unable to get the docker repo name, docker_repo_name not specified and #{output_dir}/docker.json does not exist!"}
      end
    end
  end

  @doc """
  Method to create a docker image from the Deployment repository and store it in a
  remote docker repository

  ## Options

  The `repo` option defines deployment repo agent.

  ## Return values

  :ok or {:error, reason}
  """
  @spec create_docker_image(DeploymentRepo, List) :: {:ok, DeploymentRepo} | {:error, String.t()}
  def create_docker_image(repo, tags) do
    output_dir = repo.output_dir

    docker_repo_name = repo.docker_repo_name

    case Docker.create(%{output_dir: output_dir, docker_repo_url: docker_repo_name}) do
      {:ok, docker} ->
        repo = %{repo | docker: docker}
        try do
          case Docker.build(docker) do
            {:ok, image_id} ->
              if (image_id != nil && image_id != "") do
                repo = %{repo | image_id: image_id}
                case Docker.tag(repo.docker, image_id, tags) do
                  {:ok, _} ->
                    case Docker.push(repo.docker) do
                      {:ok, _} -> {:ok, repo}
                      {:error, reason} -> {:error, reason}
                    end
                  {:error, reason} -> {:error, reason}
                end
              else
                {:error,"docker build failed to produce a valid image!"}
              end
            {:error, reason} -> {:error,reason}
          end
        after
          Docker.cleanup_image_cache(repo.docker)
        end
      {:error, reason} -> {:error,reason}
    end
  end

  @doc false
  # Method to retrieve Fleet service Units.
  #
  ## Options
  #
  # The `[filename|remaining_files]` options defines the list of file names to review
  #
  # The `source_dir` options defines where the source files exist
  #
  # The `resolved_units` options defines the list of Units that have been found.
  #
  ## Return Values
  #
  # List of the Units that were generated
  #
  @spec get_unit(List, String.t(), List) :: term
  defp get_unit([filename|remaining_files], source_dir, resolved_units) do
    if String.ends_with?(filename, ".service") do
      output_path = "#{source_dir}/#{filename}"

      Logger.info("Resolving service file #{output_path}...")
      unitOptions = CloudosBuildServer.Fleet.ServiceFileParser.parse(output_path)
      unit = %{
        "name" => filename,
        "options" => unitOptions
      }
      resolved_units = resolved_units ++ [unit]
    else
      Logger.debug("#{filename} is not a service file")
    end

    get_unit(remaining_files, source_dir, resolved_units)
  end

  @doc false
  # Method to retrieve Fleet service Unit.  Ends recursion
  #
  ## Options
  #
  # The `[]` options defines the list of file names to review
  #
  # The `source_dir` options defines where the source files exist
  #
  # The `resolved_units` options defines the list of Units that have been found.
  #
  ## Return Values
  #
  # List of the units that were generated
  #
  @spec get_unit(List, String.t(), List) :: term
  defp get_unit([], _, resolved_units) do
    resolved_units
  end

  @doc false
  # Method to resolve a Fleet service files.
  #
  ## Options
  #
  # The `[filename|remaining_files]` options defines the list of file names to review
  #
  # The `source_dir` options defines where the source files exist
  #
  # The `replacements` options defines which values should be replaced.
  #
  ## Return Values
  #
  # boolean; true if file was replaced and a commit add was performed)
  #

  @spec resolve_service_file(List, term, String.t(), Map, term) :: term
  defp resolve_service_file([filename|remaining_files], github, source_dir, replacements, units_commit_required) do
    if String.ends_with?(filename, ".service.eex") do
      template_path = "#{source_dir}/#{filename}"
      output_path = "#{source_dir}/#{String.slice(filename, 0..-5)}"

      Logger.info("Resolving service file #{output_path} from template #{template_path}...")
      service_file = EEx.eval_file "#{source_dir}/#{filename}", replacements

      file_is_identical = false
      if File.exists?(output_path) do
        existing_service_file = File.read!(output_path)
        if (service_file == existing_service_file) do
          file_is_identical = true
        end
      end

      unless (file_is_identical) do
        File.rm_rf(output_path)
        File.write!(output_path, service_file)
        Github.add(github, output_path)
        units_commit_required = true
      end
    end

    resolve_service_file(remaining_files, github, source_dir, replacements, units_commit_required)
  end

  @spec resolve_service_file(List, term, String.t(), Map, term) :: term
  defp resolve_service_file([], _, _, _, units_commit_required), do: units_commit_required
  
  
end
