require Logger

defmodule Spacesuit do
  use Application
  
  @moduledoc """
    The main Spacesuit application module.
  """

  @http_port 8080

  def start(_type, _args) do
    Logger.info "Spacesuit starting up on :#{@http_port}"

    dispatch = Spacesuit.Router.load_routes |> :cowboy_router.compile

    {:ok, _} = :cowboy.start_clear(
        :http, 100, [port: @http_port],
        %{
           env: %{
            dispatch: dispatch
           },
           middlewares: [
             :cowboy_router, Spacesuit.DebugMiddleware, Spacesuit.AuthMiddleware, :cowboy_handler
             #:cowboy_router, Spacesuit.AuthMiddleware, :cowboy_handler
           ]
         }
    )

    Spacesuit.Supervisor.start_link
  end
end
