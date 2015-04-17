defmodule OpenAperture.Builder.Workflow do
@moduledoc """



Stub until this is implemented fully.
"""

	def publish_success_notification(workflow, notification) do
		IO.puts "Workflow Success Notification: #{workflow}: #{notification}"
	end

	def step_failed(workflow, notification, reason) do
		IO.puts "Workflow Step Failure: #{workflow}: #{notification} #{reason}"
	end

	def next_step(workflow, vals) do
		IO.puts "Workflow Next Step: #{workflow}: #{inspect vals}"
	end

end