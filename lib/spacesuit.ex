defmodule Spacesuit do
  use Application

  def start(_type, _args) do
    [routes] = :yamerl_constr.file("routes.yaml")

    dispatch = routes
      |> transform_routes
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
             :cowboy_router, :cowboy_handler, Spacesuit.DebugMiddleware,
           ]
           #middlewares: [:cowboy_router, <your_middleware_here>, :cowboy_handler]
         }
    )

    Spacesuit.Supervisor.start_link
  end

  defp transform_routes(source) do
    Enum.map(source, fn({host, routes}) ->
      {host, Enum.map(routes, &transform_one_route/1)}
    end)
  end

  defp transform_one_route(source) do
    {route, [{'destination', destination} | _ ]} = source
    {route, Spacesuit.ProxyHandler, [destination: destination]}
  end

end
