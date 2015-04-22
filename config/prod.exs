use Mix.Config

config :logger, level: :info


config :autostart,
	register_queues: true

config :openaperture_manager_api, 
	manager_url: System.get_env("MANAGER_URL"),
	oauth_login_url: System.get_env("OAUTH_LOGIN_URL"),
	oauth_client_id: System.get_env("OAUTH_CLIENT_ID"),
	oauth_client_secret: System.get_env("OAUTH_CLIENT_SECRET")

config :github, 
	user_credentials: System.get_env("GITHUB_OAUTH_TOKEN")

config :openaperture_overseer_api,
	module_type: :builder,
	exchange_id: System.get_env("EXCHANGE_ID"),
	broker_id: System.get_env("BROKER_ID")