defmodule OpenAperture.Builder.Mixfile do
  use Mix.Project

  def project do
    [app: :openaperture_builder,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      mod: {OpenAperture.Builder, []},
      applications: [
        :logger, 
        :openaperture_messaging, 
        :openaperture_manager_api, 
        :openaperture_fleet, 
        :openaperture_workflow_orchestrator_api,
        :openaperture_overseer_api
      ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:ex_doc, github: "elixir-lang/ex_doc", only: [:test]},
      {:markdown, github: "devinus/markdown", only: [:test]},
            
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git",ref: "e3247e4fbcc097a3156e3b95ad2115408693ca12", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git",ref: "32986942e702dc4b32ab9118362cda992949fa6c", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "7aa864eeb3876b476c89d58c56364cbb0fa2fb08", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "488832b216a1a139a6c58d788083cf5054b3dbe8", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "515a4ad10c2a078dc0faee501d6109335f53b3e6", override: true},
      {:timex, "~> 0.12.9"},
      
      {:meck, "0.8.2", only: :test},
     ]
  end
end
