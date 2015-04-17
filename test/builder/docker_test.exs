defmodule OpenAperture.Builder.DockerTests do
  use ExUnit.Case

  alias OpenAperture.Builder.Docker

  #==================
  #init tests

  test "init - success" do
    {status, repo} = Docker.init(%Docker{docker_repo_url: "repo_url", docker_host: "myhost", output_dir: "/tmp/test"})
    assert status == :ok
    assert repo.docker_repo_url == "repo_url"
    assert repo.docker_host == "myhost"
    assert repo.output_dir == "/tmp/test"
  end

  #==================
  #build tests

  test "build - success" do
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

    docker = %Docker{docker_repo_url: "myorg/myapp", authenticated: true, output_dir: "/tmp/notused"}
    
    {result, image_id} = Docker.build(docker)
    assert result == :ok
    assert image_id == "87793b8f30d9"
  after
    :meck.unload(File)
    :meck.unload(System)
  end

#   test "build - failed" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker build --force-rm=true --no-cache=true --rm=true -t myorg/myapp .")
#       {"bad news bears", 128}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     {result, reason} = Docker.build(pid)
#     assert result == :error
#     assert reason != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end

#   #==================
#   #tag tests

#   test "tag - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker tag --force=true 87793b8f30d9 customtag")
#       {"Successfully built 87793b8f30d9", 0}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     {result, outpu} = Docker.tag(pid, "87793b8f30d9", ["customtag"])
#     assert result == :ok
#     assert outpu != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end

#   test "tag - failed" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker tag --force=true 87793b8f30d9 customtag")
#       {"bad news bears", 128}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     {result, reason} = Docker.tag(pid, "87793b8f30d9", ["customtag"])
#     assert result == :error
#     assert reason != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end  

#   #==================
#   #push tests

#   test "push - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker push myorg/myapp")
#       {"Successfully built 87793b8f30d9", 0}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     {result, outpu} = Docker.push(pid)
#     assert result == :ok
#     assert outpu != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end

#   test "push - failed" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker push myorg/myapp")
#       {"bad news bears", 128}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     {result, reason} = Docker.push(pid)
#     assert result == :error
#     assert reason != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end  

#   #==================
#   #pull tests

#   test "pull - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker pull myorg/myapp")
#       {"Successfully built 87793b8f30d9", 0}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     result = Docker.pull(pid, "myorg/myapp")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end

#   test "pull - failed" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker pull myorg/myapp")
#       {"bad news bears", 128}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     {result, reason} = Docker.pull(pid, "myorg/myapp")
#     assert result == :error
#     assert reason != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end   

#   #==================
#   #login tests

#   test "login - success with passthrough" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert is_pid pid

#     result = Docker.login(pid)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#   end

#   test "login - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "Successfully built 87793b8f30d9" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       #assert String.contains?(Enum.at(args, 1), "DOCKER_HOST=tcp://:2375 docker login -e=\"update_me\" -u=\"update_me\" -p=\"update_me\"")
#       {"Successfully built 87793b8f30d9", 0}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp"})
#     assert is_pid pid

#     result = Docker.login(pid)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end

#   test "login - failed" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       #assert String.contains?(Enum.at(args, 1), "DOCKER_HOST=tcp://:2375 docker login -e=\"update_me\" -u=\"update_me\" -p=\"update_me\"")
#       {"bad news bears", 128}
#     end)

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp"})
#     assert is_pid pid

#     {result, reason} = Docker.login(pid)
#     assert result == :error
#     assert reason != nil
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)
#   end  

#   #==========================
#   # get_containers

#   test "get_containers - error" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
#       {"bad news bears", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert Docker.get_containers(pid) == []
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end

#   test "get_containers - no containers" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
#       {"", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
#     assert Docker.get_containers(pid) == []
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "get_containers - containers" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "12345\n23456" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
#       {"12345\n23456", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     result = Docker.get_containers(pid)
#     assert length(result) == 2
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   #=================
#   # find_containers_for_image tests

#   test "find_containers_for_image - no containers" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "12345\n23456" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
#       {"12345\n23456", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.find_containers_for_image(pid, "123abc", containers)
#     assert length(result) == 0
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end 

#   test "find_containers_for_image - no containers that match" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     file_contents = File.read!(System.cwd() <> "/test/builder/sample_docker_inspect.json")
#     :meck.new(File, [:unstick, :passthrough])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> file_contents end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker inspect 098xyz")
#       {file_contents, 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = ["098xyz"]
#     result = Docker.find_containers_for_image(pid, "123abc", containers)
#     assert length(result) == 0
#   after
#     :meck.unload
#   end   

#   test "find_containers_for_image - no containers that match 2" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     file_contents = File.read!(System.cwd() <> "/test/builder/sample_docker_inspect.json")
#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> file_contents end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker inspect 098xyz")
#       {file_contents, 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = ["df605fc2be56a369efb170fb42ca938cc8f31c6b2dde8ee5a0c43eda63eae5fe"]
#     result = Docker.find_containers_for_image(pid, "947e2652c7cd996e5f0b4fc4fd729cc1d9f2fb93e4241e23e7b509173bb3a872", containers)
#     assert length(result) == 1
#     assert List.first(result) == "df605fc2be56a369efb170fb42ca938cc8f31c6b2dde8ee5a0c43eda63eae5fe"
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   #==================
#   # cleanup_container tests

#   test "cleanup_container - no containers" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "12345\n23456" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, args, _opts ->
#       assert command == "/bin/bash"
#       assert String.contains?(Enum.at(args, 1), "docker ps -aq")
#       {"12345\n23456", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_container(pid, containers)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end

#   test "cleanup_container - fails" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"bad news bears", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = ["123abc"]
#     result = Docker.cleanup_container(pid, containers)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "cleanup_container - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "bad news bears" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = ["123abc"]
#     result = Docker.cleanup_container(pid, containers)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end   

#   #==================
#   # cleanup_dangling_images tests
# #
# #  test "cleanup_dangling_images - no images" do
# #    :meck.new(DockerHosts, [:passthrough])
# #    :meck.expect(DockerHosts, :next_available, fn -> "" end)
# #
# #    :meck.new(File, [:unstick])
# #    :meck.expect(File, :mkdir_p, fn _path -> true end)
# #    :meck.expect(File, :exists?, fn _path -> true end)
# #    :meck.expect(File, :read!, fn _path -> "" end)
# #    :meck.expect(File, :rm_rf, fn _path -> true end)
# #
# #    :meck.new(System, [:unstick])
# #    :meck.expect(System, :cmd, fn command, args, _opts ->
# #      assert command == "/bin/bash"
# #      {"", 0}
# #    end) 
# #
# #    pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
# #
# #    containers = []
# #    result = Docker.cleanup_dangling_images(pid)
# #    assert result == :ok
# #  after
# #    :meck.unload(DockerHosts)
# #    :meck.unload(File)
# #    :meck.unload(System)    
# #  end  
# #
# #  test "cleanup_dangling_images - images" do
# #    :meck.new(DockerHosts, [:passthrough])
# #    :meck.expect(DockerHosts, :next_available, fn -> "" end)
# #
# #    :meck.new(File, [:unstick])
# #    :meck.expect(File, :mkdir_p, fn _path -> true end)
# #    :meck.expect(File, :exists?, fn _path -> true end)
# #    :meck.expect(File, :read!, fn _path -> "123abc" end)
# #    :meck.expect(File, :rm_rf, fn _path -> true end)
# #
# #    :meck.new(System, [:unstick])
# #    :meck.expect(System, :cmd, fn command, args, _opts ->
# #      assert command == "/bin/bash"
# #      {"123abc", 0}
# #    end) 
# #
# #    pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})
# #
# #    containers = []
# #    result = Docker.cleanup_dangling_images(pid)
# #    assert result == :ok
# #  after
# #    :meck.unload(DockerHosts)
# #    :meck.unload(File)
# #    :meck.unload(System)    
# #  end  

#   #==================
#   # cleanup_image tests

#   test "cleanup_image - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image(pid, "123abc")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "cleanup_image - failure" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "123abc" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"123abc", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image(pid, "123abc")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "cleanup_dangling_images - images" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "123abc" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"123abc", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_dangling_images(pid)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   #==================
#   # cleanup_dangling_images tests

#   test "cleanup_image - success 2" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image(pid, "123abc")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "cleanup_image - failure 2" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "123abc" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"123abc", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image(pid, "123abc")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  


#   #==================
#   # cleanup_image_cache tests

#   test "cleanup_image_cache - nil" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image_cache(pid, nil)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end 

#   test "cleanup_image_cache - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image_cache(pid, "123abc")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "cleanup_image_cache - failure" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "123abc" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"123abc", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_image_cache(pid, "123abc")
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end       

#   #==================
#   # cleanup_dangling_images tests

#   test "get_exited_containers - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "123abc\n234a" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"123abc\n234a", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.get_exited_containers(pid)
#     assert length(result) == 2
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "get_exited_containers - failure" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.get_exited_containers(pid)
#     assert length(result) == 0
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   #==================
#   # cleanup_exited_containers tests

#   test "cleanup_exited_containers - success" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "123abc\n234a" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"123abc\n234a", 0}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_exited_containers(pid)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end  

#   test "cleanup_exited_containers - failure" do
#     :meck.new(DockerHosts, [:passthrough])
#     :meck.expect(DockerHosts, :next_available, fn -> "" end)

#     :meck.new(File, [:unstick])
#     :meck.expect(File, :mkdir_p, fn _path -> true end)
#     :meck.expect(File, :exists?, fn _path -> true end)
#     :meck.expect(File, :read!, fn _path -> "" end)
#     :meck.expect(File, :rm_rf, fn _path -> true end)

#     :meck.new(System, [:unstick])
#     :meck.expect(System, :cmd, fn command, _args, _opts ->
#       assert command == "/bin/bash"
#       {"", 128}
#     end) 

#     pid = Docker.create!(%{docker_repo_url: "myorg/myapp", authenticated: true})

#     containers = []
#     result = Docker.cleanup_exited_containers(pid)
#     assert result == :ok
#   after
#     :meck.unload(DockerHosts)
#     :meck.unload(File)
#     :meck.unload(System)    
#   end   
end