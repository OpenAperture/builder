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
      assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
       {"bad news bears", 128}
     end)

     {result, reason} = Docker.login(docker_repo_unauth)
     assert result == :error
     assert reason != nil
   after
     :meck.unload(File)
     :meck.unload(System)
   end  

   #==================
   # cleanup_image_cache tests

   test "cleanup_image_cache - nil", %{docker_repo: docker_repo} do
     :meck.new(File, [:unstick])
     :meck.expect(File, :mkdir_p, fn _path -> true end)
     :meck.expect(File, :exists?, fn _path -> true end)
     :meck.expect(File, :read!, fn _path -> "" end)
     :meck.expect(File, :rm_rf, fn _path -> true end)

     :meck.new(System, [:unstick, :passthrough])
     :meck.expect(System, :cmd, fn command, _args, _opts ->
       assert command == "/bin/bash" || command == "cmd.exe"
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
       assert command == "/bin/bash" || command == "cmd.exe"
       {"", 0}
     end) 

     containers = []
     result = Docker.cleanup_image_cache(docker_repo, "123abc")
     assert result == :ok
   after
     :meck.unload(File)
     :meck.unload(System)    
   end  
end