defmodule OpenAperture.Builder.SourceRepo.Test do
  use ExUnit.Case

  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Builder.Github
  alias OpenAperture.Builder.GitHub.Repo, as: GithubRepo

	setup do
 	  source_repo = %SourceRepo{ 
 	    github_source_repo: %GithubRepo{}, 
 	    output_dir: "/tmp"
	  }

	  {:ok, source_repo: source_repo}
	end

	#=============================
	# create! tests

  test "create!" do
    :meck.new(Github, [:passthrough, :non_strict])
    :meck.expect(Github, :clone, fn _ -> :ok end)
    :meck.expect(Github, :checkout, fn _ -> :ok end)

    :meck.new(GithubRepo, [:passthrough])
    :meck.expect(GithubRepo, :resolve_github_repo_url, fn _ -> "" end)

    repo = SourceRepo.create!("123", "myorg/myrepo", "master")
    assert repo != nil
  after
    :meck.unload(GithubRepo)
    :meck.unload(Github)    
  end  

	#=============================
	# download! tests

  test "download! - success", %{source_repo: source_repo} do
    :meck.new(Github, [:passthrough, :non_strict])
    :meck.expect(Github, :clone, fn _ -> :ok end)
    :meck.expect(Github, :checkout, fn _ -> :ok end)

    :meck.new(GithubRepo, [:passthrough])
    :meck.expect(GithubRepo, :resolve_github_repo_url, fn _ -> "" end)

    repo = SourceRepo.download!(source_repo, "myorg/myrepo", "master")
    assert repo != nil
  after
    :meck.unload(GithubRepo)
    :meck.unload(Github)    
  end    

  test "download! - clone fails", %{source_repo: source_repo} do
    :meck.new(Github, [:passthrough, :non_strict])
    :meck.expect(Github, :clone, fn _ -> {:error, "bad news bears"} end)
    :meck.expect(Github, :checkout, fn _ -> :ok end)

    :meck.new(GithubRepo, [:passthrough])
    :meck.expect(GithubRepo, :resolve_github_repo_url, fn _ -> "" end)

    assert_raise RuntimeError,
                 "bad news bears",
                 fn -> SourceRepo.download!(source_repo, "myorg/myrepo", "master") end    
  after
    :meck.unload(GithubRepo)
    :meck.unload(Github)
  end

  test "download! - checkout fails", %{source_repo: source_repo} do
    :meck.new(Github, [:passthrough, :non_strict])
    :meck.expect(Github, :clone, fn _ -> :ok end)
    :meck.expect(Github, :checkout, fn _ -> {:error, "bad news bears"} end)

    :meck.new(GithubRepo, [:passthrough])
    :meck.expect(GithubRepo, :resolve_github_repo_url, fn _ -> "" end)

    assert_raise RuntimeError,
                 "bad news bears",
                 fn -> SourceRepo.download!(source_repo, "myorg/myrepo", "master") end    
  after
    :meck.unload(GithubRepo)
    :meck.unload(Github)
  end  

  #========================
  # cleanup tests

  test "cleanup", %{source_repo: source_repo} do

    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :rm_rf, fn _ -> :ok end)
 
    SourceRepo.cleanup(source_repo)
  after
    :meck.unload(File)
  end  

  #========================
  # get_openaperture_info tests

  test "get_openaperture_info - success", %{source_repo: source_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> Poison.encode!(%{
    }) end)
 
    assert %{} == SourceRepo.get_openaperture_info(source_repo)
  after
    :meck.unload(File)
  end 

  test "get_openaperture_info - bad json", %{source_repo: source_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> true end)
    :meck.expect(File, :read!, fn _ -> "blah blah blah" end)
 
    assert nil == SourceRepo.get_openaperture_info(source_repo)
  after
    :meck.unload(File)
  end

  test "get_openaperture_info - no file", %{source_repo: source_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :exists?, fn _ -> false end)
 
    assert nil == SourceRepo.get_openaperture_info(source_repo)
  after
    :meck.unload(File)
  end  
end