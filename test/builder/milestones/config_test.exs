defmodule OpenAperture.Builder.Milestones.ConfigTest do
  use ExUnit.Case

  alias OpenAperture.Builder.Milestones.Config
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.SourceRepo
  alias OpenAperture.Builder.Request, as: BuilderRequest

	alias OpenAperture.WorkflowOrchestratorApi.Request
	alias OpenAperture.WorkflowOrchestratorApi.Workflow

  test "execute - success" do
    request = %BuilderRequest{
    	workflow: %Workflow{source_repo_git_ref: "123abc"},
    	orchestrator_request: %Request{workflow: %Workflow{source_repo_git_ref: "123abc"}},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> true end)  
    :meck.expect(DeploymentRepo, :resolve_ecs_file_template, fn _,_ -> true end)    
    :meck.expect(DeploymentRepo, :checkin_pending_changes, fn _, _ -> :ok end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :save_workflow, fn _ -> request end)

    {:ok, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
  	:meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
    :meck.unload(BuilderRequest)
  end

  test "execute - success, no files" do
    request = %BuilderRequest{
      workflow: %Workflow{source_repo_git_ref: "123abc"},
      orchestrator_request: %Request{workflow: %Workflow{source_repo_git_ref: "123abc"}},
      deployment_repo: %DeploymentRepo{
        etcd_token: "123abc"
      }
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> false end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> false end) 
    :meck.expect(DeploymentRepo, :resolve_ecs_file_template, fn _,_ -> false end)   

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :save_workflow, fn _ -> request end)

    {:ok, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
    :meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
    :meck.unload(BuilderRequest)
  end

  test "execute - failure" do
    request = %BuilderRequest{
      workflow: %Workflow{source_repo_git_ref: "123abc"},
    	orchestrator_request: %Request{workflow: %Workflow{source_repo_git_ref: "123abc"}},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_ecs_file_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :checkin_pending_changes, fn _, _ -> {:error, "bad news bears"} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :save_workflow, fn _ -> request end)

    {:error, _, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
  	:meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
    :meck.unload(BuilderRequest)
  end  

  test "execute - set notifications config" do
    request = %BuilderRequest{
      workflow: %Workflow{source_repo_git_ref: "123abc"},
      orchestrator_request: %Request{workflow: %Workflow{source_repo_git_ref: "123abc"}},
      deployment_repo: %DeploymentRepo{
        etcd_token: "123abc",
        source_repo: %SourceRepo{}
      }
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> true end) 
    :meck.expect(DeploymentRepo, :resolve_ecs_file_template, fn _,_ -> true end)   
    :meck.expect(DeploymentRepo, :checkin_pending_changes, fn _, _ -> :ok end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn _,_ -> request end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :save_workflow, fn _ -> request end)

    :meck.new(OpenAperture.Builder.Git, [:passthrough])
    :meck.expect(OpenAperture.Builder.Git, :get_current_commit_hash, fn _ -> {:ok, "123abc"} end)

    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :get_openaperture_info, fn _ -> %{
      "deployments" => %{
        "notifications" => %{}
      }
    } end)

    {:ok, returned_request} = Config.execute(request)
    assert returned_request != nil
  after
    :meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
    :meck.unload(SourceRepo)
    :meck.unload(OpenAperture.Builder.Git)
    :meck.unload(BuilderRequest)
  end

  test "execute - set current git hash" do
    request = %BuilderRequest{
      workflow: %Workflow{source_repo_git_ref: "123abc"},
      orchestrator_request: %Request{workflow: %Workflow{source_repo_git_ref: "123abc"}},
      deployment_repo: %DeploymentRepo{
        etcd_token: "123abc",
        source_repo: %SourceRepo{}
      }
    }

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :resolve_dockerfile_template, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_service_file_templates, fn _,_ -> true end)
    :meck.expect(DeploymentRepo, :resolve_ecs_file_template, fn _,_ -> true end)    
    :meck.expect(DeploymentRepo, :checkin_pending_changes, fn _, _ -> :ok end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :publish_success_notification, fn req, _ -> req end)

    :meck.new(BuilderRequest, [:passthrough])
    :meck.expect(BuilderRequest, :save_workflow, fn req -> req end)

    :meck.new(OpenAperture.Builder.Git, [:passthrough])
    :meck.expect(OpenAperture.Builder.Git, :get_current_commit_hash, fn _ -> {:ok, "commit_hash_from_git"} end)

    :meck.new(SourceRepo, [:passthrough])
    :meck.expect(SourceRepo, :get_openaperture_info, fn _ -> nil end)

    {:ok, returned_request} = Config.execute(request)
    assert returned_request != nil
    assert returned_request.workflow.source_repo_git_ref == "commit_hash_from_git"
  after
    :meck.unload(DeploymentRepo)
    :meck.unload(Workflow)
    :meck.unload(SourceRepo)
    :meck.unload(OpenAperture.Builder.Git)
    :meck.unload(BuilderRequest)
  end
end
