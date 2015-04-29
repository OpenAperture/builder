defmodule OpenAperture.Builder.GitRepo do

  @moduledoc """
  This module represents a Git repository, and is used to track the local
  repository's path, the remote repository's URL, and the current
  branch/tag/commit.
  """
  defstruct local_repo_path: nil, remote_url: nil, branch: nil

  @type t :: %__MODULE__{local_repo_path: String.t, remote_url: String.t, branch: String.t}

  @doc """
  Extracts the project name from a GitHub repo URL.

  ## Examples

    iex> OpenAperture.Builder.GitRepo.get_project_name("https://github.com/test_user/test_project")
    "test_project"
  """
  @spec get_project_name(String.t) :: String.t
  def get_project_name(repo_url) when is_binary(repo_url) do
    uri = URI.parse(repo_url)

    uri.path
    |> String.split("/")
    |> List.last
  end

  @spec get_project_name(Repo.t) :: String.t
  def get_project_name(repo) when is_map(repo) do
    repo.remote_url
    |> get_project_name
  end

  @doc """
  Given a A url (absolute, [user|org]/project_name, or [user|org]/project_name.git), builds a GitHub URL. Prepends OAuth
  access credentials to the URL (if configured for the application.)

  ## Examples

    iex> OpenAperture.Builder.GitRepo.resolve_github_repo_url("test_user/test_project")
    "https://github.com/test_user/test_project.git"
    iex> OpenAperture.Builder.GitRepo.resolve_github_repo_url("http://github.com/test_user/test_project")
    "https://github.com/test_user/test_project.git"
    iex> OpenAperture.Builder.GitRepo.resolve_github_repo_url("http://github.com/test_user/test_project.git")
    "https://github.com/test_user/test_project.git"    
    iex> OpenAperture.Builder.GitRepo.resolve_github_repo_url("https://github.com/test_user/test_project")
    "https://github.com/test_user/test_project.git"
    iex> OpenAperture.Builder.GitRepo.resolve_github_repo_url("https://github.com/test_user/test_project.git")
    "https://github.com/test_user/test_project.git"    
    iex> OpenAperture.Builder.GitRepo.resolve_github_repo_url("git@github.com:test_user/test_project.git")
    "git@github.com:test_user/test_project.git"        
  """
  @spec resolve_github_repo_url(String.t) :: String.t
  def resolve_github_repo_url(raw_url) do
    cond do
      raw_url == nil -> nil
      #don't attempt to parse an SSH-formatted request
      String.starts_with?(raw_url, "git@") -> raw_url
      String.starts_with?(raw_url, "http://") || String.starts_with?(raw_url, "https://") ->
        parsed_url = URI.parse(raw_url)

        github_org_project = parsed_url.path
        github_org_project = if String.starts_with?(github_org_project, "/") do
          String.slice(github_org_project, 1, String.length(github_org_project))
        else
          github_org_project
        end

        github_org_project = if String.ends_with?(github_org_project, "/") do
          String.slice(github_org_project, 0, String.length(github_org_project)-1)
        else
          github_org_project
        end

        github_org_project = if String.ends_with?(github_org_project, ".git") do
          String.slice(github_org_project, 0, String.length(github_org_project)-4)
        else
          github_org_project
        end

        get_github_repo_url(github_org_project)        
      true -> get_github_repo_url(raw_url)
    end
  end

  @doc """
  Given a [user|org]/project_name string, builds a GitHub URL. Prepends OAuth
  access credentials to the URL (if configured for the application.)

  ## Examples

    iex> OpenAperture.Builder.GitRepo.get_github_repo_url("test_user/test_project")
    "https://github.com/test_user/test_project.git"
  """
  @spec get_github_repo_url(String.t) :: String.t
  def get_github_repo_url(relative_repo) do
    get_github_url <> relative_repo <> ".git"
  end

  @doc """
  Retrieves the base GitHub URL, including an OAuth credential if one is set
  in the application's configuration.
  """
  @spec get_github_url :: String.t
  def get_github_url() do
    case Application.get_env(:github, :user_credentials) do
      nil -> "https://github.com/"
      creds -> "https://" <> creds <> "@github.com/"
    end
  end  
end