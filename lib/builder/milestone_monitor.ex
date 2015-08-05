defmodule OpenAperture.Builder.MilestoneMonitor do
  use Timex
  alias OpenAperture.WorkflowOrchestratorApi.Workflow, as: OrchestratorWorkflow

  @spec monitor(BuilderRequest.t, Atom, fun) :: BuilderRequest.t
  def monitor(builder_request, current_milestone, fun) do
    {:ok, completed_agent_pid} = Agent.start_link(fn -> nil end)
    Task.async(fn ->
        ret = fun.()
        Agent.update(completed_agent_pid, fn _ -> ret end)
      end)
    monitor_internal(completed_agent_pid, builder_request, current_milestone, Date.now())
  end

  defp monitor_internal(completed_agent_pid, builder_request, current_milestone, last_alert) do
    case Agent.get(completed_agent_pid, &(&1)) do
      nil ->
        :timer.sleep(Application.get_env(:openaperture_builder, :milestone_monitor_sleep_seconds, 10) * 1_000)
        time_since_last_build_duration_warning = if builder_request.last_total_duration_warning == nil do
            builder_request.workflow.workflow_start_time
          else
            builder_request.last_total_duration_warning
          end
          |> Date.diff(Date.now(), :mins)
        workflow_duration = Date.diff(builder_request.workflow.workflow_start_time, Date.now(), :mins)
        if time_since_last_build_duration_warning >= 25 do
          orchestrator_request = OrchestratorWorkflow.publish_failure_notification(builder_request.orchestrator_request, "Warning: Builder request running for #{workflow_duration} minutes (current milestone: #{current_milestone})")
          builder_request = %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow, last_total_duration_warning: Date.now()}
        end
        time_since_last_step_duration_warning = Date.diff(last_alert, Date.now(), :mins)
        if time_since_last_step_duration_warning >= 15 do
          orchestrator_request = OrchestratorWorkflow.publish_failure_notification(builder_request.orchestrator_request, "Warning: Builder request #{current_milestone} milestone running for #{ time_since_last_step_duration_warning} minutes. Total workflow duration: #{workflow_duration} minutes.")
          builder_request = %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow}
          last_alert = Date.now()
        end  

        monitor_internal(completed_agent_pid, builder_request, current_milestone, last_alert)
      ret ->
        ret
    end
  end
end