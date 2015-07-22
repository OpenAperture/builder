require Logger

defmodule OpenAperture.Builder.Docker.AsyncCmd do

  def execute(cmd, cmd_opts, callbacks) do
    Task.async(fn -> 
        path = :os.find_executable('goon')
        if !Porcelain.Driver.Goon.check_goon_version(path) do
          {:error, "Goon driver not found, unable to kill process if needed!", nil, nil}
        else
          if callbacks[:on_startup] != nil, do: callbacks[:on_startup].()

          try do
            shell_process = Porcelain.spawn_shell(cmd, cmd_opts)
            monitor_shell(shell_process, callbacks)
          after
            if callbacks[:on_completed] != nil, do: callbacks[:on_completed].()
          end          
        end   
    end)    
  end

  def monitor_shell(shell_process, callbacks) do
    :timer.sleep(1_000)

    cond do
      #process has finished normally
      !Porcelain.Process.alive?(shell_process) -> {:ok, shell_process.out, shell_process.err}

      #process is in-progress, but no interrupt check is needed
      callbacks[:on_interrupt] == nil -> monitor_shell(shell_process, callbacks)

      #process is in-progress and interrupt check was ok
      callbacks[:on_interrupt].() -> monitor_shell(shell_process, callbacks)

      #process is in-progress and interrupt check failed
      true -> 
        Porcelain.Process.stop(shell_process)
        {:error, "The process was interrupted!", shell_process.out, shell_process.err}        
    end
  end
end