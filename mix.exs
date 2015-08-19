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
        :openaperture_overseer_api,
        :porcelain,
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
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "3d3a84eabf4ba0a3a827a61c4d99cdbf0ab49a0d", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git", ref: "86cf2c324434f9899416881219e03c0f959c2896", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4b9146507ab50789fec4696b96f79642add2b502", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "324acdae0ceecb6a954d804d56d9d2fceaeb937c", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "df4033a048145c62361e7e161c60142b7fc501e4", override: true},
      {:tail, "~> 1.0.0"},
      {:timex, "~> 0.13.3", override: true},
      {:fleet_api, "~> 0.0.15", override: true},
      {:porcelain, "~>2.0.0"},
      {:uuid, "~> 0.1.5" },

      {:meck, "0.8.3", override: true},
     ]
  end
end
