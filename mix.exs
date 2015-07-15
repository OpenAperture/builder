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
      {:ex_doc, "0.7.3", only: :test},
      {:earmark, "0.1.17", only: :test}, 
      {:poison, "~> 1.4.0", override: true},
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "525e68bdcec83a30d914813a58302cea02648b06", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git", ref: "84eedf15d805e6a827b3d62978b5a20244c99094", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4b9146507ab50789fec4696b96f79642add2b502", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "714c52b5258f96e741b57c73577431caa6f480b3", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "c66fa165e9ee07250d264b4b63ce375692e2b7cc", override: true},
      {:tail, git: "https://github.com/TheFirstAvenger/elixir-tail", ref: "31f44c6d28874ba8f85066012bc686fb510073b6"},
      {:timex, "~> 0.12.9"},
      {:fleet_api, "~> 0.0.11", override: true},

      {:meck, "0.8.2", only: :test},
     ]
  end
end
