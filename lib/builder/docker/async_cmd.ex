require Logger

defmodule OpenAperture.Builder.Docker.AsyncCmd do

  @spec execute(binary, Keyword.t, Keyword.t) :: :ok | {:error, String.t}
  def execute(cmd, cmd_opts, callbacks) do
    if callbacks[:on_startup] != nil, do: callbacks[:on_startup].()

    try do
      shell_process = Porcelain.spawn_shell(cmd, cmd_opts)
      {:ok, agent_pid} = Agent.start_link(fn -> shell_process end)
      task = Task.async(fn ->
          proc = Agent.get_and_update(agent_pid, fn p -> {p, nil} end)
          ret = Porcelain.Process.await(proc)
          Agent.update(agent_pid, fn _ -> :completed end)
          ret
        end)
      monitor_task(task, agent_pid, shell_process, callbacks)
    after
      if callbacks[:on_completed] != nil, do: callbacks[:on_completed].()
    end
  end

  @spec monitor_task(Task.t, pid, Porcelain.Process.t, Keyword.t) :: :ok | {:error, String.t}
  def monitor_task(task, agent_pid, shell_process, callbacks) do
    :timer.sleep(1_000)

    cond do
      #process has finished normally
      Agent.get(agent_pid, &(&1)) == :completed ->
        Logger.debug("Async Process ended. Awaiting...")
        case Task.await(task) do
          {:error, reason} ->
            Logger.debug("Async Process returned error.")
            {:error, "Porcelain returned error: #{reason}", shell_process.out, shell_process.err}
          {:ok, result}    ->
            Logger.debug("Async Process returned ok. Result: #{inspect result}")
            case result.status do
              0 -> :ok
              _ -> {:error, "Nonzero exit from process: #{inspect result.status}"}
            end
        end
      #process is in-progress, but no interrupt check is needed
      callbacks[:on_interrupt] == nil ->
        Logger.debug("Async Process no interrupt defined, continuing.")
        monitor_task(task, agent_pid, shell_process, callbacks)

      #process is in-progress and interrupt check was ok
      callbacks[:on_interrupt].() ->
        Logger.debug("Async Process interrupt passed")
        monitor_task(task, agent_pid, shell_process, callbacks)

      #process is in-progress and interrupt check failed
      true -> 
        Logger.debug("Async Process interrupted")
        Porcelain.Process.stop(shell_process)
        {:error, "The process was interrupted!"}        
    end
  end

  @spec check_goon :: nil
  def check_goon do
    path = __MODULE__.find_goon_executable
    cond do
      path == false ->
        raise "Goon driver not found, unable to kill process if needed!"
      !Porcelain.Driver.Goon.check_goon_version(path) ->
        raise "Goon driver not correct version, unable to kill process if needed!"
      true -> nil
    end          
  end

  @doc """
  Separated so it can be mecked (:os doesn't play nice with meck)
  """
  @spec find_goon_executable :: boolean | String.t
  def find_goon_executable do
    :os.find_executable('goon')
  end
end