defmodule OpenAperture.Builder.Request do

  alias OpenAperture.WorkflowOrchestratorApi.Workflow
  
	@moduledoc """
	Methods and Request struct for Builder requests
	"""

  defstruct workflow: nil, 
  					orchestrator_request: nil,
	  				deployment_repo: nil,
	  				delivery_tag: nil,
            image_found: false

  @type t :: %__MODULE__{}

  @doc """
  Method to convert a map into a Request struct

  ## Options

  The `payload` option defines the Map containing the request

  ## Return Values

  OpenAperture.WorkflowOrchestratorApi.Request.t
  """
  @spec from_payload(Map) :: OpenAperture.Builder.Request.t
  def from_payload(payload) do
  	orchestrator_request = OpenAperture.WorkflowOrchestratorApi.Request.from_payload(payload)

  	%OpenAperture.Builder.Request{
  		workflow: orchestrator_request.workflow,
  		orchestrator_request: orchestrator_request
    }
  end

  @doc """
  Convenience wrapper to add Notifications configuration to the request

  ## Options
   
  The `builder_request` option defines the Request

  The `config` option represents the Notifications configuration options

  ## Return values

  Request
  """
  @spec set_notifications_config(OpenAperture.Builder.Request.t, Map) :: OpenAperture.Builder.Request.t
  def set_notifications_config(builder_request, config) do
    orchestrator_request = %{builder_request.orchestrator_request | notifications_config: config}
    %{builder_request | orchestrator_request: orchestrator_request}
  end

  @doc """
  Convenience wrapper to add Fleet configuration to the request

  ## Options
   
  The `builder_request` option defines the Request

  The `config` option represents the Notifications configuration options

  ## Return values

  Request
  """
  @spec set_fleet_config(OpenAperture.Builder.Request.t, Map) :: OpenAperture.Builder.Request.t
  def set_fleet_config(builder_request, config) do
    orchestrator_request = %{builder_request.orchestrator_request | fleet_config: config}
    %{builder_request | orchestrator_request: orchestrator_request}
  end

  @doc """
  Convenience wrapper to publish a "success" notification to the associated Workflow

  ## Options
   
  The `builder_request` option defines the Request

  The `message` option defines the message to publish

  ## Return values

  Request
  """
  @spec publish_success_notification(OpenAperture.Builder.Request.t, String.t()) :: OpenAperture.Builder.Request.t
  def publish_success_notification(builder_request, message) do
    orchestrator_request = Workflow.publish_success_notification(builder_request.orchestrator_request, message)
    %{builder_request | orchestrator_request: orchestrator_request, workflow: orchestrator_request.workflow}
  end
end