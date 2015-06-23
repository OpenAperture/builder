defmodule OpenAperture.Builder.Milestones.VerifyBuildExistsTest do
  use ExUnit.Case

  alias OpenAperture.Builder.Milestones.VerifyBuildExists
  alias OpenAperture.Builder.Docker
  alias OpenAperture.Builder.Request, as: BuilderRequest
  alias OpenAperture.WorkflowOrchestratorApi.Request, as: OrchestratorRequest
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.WorkflowOrchestratorApi.Workflow

  test "execute - success" do
  	request = %BuilderRequest{workflow: %Workflow{}, orchestrator_request: %OrchestratorRequest{workflow: %Workflow{}}, deployment_repo: %DeploymentRepo{docker_repo: %Docker{}}}
  	:meck.new(Docker, [:passthrough])
  	:meck.expect(Docker, :cleanup_image, fn _,_ -> :ok end)
  	:meck.expect(Docker, :pull, fn _,_ -> :ok end)
    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :add_event_to_log, fn req, msg -> req end)
  	{status, _} = VerifyBuildExists.execute(request)
  	assert status == :ok
  after
  	:meck.unload(Docker)
  	:meck.unload(Workflow)
  end

  test "execute - failure" do
  	request = %BuilderRequest{workflow: %Workflow{}, orchestrator_request: %OrchestratorRequest{workflow: %Workflow{}}, deployment_repo: %DeploymentRepo{docker_repo: %Docker{}}}
  	:meck.new(Docker, [:passthrough])
  	:meck.expect(Docker, :cleanup_image, fn _,_ -> :ok end)
  	:meck.expect(Docker, :pull, fn _,_ -> {:error, "bad news bears"} end)
    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :add_event_to_log, fn req, msg -> req end)
  	{status, msg, _} = VerifyBuildExists.execute(request)
  	assert status == :error
  	assert msg == "Docker image (:) not found in docker repo: bad news bears"
  after
  	:meck.unload(Docker)
  	:meck.unload(Workflow)
  end
end