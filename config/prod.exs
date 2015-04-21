use Mix.Config

config :logger, level: :info


config :autostart,
	register_queues: true

config :openaperture_manager_api, 
	manager_url: System.get_env("MANAGER_URL"),
	oauth_login_url: System.get_env("OAUTH_LOGIN_URL"),
	oauth_client_id: System.get_env("OAUTH_CLIENT_ID"),
	oauth_client_secret: System.get_env("OAUTH_CLIENT_SECRET")