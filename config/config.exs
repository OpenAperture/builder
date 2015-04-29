# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for third-
# party users, it should be done in your mix.exs file.

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]

config :openaperture_builder,
	tmp_dir: System.get_env("BUILDER_TMPDIR") || "/tmp/openaperture",
	docker_registry_url: System.get_env("DOCKER_REGISTRY_URL") || "https://index.docker.io/v1/",
	docker_registry_username: System.get_env("DOCKER_REGISTRY_USERNAME"),
	docker_registry_email: System.get_env("DOCKER_REGISTRY_EMAIL"),
	docker_registry_password: System.get_env("DOCKER_REGISTRY_PASSWORD")

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
