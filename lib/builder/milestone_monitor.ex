require Logger

defmodule OpenAperture.Builder.MilestoneMonitor do
  use Timex
  alias OpenAperture.WorkflowOrchestratorApi.Workflow, as: OrchestratorWorkflow

  @logprefix "[MilestoneMonitor]"

  @max_build_duration_warn_time = 25
  @max_step_duration_warn_time  = 15

  @spec monitor(BuilderRequest.t, Atom, fun) :: BuilderRequest.t
  def monitor(builder_request, current_milestone, fun) do
    Logger.debug("#{@logprefix} Starting to monitor milestone #{inspect current_milestone} for workflow #{builder_request.workflow.id}")
    
    {:ok, completed_agent_pid} = Agent.start_link(fn -> nil end)
    Task.async(fn ->
        Logger.debug("#{@logprefix}[#{builder_request.workflow.id}][#{inspect current_milestone}] Starting milestone")
        ret = fun.()
        Logger.debug("#{@logprefix}[#{builder_request.workflow.id}][#{inspect current_milestone}] Completed milestone")
        Agent.update(completed_agent_pid, fn _ -> ret end)
    end)
    monitor_internal(completed_agent_pid, builder_request, current_milestone, Time.now())
  end

  defp monitor_internal(completed_agent_pid, builder_request, current_milestone, last_alert) do
    case Agent.get(completed_agent_pid, &(&1)) do
      nil ->
        Logger.debug("#{@logprefix}[#{builder_request.workflow.id}][#{inspect current_milestone}] Milestone not completed, sleeping...")
        :timer.sleep(Application.get_env(:openaperture_builder, :milestone_monitor_sleep_seconds, 10) * 1_000)
        time_since_last_build_duration_warning = if builder_request.last_total_duration_warning == nil do
            builder_request.workflow.workflow_start_time
          else
            builder_request.last_total_duration_warning
          end
          |> Time.diff(Time.now(), :mins)
        workflow_duration = Time.diff(builder_request.workflow.workflow_start_time, Time.now(), :mins)
        if too_long?(time_since_last_build_duration_warning) do
          Logger.debug("#{@logprefix}[#{builder_request.workflow.id}][#{inspect current_milestone}] Milestone has been processing for #{time_since_last_build_duration_warning} minutes")
          orchestrator_request = OrchestratorWorkflow.publish_failure_notification(builder_request.orchestrator_request, "Warning: Builder request running for #{workflow_duration} minutes (current milestone: #{current_milestone})")
          builder_request = %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow, last_total_duration_warning: Time.now()}
        end
        time_since_last_step_duration_warning = Time.diff(last_alert, Time.now(), :mins)
        if too_long?(time_since_last_step_duration_warning) do
          Logger.debug("#{@logprefix}[#{builder_request.workflow.id}][#{inspect current_milestone}] Milestone has been processing for #{time_since_last_build_duration_warning} minutes")
          orchestrator_request = OrchestratorWorkflow.publish_failure_notification(builder_request.orchestrator_request, "Warning: Builder request #{current_milestone} milestone running for #{ time_since_last_step_duration_warning} minutes. Total workflow duration: #{workflow_duration} minutes.")
          builder_request = %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow}
          last_alert = Time.now()
        end  

        monitor_internal(completed_agent_pid, builder_request, current_milestone, last_alert)
      ret ->
        Logger.debug("#{@logprefix} Finished monitoring milestone #{inspect current_milestone} for workflow #{builder_request.workflow.id}")
        ret
    end
  end

  defp too_long?(:build, time), do: time >= @max_build_duration_warn_time
  defp too_long?(:step,  time), do: time >= @max_step_duration_warn_time
end
