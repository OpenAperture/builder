require Logger

defmodule OpenAperture.Builder.SourceRepo do

  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Builder.Git
  alias OpenAperture.Builder.GitRepo, as: GitRepo

  defstruct output_dir: nil,
            github_source_repo: nil

  @type t :: %__MODULE__{}
  
  @moduledoc """
  This module provides a data struct to represent a source repository. Initializing the struct
  will download the contents of the repo and populate the struct with all available information
  """

  @doc """
  Method to create a populated SourceRepo
  """
  @spec create!(String.t, String.t, String.t) :: {:ok, SourceRepo} | {:error, term}
  def create!(workflow_id, source_repo_url, source_repo_git_ref) do
    output_dir = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/source_repos/#{workflow_id}"
    try do
      repo = %OpenAperture.Builder.SourceRepo{
        output_dir: output_dir
      }

      %{repo | github_source_repo: download!(repo, source_repo_url, source_repo_git_ref)}
    rescue
      e in RuntimeError -> {:error, e.message}
    end
  end

  @doc """
  Method to download the repository locally
  """
  @spec download!(SourceRepo, String.t, String.t) :: SourceRepo
  def download!(repo, source_repo_url, source_repo_git_ref) do
    case download(repo, source_repo_url, source_repo_git_ref) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec download(SourceRepo, String.t, String.t) :: {:ok, GitRepo} | {:error, String.t()}
  defp download(repo, source_repo_url, source_repo_git_ref) do
    Logger.info "Downloading Source repo..."
    github_repo = %GitRepo{
      local_repo_path: repo.output_dir, 
      remote_url: GitRepo.resolve_github_repo_url(source_repo_url), 
      branch: source_repo_git_ref
    }

    case Git.clone(github_repo) do
      :ok ->
        case Git.checkout(github_repo) do
          :ok -> {:ok, github_repo}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end


  @doc """
  Method to cleanup any artifacts associated with the deploy repo PID
   
  ## Options
   
  The `repo` option defines the repo PID
  """
  @spec cleanup(pid) :: term
  def cleanup(repo) do
    if (repo.output_dir != nil && String.length(repo.output_dir) > 0), do: File.rm_rf(repo.output_dir)
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
    resolve_openaperture_info(repo)
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
  @spec resolve_openaperture_info(SourceRepo) :: Map
  defp resolve_openaperture_info(repo) do
    output_path = "#{repo.output_dir}/openaperture.json"

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

  @spec get_current_commit_hash(SourceRepo) :: String.t
  def get_current_commit_hash(source_repo) do
    Git.get_current_commit_hash(source_repo.github_source_repo)
  end
end
