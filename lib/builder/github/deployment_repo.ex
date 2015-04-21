require Logger

defmodule OpenAperture.Builder.DeploymentRepo do

  alias OpenAperture.Builder.Workflow
  alias OpenAperture.Builder.Github
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Fleet.EtcdCluster

  alias OpenAperture.Builder.GitHub.Repo, as: GithubRepo

  defstruct output_dir: nil,
            github_deployment_repo: nil,
            github_source_repo: nil,
            etcd_token: nil,
            docker_repo_name: nil

  @moduledoc """
  This module provides a data struct to represent an openaperture <project>_docker repository. Initializing the struct
  will download the contents of the repo and populate the struct with all available information
  """

  @doc """
  Method to create a populated DeploymentRepo from a Workflow
  """
  @spec init_from_workflow(Workflow.t) :: {:ok, DeploymentRepo} | {:error, term}
  def init_from_workflow(workflow) do
    cond do
      workflow.source_repo_git_ref == nil -> {:error, "Missing source_repo_git_ref"}
      workflow.deployment_repo == nil -> {:error, "Missing deployment_repo"}
      true ->
        output_dir = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/deployment_repos/#{workflow.id}"
        try do
          repo = %OpenAperture.Builder.DeploymentRepo{
            output_dir: output_dir
          }

          if workflow.deployment_repo_git_ref == nil do
            deployment_repo_git_ref = "master"
          else
            deployment_repo_git_ref = workflow.deployment_repo_git_ref
          end
          repo = %{repo | github_deployment_repo: download!(repo, workflow)}
          repo = %{repo | source_repo: populate_source_repo!(repo, workflow)}
          repo = %{repo | etcd_token: populate_etcd_token!(repo)}
          repo = %{repo | docker_repo_name: populate_docker_repo_name!(repo)}

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

  @doc """
  Method to download a DeploymentRepo locally
  """
  @spec download!(DeploymentRepo, Workflow.t) :: GithubRepo.t
  def download!(repo, workflow) do
    case download(repo, workflow) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec download(DeploymentRepo, Workflow.t) :: {:ok, GithubRepo} | {:error, String.t()}
  defp download(repo, workflow) do
		Logger.info "Downloading Deployment repo..."
    github_repo = %GithubRepo{
      local_repo_path: repo.output_dir, 
      remote_url: GithubRepo.resolve_github_repo_url(workflow.deployment_repo), 
      branch: workflow.deployment_repo_git_ref
    }

    case Github.clone(github_repo) do
      :ok ->
        case Github.checkout(github_repo) do
          :ok -> {:ok, github_repo}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Method to download a DeploymentRepo locally
  """
  @spec populate_source_repo!(DeploymentRepo, Workflow.t) :: SourceRepo
  def populate_source_repo!(repo, workflow) do
    case populate_source_repo(repo, workflow) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec populate_source_repo(DeploymentRepo, Workflow.t) :: {:ok, SourceRepo} | {:error, String.t()}
  defp populate_source_repo(repo, workflow) do
    case resolve_source_info(repo) do
      {:ok, source_info} ->
        source_repo_option = source_info["source_repo"]

        #if source_commit_hash was passed in, override what's in the source.json (if present)
        source_repo_git_ref_option = if workflow.source_repo_git_ref != nil do
          workflow.source_repo_git_ref
        else
          source_info["source_repo_git_ref"]
        end

        case source_repo_option do
          nil -> {:ok, nil}
          _   -> {:ok, SourceRepo.create!(workflow.id, workflow.source_repo, source_repo_git_ref_option)}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  @spec resolve_source_info(DeploymentRepo) :: {:ok, Map} | {:error, term}
  defp resolve_source_info(repo) do
    output_path = "#{repo.output_dir}/source.json"

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

  @spec populate_etcd_token!(DeploymentRepo) :: String.t
  defp populate_etcd_token!(repo) do
    case populate_etcd_token(repo) do
      {:ok, token} -> token
      {:error, reason} -> raise reason
    end
  end

  @spec populate_etcd_token(DeploymentRepo) :: {:ok, String.t()} | {:error, term}
  defp populate_etcd_token(repo) do
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

  @doc """
  Method to retrieve the associated Docker repository name
  """
  @spec populate_docker_repo_name!(DeploymentRepo) :: String.t
  def populate_docker_repo_name!(repo) do
    case populate_docker_repo_name(repo) do
      {:ok, docker_repo_name} -> docker_repo_name
      {:error, reason} -> raise reason
    end
  end

  @spec populate_docker_repo_name(DeploymentRepo) :: {:ok, String.t()} | {:error, String.t()}
  defp populate_docker_repo_name(repo) do
    if File.exists?("#{repo.output_dir}/docker.json") do
      case JSON.decode(File.read!("#{repo.output_dir}/docker.json")) do
        {:ok, json} -> 
          case json["docker_url"] do
            nil -> {:error, "Unable to get the docker repo name, docker_repo_name not specified and docker_url not specified in docker.json"}
            _   -> {:ok, json["docker_url"]}
          end
        {:error, reason} -> {:error, inspect reason}
      end
    else
      {:error, "Unable to get the docker repo name, docker_repo_name not specified and #{repo.output_dir}/docker.json does not exist!"}
    end
  end

  @spec update_file(String.t, String.t, List, GithubRepo.t, term) :: term
  defp update_file(template_path, output_path, template_options, github_deployment_repo, type) do
    Logger.info("Resolving #{inspect type} from template #{template_path}...")

    if File.exists?(template_path) do
      new_version = EEx.eval_file(template_path, template_options)

      if File.exists?(output_path) do
        if new_version != File.read!(output_path) do
          # The new version is different from the existing file, so we need to
          # replace the existing file's contents with the new contents.
          File.write!(output_path, new_version)
          Github.add(github_deployment_repo, output_path)
          true
        else
          # The template is the same as what's already there
          Logger.info("New version of #{inspect type} matches contents at #{inspect output_path}. File not updated.")
          false
        end
      else
        Logger.info("#{inspect output_path} doesn't exist. Creating it with template contents.")
        File.write!(output_path, new_version)
        Github.add(github_deployment_repo, output_path)
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
    updated_dockerfile? = update_file(repo.output_dir <> "/Dockerfile.eex", repo.output_dir <> "/Dockerfile", template_options, repo.github_deployment_repo, :dockerfile)

    updated_install? = update_file(repo.output_dir <> "/install.sh.eex", repo.output_dir <> "/install.sh", template_options, repo.github_deployment_repo, :install_sh)

    updated_update? = update_file(repo.output_dir <> "/update.sh.eex", repo.output_dir <> "/update.sh", template_options, repo.github_deployment_repo, :update_sh)

    updated_dockerfile? || updated_install? || updated_update?
  end

  @doc """
  Method to run the templating engine against any service files in the repo. Returns true if any changes are made.
  """
  @spec resolve_service_file_templates(DeploymentRepo, List) :: term
  def resolve_service_file_templates(repo, template_options) do
    case File.ls("#{repo.output_dir}") do
      {:ok, files} ->
        resolve_service_file(files, repo.github_deployment_repo, repo.output_dir, template_options, false)
      {:error, reason} ->
        Logger.error("Unable to find any service files in #{repo.output_dir}:  #{reason}!")
        false
    end
  end

  @doc """
  Method to run the templating engine against any service files in the repo. Returns true if any changes are made.
  """
  @spec checkin_pending_changes(DeploymentRepo, String.t()) :: :ok | {:error, String.t()}
  def checkin_pending_changes(repo, message) do
    github = repo.github

    case Github.commit(github, message) do
      :ok -> Github.push(github)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Method to retrieve all of the currently associated Units
  """
  @spec get_units(DeploymentRepo) :: List
  def get_units(repo) do
    Logger.debug("Retrieving Units for repo #{repo.output_dir}...")
    case File.ls("#{repo.output_dir}") do
      {:ok, files} ->
        get_unit(files, repo.output_dir, [])
      {:error, reason} ->
        Logger.error("there are no service files in #{repo.output_dir}:  #{reason}!")
        []
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
      unitOptions = OpenAperture.Fleet.ServiceFileParser.parse(output_path)
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
  defp resolve_service_file([filename|remaining_files], github_deployment_repo, source_dir, replacements, units_commit_required) do
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
        Github.add(github_deployment_repo, output_path)
        units_commit_required = true
      end
    end

    resolve_service_file(remaining_files, github_deployment_repo, source_dir, replacements, units_commit_required)
  end

  @spec resolve_service_file(List, term, String.t(), Map, term) :: term
  defp resolve_service_file([], _, _, _, units_commit_required), do: units_commit_required
  
  @doc """
  Method to create a docker image from the Deployment repository and store it in a
  remote docker repository

  ## Options

  The `repo` option defines deployment repo agent.

  ## Return values

  :ok or {:error, reason}
  """
  @spec create_docker_image(DeploymentRepo, List) :: :ok | {:error, String.t()}
  def create_docker_image(repo, tags) do
    case Docker.create(%{output_dir: repo.output_dir, docker_repo_url: repo.docker_repo_name}) do
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
                      {:ok, _} -> :ok
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
end
