defmodule OpenAperture.Builder.Milestones.ConfigTest do
  use ExUnit.Case

  alias OpenAperture.Builder.Milestones.Config
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
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> true end)    
    :meck.expect(DeploymentRepo, :checkin_pending_changes, fn _, _ -> :ok end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    {:ok, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
  	:meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
  end

  test "execute - success, no files" do
    request = %BuilderRequest{
      workflow: %Workflow{},
      orchestrator_request: %Request{},
      deployment_repo: %DeploymentRepo{
        etcd_token: "123abc"
      }
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> false end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> false end)    

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    {:ok, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
    :meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
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
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :checkin_pending_changes, fn _, _ -> {:error, "bad news bears"} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    {:error, _, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
  	:meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
  end  
end
