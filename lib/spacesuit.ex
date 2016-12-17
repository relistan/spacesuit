defmodule Spacesuit do
  use Application

  def start(_type, _args) do
    dispatch = Spacesuit.Router.load_routes |> :cowboy_router.compile

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
             :cowboy_router, Spacesuit.DebugMiddleware, :cowboy_handler
           ]
           #middlewares: [:cowboy_router, <your_middleware_here>, :cowboy_handler]
         }
    )

    Spacesuit.Supervisor.start_link
  end
end
