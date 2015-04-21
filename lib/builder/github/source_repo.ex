require Logger

defmodule OpenAperture.Builder.SourceRepo do

  alias OpenAperture.Builder.Workflow
  alias OpenAperture.Builder.Github
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.GitHub.Repo, as: GithubRepo

  defstruct output_dir: nil,
            github_source_repo: nil

  @spec create!(String.t, String.t, String.t) :: {:ok, SourceRepo} | {:error, term}
  def create!(workflow_id, source_repo_url, source_repo_git_ref) do
    output_dir = "#{Application.get_env(:openaperture_builder, :tmp_dir)}/source_repos/#{workflow_id}"
    try do
      repo = %OpenAperture.Builder.SourceRepo{
        output_dir: output_dir
      }

      repo = %{repo | github_source_repo: download!(repo, source_repo_url, source_repo_git_ref)}

      {:ok, repo}
    rescue
      e in RuntimeError -> {:error, e.message}
    end
  end

  @spec download!(SourceRepo, String.t, String.t) :: DeploymentRepo
  def download!(repo, source_repo_url, source_repo_git_ref) do
    case download(repo, source_repo_url, source_repo_git_ref) do
      {:ok, repo} -> repo
      {:error, reason} -> raise reason
    end
  end

  @spec download(SourceRepo, String.t, String.t) :: {:ok, GithubRepo} | {:error, String.t()}
  defp download(repo, source_repo_url, source_repo_git_ref) do
    Logger.info "Downloading Source repo..."
    github_repo = %GithubRepo{
      local_repo_path: repo.output_dir, 
      remote_url: GithubRepo.resolve_github_repo_url(source_repo_url), 
      branch: source_repo_git_ref
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
          
          #deployment_repo = DeploymentRepo.create(%{docker_repo: docker_repo, docker_repo_branch: docker_repo_branch})
          #repo_options = Map.merge(repo_options, %{deployment_repo: deployment_repo})
          #Agent.update(repo, fn _ -> repo_options end)
          #deployment_repo          
          nil
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
end
