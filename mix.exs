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
      
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "8c51d099ec79473b23b3c385c072e6bf2219fba7", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git", ref: "5d442cfbdd45e71c1101334e185d02baec3ef945", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4d65d2295f2730bc74ec695c32fa0d2478158182", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "2e63b7889c76f4d3b749146f3ebceb01702cf012", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "c9c4175117f4807fb312637374d8119772913e3e", override: true},
      {:tail, git: "https://github.com/TheFirstAvenger/elixir-tail", ref: "31f44c6d28874ba8f85066012bc686fb510073b6"},
      {:timex, "~> 0.12.9"},
      {:fleet_api, "~> 0.0.6", override: true},

      {:meck, "0.8.2", only: :test},
     ]
  end
end
