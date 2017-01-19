defmodule Spacesuit do
  use Application

  def start(_type, _args) do
    routes = Spacesuit.Router.load_routes

    dispatch = routes
      |> List.insert_at(0, {"admin.example.com", [ {"/admin/list_routes", Spacesuit.AdminHandler, [routes] }]})
      |> :cowboy_router.compile

#    dispatch = :cowboy_router.compile([
#      {:_, [
#          {"/users/:user_id/[...]", Spacesuit.ProxyHandler, [destination: "https://google.com/"]},
#          {"/[...]", Spacesuit.ProxyHandler, [destination: "https://news.ycombinator.com"]}
#      ]}
#    ])

    {:ok, _} = :cowboy.start_clear(
        :http, 100, [port: 8080],
        %{
           env: %{
            dispatch: dispatch
           },
           middlewares: [
             :cowboy_router, Spacesuit.DebugMiddleware, Spacesuit.AuthMiddleware, :cowboy_handler
           ]
           #middlewares: [:cowboy_router, <your_middleware_here>, :cowboy_handler]
         }
    )

    Spacesuit.Supervisor.start_link
  end
end
