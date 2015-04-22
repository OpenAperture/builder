defmodule OpenAperture.Builder.DockerTests do
  use ExUnit.Case

  alias OpenAperture.Builder.Docker

  setup do
    {:ok, docker_repo} = Docker.init(%Docker{
      docker_repo_url: "myorg/myapp", 
      docker_host: "myhost", 
      output_dir: "/tmp/test",
      registry_url: Application.get_env(:openaperture_builder, :docker_registry_url),
      registry_username: Application.get_env(:openaperture_builder, :docker_registry_username),
      registry_email: Application.get_env(:openaperture_builder, :docker_registry_email),
      registry_password: Application.get_env(:openaperture_builder, :docker_registry_password), 
      authenticated: true
    })

    {:ok, docker_repo_unauth} = Docker.init(%Docker{
      docker_repo_url: "myorg/myapp", 
      docker_host: "myhost", 
      output_dir: "/tmp/test",
      registry_url: Application.get_env(:openaperture_builder, :docker_registry_url),
      registry_username: Application.get_env(:openaperture_builder, :docker_registry_username),
      registry_email: Application.get_env(:openaperture_builder, :docker_registry_email),
      registry_password: Application.get_env(:openaperture_builder, :docker_registry_password), 
      authenticated: false
    })

    {:ok, docker_repo: docker_repo, docker_repo_unauth: docker_repo_unauth}
  end

  #==================
  #init tests

  test "init - success" do
    {status, repo} = Docker.init(%Docker{
      docker_repo_url: "repo_url", 
      docker_host: "myhost", 
      output_dir: "/tmp/test",
      registry_url: Application.get_env(:openaperture_builder, :docker_registry_url),
      registry_username: Application.get_env(:openaperture_builder, :docker_registry_username),
      registry_email: Application.get_env(:openaperture_builder, :docker_registry_email),
      registry_password: Application.get_env(:openaperture_builder, :docker_registry_password)     
    })
    assert status == :ok
    assert repo.docker_repo_url == "repo_url"
    assert repo.docker_host == "myhost"
    assert repo.output_dir == "/tmp/test"
  end

  #==================
  #build tests

  test "build - success", %{docker_repo: docker_repo} do
    :meck.new(File, [:unstick])
    :meck.expect(File, :mkdir_p, fn _path -> true end)
    :meck.expect(File, :exists?, fn _path -> true end)
    :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
    :meck.expect(File, :rm_rf, fn _path -> true end)

    :meck.new(System, [:unstick])
    :meck.expect(System, :cmd, fn command, args, _opts ->
      assert command == "/bin/bash" || "cmd.exe"
      assert String.contains?(Enum.at(args, 1), "docker build --force-rm=true --no-cache=true --rm=true -t myorg/myapp .")
      {"Successfully built 87793b8f30d9", 0}
    end)
    :meck.expect(System, :user_home, fn -> "/" end)

    {result, image_id} = Docker.build(docker_repo)
    assert result == :ok
    assert image_id == "87793b8f30d9"
  after
    :meck.unload(File)
    :meck.unload(System)
  end

   test "build - failed", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker build --force-rm=true --no-cache=true --rm=true -t myorg/myapp .")
       {"bad news bears", 128}
     end)

     {result, reason} = Docker.build(docker_repo)
     assert result == :error
     assert reason != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end

#   #==================
#   #tag tests

   test "tag - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker tag --force=true 87793b8f30d9 customtag")
       {"Successfully built 87793b8f30d9", 0}
     end)

     {result, output} = Docker.tag(docker_repo, "87793b8f30d9", ["customtag"])
     assert result == :ok
     assert output != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end

   test "tag - failed", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker tag --force=true 87793b8f30d9 customtag")
       {"bad news bears", 128}
     end)

     {result, reason} = Docker.tag(docker_repo, "87793b8f30d9", ["customtag"])
     assert result == :error
     assert reason != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end  

#   #==================
#   #push tests

   test "push - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker push myorg/myapp")
       {"Successfully built 87793b8f30d9", 0}
     end)

     {result, output} = Docker.push(docker_repo)
     assert result == :ok
     assert output != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end

   test "push - failed", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker push myorg/myapp")
       {"bad news bears", 128}
     end)

     {result, reason} = Docker.push(docker_repo)
     assert result == :error
     assert reason != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end  

#   #==================
#   #pull tests

   test "pull - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker pull myorg/myapp")
       {"Successfully built 87793b8f30d9", 0}
     end)

     result = Docker.pull(docker_repo, "myorg/myapp")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)
   end

   test "pull - failed", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker pull myorg/myapp")
       {"bad news bears", 128}
     end)

     {result, reason} = Docker.pull(docker_repo, "myorg/myapp")
     assert result == :error
     assert reason != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end   

#   #==================
#   #login tests

   test "login - success with passthrough", %{docker_repo: docker_repo} do
     result = Docker.login(docker_repo)
     assert result == :ok
   end

   test "login - success", %{docker_repo_unauth: docker_repo_unauth} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       {"Successfully built 87793b8f30d9", 0}
     end)

     result = Docker.login(docker_repo_unauth)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)
   end

   test "login - failed", %{docker_repo_unauth: docker_repo_unauth} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       {"bad news bears", 128}
     end)

     {result, reason} = Docker.login(docker_repo_unauth)
     assert result == :error
     assert reason != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end  

#   #==========================
#   # get_containers

   test "get_containers - error", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
       {"bad news bears", 128}
     end) 

     assert Docker.get_containers(docker_repo) == []
   after
     :meck.unload(File)
     :meck.unload(System)    
   end

   test "get_containers - no containers", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
       {"", 0}
     end) 

     assert Docker.get_containers(docker_repo) == []
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "get_containers - containers", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "12345\n23456" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
       {"12345\n23456", 0}
     end) 

     result = Docker.get_containers(docker_repo)
     assert length(result) == 2
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

#   #=================
#   # find_containers_for_image tests

   test "find_containers_for_image - no containers", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "12345\n23456" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
       {"12345\n23456", 0}
     end) 

     containers = []
     result = Docker.find_containers_for_image(docker_repo, "123abc", containers)
     assert length(result) == 0
   after
     :meck.unload(File)
     :meck.unload(System)    
   end 

   test "find_containers_for_image - no containers that match", %{docker_repo: docker_repo} do
     file_contents = File.read!(System.cwd() <> "/test/builder/sample_docker_inspect.json")
     :meck.new(File, [:unstick, :passthrough])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> file_contents end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker inspect 098xyz")
       {file_contents, 0}
     end) 

     containers = ["098xyz"]
     result = Docker.find_containers_for_image(docker_repo, "123abc", containers)
     assert length(result) == 0
   after
     :meck.unload
   end   

   test "find_containers_for_image - no containers that match 2", %{docker_repo: docker_repo} do
     file_contents = File.read!(System.cwd() <> "/test/builder/sample_docker_inspect.json")
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> file_contents end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker inspect df605fc2be56a369efb170fb42ca938cc8f31c6b2dde8ee5a0c43eda63eae5fe")
       {file_contents, 0}
     end) 

     containers = ["df605fc2be56a369efb170fb42ca938cc8f31c6b2dde8ee5a0c43eda63eae5fe"]
     result = Docker.find_containers_for_image(docker_repo, "947e2652c7cd996e5f0b4fc4fd729cc1d9f2fb93e4241e23e7b509173bb3a872", containers)
     assert length(result) == 1
     assert List.first(result) == "df605fc2be56a369efb170fb42ca938cc8f31c6b2dde8ee5a0c43eda63eae5fe"
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

#   #==================
#   # cleanup_container tests

   test "cleanup_container - no containers", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "12345\n23456" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, args, _opts ->
       assert command == "/bin/bash"
       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
       {"12345\n23456", 0}
     end) 

     containers = []
     result = Docker.cleanup_container(docker_repo, containers)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end

   test "cleanup_container - fails", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"bad news bears", 128}
     end) 

     containers = ["123abc"]
     result = Docker.cleanup_container(docker_repo, containers)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "cleanup_container - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 0}
     end) 

     containers = ["123abc"]
     result = Docker.cleanup_container(docker_repo, containers)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end   

#   #==================
#   # cleanup_image tests

   test "cleanup_image - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 0}
     end) 

     containers = []
     result = Docker.cleanup_image(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "cleanup_image - failure", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "123abc" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"123abc", 128}
     end) 

     containers = []
     result = Docker.cleanup_image(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "cleanup_dangling_images - images", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "123abc" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"123abc", 0}
     end) 

     containers = []
     result = Docker.cleanup_dangling_images(docker_repo)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

#   #==================
#   # cleanup_dangling_images tests

   test "cleanup_image - success 2", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 0}
     end) 

     containers = []
     result = Docker.cleanup_image(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "cleanup_image - failure 2", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "123abc" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"123abc", 128}
     end) 

     containers = []
     result = Docker.cleanup_image(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

#   #==================
#   # cleanup_image_cache tests

   test "cleanup_image_cache - nil", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 0}
     end) 

     containers = []
     docker_repo = %{docker_repo | image_id: "123"}
     result = Docker.cleanup_image_cache(docker_repo, nil)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end 

   test "cleanup_image_cache - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 0}
     end) 

     containers = []
     result = Docker.cleanup_image_cache(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "cleanup_image_cache - failure", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "123abc" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"123abc", 128}
     end) 

     containers = []
     result = Docker.cleanup_image_cache(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end       

#   #==================
#   # cleanup_dangling_images tests

   test "get_exited_containers - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "123abc\n234a" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"123abc\n234a", 0}
     end) 

     containers = []
     result = Docker.get_exited_containers(docker_repo)
     assert length(result) == 2
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "get_exited_containers - failure", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 128}
     end) 

     containers = []
     result = Docker.get_exited_containers(docker_repo)
     assert length(result) == 0
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

#   #==================
#   # cleanup_exited_containers tests

   test "cleanup_exited_containers - success", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "123abc\n234a" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"123abc\n234a", 0}
     end) 

     containers = []
     result = Docker.cleanup_exited_containers(docker_repo)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  

   test "cleanup_exited_containers - failure", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash"
       {"", 128}
     end) 

     containers = []
     result = Docker.cleanup_exited_containers(docker_repo)
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end   
end