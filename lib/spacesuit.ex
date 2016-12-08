defmodule Spacesuit do
  use Application

  def start(_type, _args) do
    dispatch = :cowboy_router.compile([
      {:_, [
          {"/[...]", Spacesuit.TopPageHandler, []}
      ]}
    ])

    {:ok, _} = :cowboy.start_clear(
        :http, 100, [port: 8080],
        %{ env: %{ dispatch: dispatch } }
    )

    Spacesuit.Supervisor.start_link
  end
end
