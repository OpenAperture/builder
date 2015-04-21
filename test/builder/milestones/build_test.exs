defmodule OpenAperture.Builder.Milestones.BuildTest do
  use ExUnit.Case

  alias OpenAperture.Builder.Milestones.Build
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Request, as: BuilderRequest

	alias OpenAperture.WorkflowOrchestratorApi.Request
	alias OpenAperture.WorkflowOrchestratorApi.Workflow

  test "execute - success" do
    request = %BuilderRequest{
    	workflow: %Workflow{},
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :create_docker_image, fn _, _ -> :ok end)

    assert Build.execute(request) == {:ok, request}
  after
  	:meck.unload(DeploymentRepo)
  end

  test "execute - failure" do
    request = %BuilderRequest{
    	workflow: %Workflow{},
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :create_docker_image, fn _, _ -> {:error, "bad news bears"} end)

    {:error, _, returned_request} = Build.execute(request)
    assert returned_request == request
  after
  	:meck.unload(DeploymentRepo)
  end  
end
