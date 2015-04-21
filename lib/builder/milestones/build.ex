require Logger

defmodule OpenAperture.Builder.Milestones.Build do

  alias OpenAperture.Builder.DeploymentRepo

  @moduledoc """
  This module contains the logic for the "Build" Workflow milestone
  """  

  @doc """
  Method to process an incoming Builder request

  ## Options

  The `request` option defines the BuilderRequest

  """
  @spec execute(BuilderRequest.t) :: {:ok, BuilderRequest.t} | {:error, String.t, BuilderRequest.t}
  def execute(request) do
    Logger.info ("Beginning docker image build of #{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}...")    
    case DeploymentRepo.create_docker_image(request.deployment_repo, ["#{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}"]) do
      :ok -> {:ok, request}
      {:error, reason} -> {:error, "Failed to build docker image #{request.deployment_repo.docker_repo_name}:#{request.workflow.source_repo_git_ref}:  #{inspect reason}", request}
    end
  end
end