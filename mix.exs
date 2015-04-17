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
    [applications: [:logger, :openaperture_messaging, :openaperture_manager_api, :openaperture_fleet],
     mod: {OpenAperture.Builder, []}]
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
      {:openaperture_messaging,
       git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/messaging.git",
       ref: "3211204ba8d949b76bc3373ee91260944cc0ff6b"},
      {:openaperture_manager_api,
       git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/manager_api.git",
       ref: "f67a4570ec4b46cb2b2bb746924b322eec1e3178"},
      {:openaperture_fleet,
       git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/fleet.git",
       ref: "0c648a0645106e51b858e3dbddefa570cdd2785a"},
      {:timex, "~> 0.12.9"},
      
      {:meck, "0.8.2", only: :test},
     ]
  end
end
