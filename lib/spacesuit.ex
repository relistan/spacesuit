defmodule Spacesuit do
  use Application

  def start(_type, _args) do
    dispatch = :cowboy_router.compile([
      {:_, [
          {"/[...]", Spacesuit.ProxyHandler, []}
      ]}
    ])

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
end
