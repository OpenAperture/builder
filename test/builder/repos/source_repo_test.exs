defmodule OpenAperture.Builder.SourceRepo.Test do
  use ExUnit.Case

  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Builder.Git
  alias OpenAperture.Builder.GitRepo, as: GitRepo

	setup do
 	  source_repo = %SourceRepo{ 
 	    github_source_repo: %GitRepo{}, 
 	    output_dir: "/tmp"
	  }

	  {:ok, source_repo: source_repo}
	end

	#=============================
	# create! tests

  test "create!" do
    :meck.new(Git, [:passthrough, :non_strict])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    repo = SourceRepo.create!("123", "myorg/myrepo", "master")
    assert repo != nil
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)    
  end  

	#=============================
	# download! tests

  test "download! - success", %{source_repo: source_repo} do
    :meck.new(Git, [:passthrough, :non_strict])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    repo = SourceRepo.download!(source_repo, "myorg/myrepo", "master")
    assert repo != nil
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)    
  end    

  test "download! - clone fails", %{source_repo: source_repo} do
    :meck.new(Git, [:passthrough, :non_strict])
    :meck.expect(Git, :clone, fn _ -> {:error, "bad news bears"} end)
    :meck.expect(Git, :checkout, fn _ -> :ok end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    assert_raise RuntimeError,
                 "bad news bears",
                 fn -> SourceRepo.download!(source_repo, "myorg/myrepo", "master") end    
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)
  end

  test "download! - checkout fails", %{source_repo: source_repo} do
    :meck.new(Git, [:passthrough, :non_strict])
    :meck.expect(Git, :clone, fn _ -> :ok end)
    :meck.expect(Git, :checkout, fn _ -> {:error, "bad news bears"} end)

    :meck.new(GitRepo, [:passthrough])
    :meck.expect(GitRepo, :resolve_github_repo_url, fn _ -> "" end)

    assert_raise RuntimeError,
                 "bad news bears",
                 fn -> SourceRepo.download!(source_repo, "myorg/myrepo", "master") end    
  after
    :meck.unload(GitRepo)
    :meck.unload(Git)
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