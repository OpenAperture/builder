defmodule OpenAperture.Builder.Util do

  def execute_command(cmd, dir \\ nil) do
    opts = case dir do
            nil -> [{:stderr_to_stdout, true}]
            _   ->
              File.mkdir_p(dir)
              [{:cd, "#{dir}"}, {:stderr_to_stdout, true}]
          end
  	case String.starts_with?(System.user_home, "/") do
  		true -> System.cmd("/bin/bash", ["-c", cmd], opts)
  		false -> System.cmd("cmd.exe", ["/c", cmd], opts)
  	end
  end
end