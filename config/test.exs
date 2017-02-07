use Mix.Config

# Silence log output during tests unless it's an error
config :logger, level: :error
config :spacesuit, http_client: Spacesuit.HttpClient.Mock

config :spacesuit, jwt_secret: "secret"
config :spacesuit, routes: %{}
