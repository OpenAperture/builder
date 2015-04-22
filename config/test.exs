use Mix.Config

config :logger, level: :warn

config :autostart,
	register_queues: false

config :openaperture_builder,
	broker_id: "1",
	exchange_id: "1",
	github_user_credentials: "user",
	tmp_dir: "/tmp/openaperture",
	docker_registry_url: "https://hub.docker.com",
	docker_registry_username: "user",
	docker_registry_email: "user@test.com",
	docker_registry_password: "pass"

config :openaperture_overseer_api,
	module_type: :test,
	autostart: false,	
	exchange_id: "1",
	broker_id: "1"