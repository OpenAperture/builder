defmodule OpenAperture.Builder.GitRepo.Test do
  use ExUnit.Case
  doctest OpenAperture.Builder.GitRepo

  alias OpenAperture.Builder.GitRepo
  import OpenAperture.Builder.GitRepo

  test "get_project_name from repo" do
    repo = %GitRepo{
      local_repo_path: "/tmp/some_random_path",
      remote_url: "https://github.com/test_org/test_project",
      branch: "master"
    }

    assert get_project_name(repo) == "test_project"
  end

  test "get_project_name from https url" do
    assert get_project_name("https://github.com/some_user/test_project") == "test_project"
  end

  test "get_project_name from ssh url" do
    assert get_project_name("git@github.com:some_user/test_project.git") == "test_project.git"
  end

  test "get_github_repo_url" do
    assert get_github_repo_url("test_user/test_project") == "https://github.com/test_user/test_project.git"
  end
end