use Mix.Config

# Silence log output during tests unless it's an error
config :spacesuit, http_client: Spacesuit.HttpClient.Mock
config :spacesuit, http_server: Spacesuit.HttpServer.Mock

config :spacesuit, jwt_secret: "secret"
config :spacesuit, routes: %{}

config :spacesuit, cors: %{
  enabled: true,
  path_prefixes: ["/matched"],
  preflight_max_age: "3600",
  access_control_request_headers: ["X-Header1", "X-Header2"]
}

config :logger, level: :error
