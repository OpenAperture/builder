defmodule OpenAperture.Builder.Dispatcher do
	use GenServer
  @connection_options nil
	use OpenAperture.Messaging
	alias OpenAperture.Messaging.Queue
	alias OpenAperture.Messaging.AMQP.Exchange, as: AMQPExchange
  	alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  	alias OpenAperture.Builder.MessageManager

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
  	milestone_queue = %Queue{
      name: "workflow_orchestration", 
      exchange: %AMQPExchange{name: Application.get_env(:cloudos_builder, :exchange_id), options: [:durable]},
      error_queue: "workflow_orchestration_error",
      options: [durable: true, arguments: [{"x-dead-letter-exchange", :longstr, ""},{"x-dead-letter-routing-key", :longstr, "workflow_orchestration_error"}]],
      binding_options: [routing_key: "workflow_orchestration"]
    }

    callback =  fn(payload, _meta, async_info) -> 
      				    handle_callback(payload, async_info)
    			      end

    OpenAperture.ManagerApi.get_api()
  		|> OpenAperture.Messaging.ConnectionOptionsResolver.get_for_broker(Application.get_env(:cloudos_builder, :broker_id))
  		|> subscribe(milestone_queue, callback)
  	{:ok, []}
  end

  def handle_callback(payload, %{subscription_handler: _subscription_handler, delivery_tag: _delivery_tag} = async_info) do
    MessageManager.track(async_info)
    options = resolve_payload(payload)
    case OpenAperture.Builder.Config.config(options) do
      {:ok, deploy_repo} -> 
        case OpenAperture.Builder.Build.build(deploy_repo) do
          {:ok, deploy_repo} -> 
            DeploymentRepo.cleanup(deploy_repo)
            IO.puts "done"
          {:error, reason} -> IO.puts "error: #{inspect reason}"
        end
      {:error, reason} -> IO.puts "error: #{inspect reason}"
    end
  end

  defp resolve_payload(payload) do
    payload|>
      Map.merge %{deployment_repo: DeploymentRepo.create!()}
  end

  def acknowledge(delivery_tag) do
    message = MessageManager.remove(delivery_tag)
    unless message == nil do
      SubscriptionHandler.acknowledge(message[:subscription_handler], message[:delivery_tag])
    end
  end

  def reject(delivery_tag, redeliver \\ false) do
    message = MessageManager.remove(delivery_tag)
    unless message == nil do
      SubscriptionHandler.reject(message[:subscription_handler], message[:delivery_tag], redeliver)
    end
  end  
end