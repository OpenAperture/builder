defmodule OpenAperture.Builder.Docker.AsyncCmdTest do
  use ExUnit.Case

  alias OpenAperture.Builder.Docker.AsyncCmd

  test "goon - not found" do
    :meck.new(AsyncCmd, [:passthrough])
    :meck.expect(AsyncCmd, :find_goon_executable, fn -> false end)

    assert_raise RuntimeError, "Goon driver not found, unable to kill process if needed!", &AsyncCmd.check_goon/0
  after
    :meck.unload
  end

  test "goon - bad version" do
    :meck.new(AsyncCmd, [:passthrough])
    :meck.expect(AsyncCmd, :find_goon_executable, fn -> true end)
    :meck.new(Porcelain.Driver.Goon)
    :meck.expect(Porcelain.Driver.Goon, :check_goon_version, fn _ -> false end)
    
    assert_raise RuntimeError, "Goon driver not correct version, unable to kill process if needed!", &AsyncCmd.check_goon/0
  after
    :meck.unload
  end

  test "goon - good version" do
    :meck.new(AsyncCmd, [:passthrough])
    :meck.expect(AsyncCmd, :find_goon_executable, fn -> true end)
    :meck.new(Porcelain.Driver.Goon)
    :meck.expect(Porcelain.Driver.Goon, :check_goon_version, fn _ -> true end)
    
    assert AsyncCmd.check_goon == nil
  after
    :meck.unload
  end

  test "execute - completed immediately" do
    :meck.new(Porcelain)
    :meck.expect(Porcelain, :spawn_shell, fn _, _ -> %{out: "shellout", err: "shellerr"} end)
    :meck.new(Porcelain.Process)
    :meck.expect(Porcelain.Process, :alive?, fn _ -> false end)
    :meck.expect(Porcelain.Process, :await, fn _ -> {:ok, %{status: 0}} end)

    {:ok, pid} = Agent.start_link(&HashSet.new/0)
    on_startup = fn -> Agent.update(pid, &HashSet.put(&1, :on_startup)) end
    on_completed = fn -> Agent.update(pid, &HashSet.put(&1, :on_completed)) end
    on_interrupt = fn -> true end
    callbacks = %{on_startup: on_startup, on_completed: on_completed, on_interrupt: on_interrupt}

    :ok = AsyncCmd.execute("MyCommand", %{}, callbacks)
    state = Agent.get(pid,&(&1))
    assert HashSet.member?(state, :on_startup)
    assert HashSet.member?(state, :on_completed)
  after
    :meck.unload
  end

  test "execute - failure" do
    :meck.new(Porcelain)
    :meck.expect(Porcelain, :spawn_shell, fn _, _ -> %{out: "shellout", err: "shellerr"} end)
    :meck.new(Porcelain.Process)
    :meck.expect(Porcelain.Process, :alive?, fn _ -> false end)
    :meck.expect(Porcelain.Process, :await, fn _ -> {:ok, %{status: 128}} end)

    {:ok, pid} = Agent.start_link(&HashSet.new/0)
    on_startup = fn -> Agent.update(pid, &HashSet.put(&1, :on_startup)) end
    on_completed = fn -> Agent.update(pid, &HashSet.put(&1, :on_completed)) end
    on_interrupt = fn -> true end
    callbacks = %{on_startup: on_startup, on_completed: on_completed, on_interrupt: on_interrupt}

    {:error, "Nonzero exit from process: 128"} = AsyncCmd.execute("MyCommand", %{}, callbacks)
    state = Agent.get(pid,&(&1))
    assert HashSet.member?(state, :on_startup)
    assert HashSet.member?(state, :on_completed)
  after
    :meck.unload
  end

  test "execute - interrupted" do
    :meck.new(Porcelain)
    :meck.expect(Porcelain, :spawn_shell, fn _, _ -> %{out: "shellout", err: "shellerr"} end)
    :meck.new(Porcelain.Process)
    :meck.expect(Porcelain.Process, :alive?, fn _ -> true end)
    :meck.expect(Porcelain.Process, :await, fn _ -> :timer.sleep(5000); {:ok, %{status: 0}} end)
    :meck.expect(Porcelain.Process, :stop, fn _ -> true end)

    {:ok, pid} = Agent.start_link(&HashSet.new/0)
    on_startup = fn -> Agent.update(pid, &HashSet.put(&1, :on_startup)) end
    on_completed = fn -> Agent.update(pid, &HashSet.put(&1, :on_completed)) end
    on_interrupt = fn -> false end
    callbacks = %{on_startup: on_startup, on_completed: on_completed, on_interrupt: on_interrupt}

    {:error, "The process was interrupted!"} = AsyncCmd.execute("MyCommand", %{}, callbacks)
    state = Agent.get(pid,&(&1))
    assert HashSet.member?(state, :on_startup)
    assert HashSet.member?(state, :on_completed)
  after
    :meck.unload
  end
end