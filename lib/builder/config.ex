require Logger
require Timex.Date

defmodule OpenAperture.Builder.Config do
  use GenServer
  use Timex

  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Workflow

  @spec start_link :: {:ok, pid} | {:error, String.t}
	def start_link do
		GenServer.start_link(__MODULE__, nil)
	end

  @spec config(term) :: {:ok, DeploymentRepo} | {:error, String.t()}
  def config(options) do
    GenServer.call(__MODULE__, {:config, options})
  end

  @spec handle_call(term, term, term) :: {:ok, DeploymentRepo} | {:error, String.t()}
  def handle_call({:config, options}, _from, state) do
    {:reply, config_impl(options), state}
  end

  @spec config_impl(Map) :: {:ok, DeploymentRepo} | {:error, String.t}
  defp config_impl(options) do
    cloudos_workflow   = "workflow"

    Workflow.publish_success_notification(cloudos_workflow, "Requesting configuration of repository #{options[:deployment_repo]}...")

    deploy_repo = %DeploymentRepo{deployment_repo: options[:deployment_repo],
                                  deployment_repo_git_ref: options[:deployment_repo_git_ref] || "master",
                                  source_repo: options[:source_repo],
                                  source_repo_git_ref: options[:source_repo_git_ref]
                                }
    case DeploymentRepo.init(deploy_repo) do
      {:ok, deploy_repo} ->
        dockerfile_commit_required = DeploymentRepo.resolve_dockerfile_template(deploy_repo, [commit_hash: deploy_repo.source_repo_git_ref, timestamp: get_timestamp])
        units_commit_required = DeploymentRepo.resolve_service_file_templates(deploy_repo, [commit_hash: deploy_repo.source_repo_git_ref, timestamp: get_timestamp, dst_port: "<%= dst_port %>"])

        if (dockerfile_commit_required || units_commit_required) do
          commit_result = case DeploymentRepo.checkin_pending_changes(deploy_repo, "Deployment for commit #{deploy_repo.source_repo_git_ref}") do
            :ok -> :ok
            {:error, reason} ->
              Workflow.step_failed(cloudos_workflow, "Failed to commit changes.  Please see the event log for more details...", reason)
              :error
          end
        else
          Logger.debug ("There are no files to commit (templating required no file changes)")
          commit_result = :ok
        end

        case commit_result do
          :ok ->
              Workflow.next_step(cloudos_workflow, "next step")
          {:error, reason}   ->
              DeploymentRepo.cleanup(deploy_repo)
              {:error, reason}
        end
      {:error, reason} ->
        DeploymentRepo.cleanup(deploy_repo)
        Workflow.step_failed(cloudos_workflow, "Failed to download the deployment repository.  Please see the event log for more details...", reason)
    end
  end

  @spec get_timestamp() :: String.t()
  defp get_timestamp() do
    date = Date.now()
    DateFormat.format!(date, "{RFC1123}")
  end

end