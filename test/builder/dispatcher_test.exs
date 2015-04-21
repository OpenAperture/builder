defmodule OpenAperture.Builder.DispatcherTest do
  use ExUnit.Case

  alias OpenAperture.Builder.Dispatcher

  alias OpenAperture.Messaging.AMQP.ConnectionPool
  alias OpenAperture.Messaging.AMQP.ConnectionPools
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  alias OpenAperture.Messaging.ConnectionOptionsResolver
  alias OpenAperture.Messaging.AMQP.Exchange, as: AMQPExchange
  alias OpenAperture.Messaging.AMQP.ConnectionOptions, as: AMQPConnectionOptions
  alias OpenAperture.Messaging.AMQP.QueueBuilder

  alias OpenAperture.WorkflowOrchestratorApi.Workflow
  alias OpenAperture.WorkflowOrchestratorApi.Request

  alias OpenAperture.Builder.MessageManager
  alias OpenAperture.Builder.Request, as: BuilderRequest
  alias OpenAperture.Builder.DeploymentRepo
  alias OpenAperture.Builder.Milestones.Config, as: ConfigMilestone
  alias OpenAperture.Builder.Milestones.Build, as: BuildMilestone

  # ===================================
  # register_queues tests

  test "register_queues success" do
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, _, _, _ -> :ok end)

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _, _ -> %AMQPConnectionOptions{} end)

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    assert Dispatcher.register_queues == :ok
  after
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
    :meck.unload(ConnectionOptionsResolver)
    :meck.unload(QueueBuilder)
  end

  test "register_queues failure" do
    :meck.new(ConnectionPools, [:passthrough])
    :meck.expect(ConnectionPools, :get_pool, fn _ -> %{} end)

    :meck.new(ConnectionPool, [:passthrough])
    :meck.expect(ConnectionPool, :subscribe, fn _, _, _, _ -> {:error, "bad news bears"} end)

    :meck.new(ConnectionOptionsResolver, [:passthrough])
    :meck.expect(ConnectionOptionsResolver, :get_for_broker, fn _, _ -> %AMQPConnectionOptions{} end)    

    :meck.new(QueueBuilder, [:passthrough])
    :meck.expect(QueueBuilder, :build, fn _,_,_ -> %OpenAperture.Messaging.Queue{name: ""} end)      

    assert Dispatcher.register_queues == {:error, "bad news bears"}
  after
    :meck.unload(ConnectionPool)
    :meck.unload(ConnectionPools)
    :meck.unload(ConnectionOptionsResolver)
    :meck.unload(QueueBuilder)
  end 

  test "acknowledge" do
    :meck.new(MessageManager, [:passthrough])
    :meck.expect(MessageManager, :remove, fn _ -> %{} end)

    :meck.new(SubscriptionHandler, [:passthrough])
    :meck.expect(SubscriptionHandler, :acknowledge, fn _, _ -> :ok end)

    Dispatcher.acknowledge("123abc")
  after
    :meck.unload(MessageManager)
    :meck.unload(SubscriptionHandler)
  end

  test "reject" do
    :meck.new(MessageManager, [:passthrough])
    :meck.expect(MessageManager, :remove, fn _ -> %{} end)

    :meck.new(SubscriptionHandler, [:passthrough])
    :meck.expect(SubscriptionHandler, :reject, fn _, _, _ -> :ok end)

    Dispatcher.reject("123abc")
  after
    :meck.unload(MessageManager)
    :meck.unload(SubscriptionHandler)
  end  

  test "execute_milestone(:completed)" do
    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_completed, fn orchestrator_request -> 
    	assert orchestrator_request.etcd_token == "123abc"
    	assert orchestrator_request.deployable_units == []
    	:ok
    end)

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :get_units, fn _ -> [] end)

    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }
    Dispatcher.execute_milestone(:completed, {:ok, request})
  after
    :meck.unload(Workflow)
    :meck.unload(DeploymentRepo)
  end

  test "execute_milestone(:build) - success" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(BuildMilestone, [:passthrough])
    :meck.expect(BuildMilestone, :execute, fn _ -> {:ok, request} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_completed, fn orchestrator_request -> 
    	assert orchestrator_request.etcd_token == "123abc"
    	assert orchestrator_request.deployable_units == []
    	:ok
    end)

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :get_units, fn _ -> [] end)

    Dispatcher.execute_milestone(:build, {:ok, request})
  after
    :meck.unload(Workflow)
    :meck.unload(DeploymentRepo)  	
    :meck.unload(BuildMilestone)
  end  

  test "execute_milestone(:build) - failure" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(BuildMilestone, [:passthrough])
    :meck.expect(BuildMilestone, :execute, fn _ -> {:error, "bad news bears", request} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_failed, fn _,_,_ -> :ok end)

    Dispatcher.execute_milestone(:build, {:ok, request})
  after
    :meck.unload(Workflow)	
    :meck.unload(BuildMilestone)
  end

  test "execute_milestone(:config) - success" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(ConfigMilestone, [:passthrough])
    :meck.expect(ConfigMilestone, :execute, fn _ -> {:ok, request} end)

    :meck.new(BuildMilestone, [:passthrough])
    :meck.expect(BuildMilestone, :execute, fn _ -> {:ok, request} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_completed, fn orchestrator_request -> 
    	assert orchestrator_request.etcd_token == "123abc"
    	assert orchestrator_request.deployable_units == []
    	:ok
    end)

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :get_units, fn _ -> [] end)

    Dispatcher.execute_milestone(:config, {:ok, request})
  after
    :meck.unload(Workflow)
    :meck.unload(DeploymentRepo)  	
    :meck.unload(BuildMilestone)
    :meck.unload(ConfigMilestone)
  end  

  test "execute_milestone(:config) - failure" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(ConfigMilestone, [:passthrough])
    :meck.expect(ConfigMilestone, :execute, fn _ -> {:error, "bad news bears", request} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_failed, fn _,_,_ -> :ok end)

    Dispatcher.execute_milestone(:config, {:ok, request})
  after
    :meck.unload(Workflow)	
    :meck.unload(ConfigMilestone)
  end  

  test "execute_milestone(_, {:error}) - failure" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_failed, fn _,_,_ -> :ok end)

    Dispatcher.execute_milestone(:config, {:error, "bad news bears", request})
  after
    :meck.unload(Workflow)	
  end   

  test "process_request - success" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(ConfigMilestone, [:passthrough])
    :meck.expect(ConfigMilestone, :execute, fn _ -> {:ok, request} end)

    :meck.new(BuildMilestone, [:passthrough])
    :meck.expect(BuildMilestone, :execute, fn _ -> {:ok, request} end)

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_completed, fn orchestrator_request -> 
    	assert orchestrator_request.etcd_token == "123abc"
    	assert orchestrator_request.deployable_units == []
    	:ok
    end)

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :get_units, fn _ -> [] end)
    :meck.expect(DeploymentRepo, :init_from_workflow, fn _ -> {:ok, %{}} end)
    :meck.expect(DeploymentRepo, :cleanup, fn _ -> :ok end)

    :meck.new(MessageManager, [:passthrough])
    :meck.expect(MessageManager, :remove, fn _ -> %{} end)    

    :meck.new(SubscriptionHandler, [:passthrough])
    :meck.expect(SubscriptionHandler, :acknowledge, fn _, _ -> :ok end)    
    
    Dispatcher.process_request(request)
  after
    :meck.unload(Workflow)
    :meck.unload(DeploymentRepo)  	
    :meck.unload(BuildMilestone)
    :meck.unload(ConfigMilestone)
    :meck.unload(MessageManager)
    :meck.unload(SubscriptionHandler)
  end  

  test "process_request - failure" do
    request = %BuilderRequest{
    	orchestrator_request: %Request{},
    	deployment_repo: %DeploymentRepo{
    		etcd_token: "123abc"
    	}
    }

    :meck.new(Workflow, [:passthrough])
    :meck.expect(Workflow, :step_completed, fn orchestrator_request -> 
    	assert orchestrator_request.etcd_token == "123abc"
    	assert orchestrator_request.deployable_units == []
    	:ok
    end)

    :meck.new(DeploymentRepo, [:passthrough])
    :meck.expect(DeploymentRepo, :get_units, fn _ -> [] end)
    :meck.expect(DeploymentRepo, :init_from_workflow, fn _ -> {:error, "bad news bears"} end)

    :meck.new(MessageManager, [:passthrough])
    :meck.expect(MessageManager, :remove, fn _ -> %{} end)    

    :meck.new(SubscriptionHandler, [:passthrough])
    :meck.expect(SubscriptionHandler, :acknowledge, fn _, _ -> :ok end)    
    
    Dispatcher.process_request(request)
  after
    :meck.unload(Workflow)
    :meck.unload(DeploymentRepo)  	
    :meck.unload(MessageManager)
    :meck.unload(SubscriptionHandler)
  end  
end
