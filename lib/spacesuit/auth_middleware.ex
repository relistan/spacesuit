defmodule Spacesuit.AuthMiddleware do
  require Logger

  def execute(req, env) do
    case req[:headers]["authorization"] do
      nil ->
        Logger.warn "No auth header"
        {:ok, req, env}

      "magic!" ->
        Logger.warn "Unauthorized request"
        error_reply(req, 401, "Unauthorized")
        {:halt, req}

      "Bearer " <> token ->
        Logger.info "Token: #{:base64.decode(token)}"
        # TODO do something smart here
        {:ok, strip_auth(req), env}

      authorization ->
        # TODO we got some header but we don't know what it is
        Logger.info "Found authorization header! #{authorization}"
        {:ok, strip_auth(req), env}
    end
  end

  defp strip_auth(req) do
    %{ req | headers: Map.delete(req[:headers], "authorization") }
  end

  defp error_reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: message}
    )
    :cowboy_req.reply(code, %{}, msg, req)
  end
end
