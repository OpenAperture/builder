require Logger

defmodule OpenAperture.Builder.Docker.AsyncCmd do

  @spec execute(binary, Keyword.t, Keyword.t) :: {:ok, String.t, String.t} | {:error, String.t, String.t, String.t}
  def execute(cmd, cmd_opts, callbacks) do
    if callbacks[:on_startup] != nil, do: callbacks[:on_startup].()

    try do
      shell_process = Porcelain.spawn_shell(cmd, cmd_opts)
      monitor_shell(shell_process, callbacks)
    after
      if callbacks[:on_completed] != nil, do: callbacks[:on_completed].()
    end
  end

  @spec monitor_shell(Porcelain.Process.t, Keyword.t) :: {:ok, String.t, String.t} | {:error, String.t, String.t, String.t}
  def monitor_shell(shell_process, callbacks) do
    :timer.sleep(1_000)

    cond do
      #process has finished normally
      !Porcelain.Process.alive?(shell_process) -> 
        case Porcelain.Process.await(shell_process) do
          {:error, reason} ->
            {:error, "Porcelain returned error: #{reason}", shell_process.out, shell_process.err}
          {:ok, result}    ->
            case result.status do
              0 -> {:ok, shell_process.out, shell_process.err}
              _ -> {:error, "Nonzero exit from process", shell_process.out, shell_process.err}
            end
        end
      #process is in-progress, but no interrupt check is needed
      callbacks[:on_interrupt] == nil ->
        monitor_shell(shell_process, callbacks)

      #process is in-progress and interrupt check was ok
      callbacks[:on_interrupt].() ->
        monitor_shell(shell_process, callbacks)

      #process is in-progress and interrupt check failed
      true -> 
        Porcelain.Process.stop(shell_process)
        {:error, "The process was interrupted!", shell_process.out, shell_process.err}        
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