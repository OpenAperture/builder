use Mix.Config

config :logger, level: :warn

config :autostart,
	register_queues: false

config :openaperture_builder,
	broker_id: "1",
	exchange_id: "1",
	github_user_credentials: "user",
	tmp_dir: "/tmp/openaperture",
	docker_registry_url: "https://index.docker.io/v1/",
	docker_registry_username: "user",
	docker_registry_email: "user@test.com",
	docker_registry_password: "pass",
	skip_goon_check: true,
	build_log_publisher_autostart: false,
	milestone_monitor_sleep_seconds: 1

config :openaperture_overseer_api,
	module_type: :test,
	autostart: false,	
	exchange_id: "1",
	broker_id: "1"