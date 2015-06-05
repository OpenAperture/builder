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
    
    response = %{body: JSON.decode!("{\"workflow_error\":false,\"workflow_completed\":false}")}

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :create_docker_image, fn _, _ -> 
                                                          :timer.sleep(1_000)
                                                          {:ok, ["Status", "Status"]} end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :publish_success_notification, fn _, _ -> request end)

    :meck.new(OpenAperture.ManagerApi.Workflow, [:passthrough])
    :meck.expect(OpenAperture.ManagerApi.Workflow, :get_workflow, fn _ -> response end)    


    assert Build.execute(request) == {:ok, request}
  after
  	:meck.unload(DeploymentRepo)
    :meck.unload(BuilderRequest)
    :meck.unload(OpenAperture.ManagerApi.Workflow)
  end

  test "execute - failure" do
    request = %BuilderRequest{
      workflow: %Workflow{},
      orchestrator_request: %Request{},
      deployment_repo: %DeploymentRepo{
        etcd_token: "123abc"
      }
    }
    response = %{body: JSON.decode!("{\"workflow_error\":false,\"workflow_completed\":false}")}

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :create_docker_image, fn _, _ -> {:error, "bad news bears", ["Status", "Status"]} end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :publish_success_notification, fn _, _ -> request end)

    :meck.new(OpenAperture.ManagerApi.Workflow, [:passthrough])
    :meck.expect(OpenAperture.ManagerApi.Workflow, :get_workflow, fn _ -> response end)

    {:error, _, returned_request} = Build.execute(request)
    assert returned_request == request
  after
    :meck.unload(DeploymentRepo)
    :meck.unload(BuilderRequest)
    :meck.unload(OpenAperture.ManagerApi.Workflow)
  end  

  test "execute - workflow killed" do
    request = %BuilderRequest{
      workflow: %Workflow{},
      orchestrator_request: %Request{},
      deployment_repo: %DeploymentRepo{
        etcd_token: "123abc"
      }
    }

    response = %{body: JSON.decode!("{\"workflow_error\":true,\"workflow_completed\":true}")}

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :create_docker_image, fn _, _ -> :timer.sleep(100_000) end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :publish_success_notification, fn _, _ -> request end)    

    :meck.new(OpenAperture.ManagerApi.Workflow, [:passthrough])
    :meck.expect(OpenAperture.ManagerApi.Workflow, :get_workflow, fn _ -> response end)    

    {:error, error_string, returned_request} = Build.execute(request)
    assert error_string == "Workflow is in error state"
    assert returned_request == request
  after
    :meck.unload(DeploymentRepo)
    :meck.unload(BuilderRequest)
    :meck.unload(OpenAperture.ManagerApi.Workflow)
  end  
end
