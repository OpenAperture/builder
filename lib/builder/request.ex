defmodule OpenAperture.Builder.Request do

	@moduledoc """
	Methods and Request struct for Builder requests
	"""

  defstruct workflow: nil, 
  					orchestrator_request: nil,
	  				deployment_repo: nil,
	  				delivery_tag: nil

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
end