defmodule Spacesuit.HealthHandler do
  require Logger

  @http_server Application.get_env(:spacesuit, :http_server)

  # Callback from the Cowboy handler
  def init(req, state) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "ok", message: "Spacesuit running OK"}
    )
    @http_server.reply(200, %{}, msg, req)
    
    {:ok, req, state}
  end

end
