defmodule Spacesuit.AuthMiddleware do
  require Logger

  @jwt_secret Application.get_env(:spacesuit, :jwt_secret)

  def execute(req, env) do
    case req[:headers]["authorization"] do
      nil ->
        Logger.warn "No auth header"
        {:ok, req, env}

      "magic!" ->
        Logger.warn "Unauthorized request"
        reply(req, 401, "Unauthorized")
        {:halt, req}

      "Bearer " <> token ->
        handle_bearer_token(req, env, token)

      authorization ->
        # TODO we got some header but we don't know what it is
        Logger.info "Found authorization header! #{authorization}"
        {:ok, strip_auth(req), env}
    end
  end

  defp strip_auth(req) do
    %{ req | headers: Map.delete(req[:headers], "authorization") }
  end

  defp reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: message}
    )
    :cowboy_req.reply(code, %{}, msg, req)
  end

  # Consume a bearer token, validate it, and then either
  # reject it or pass it on to a session service to be
  # enriched.
  def handle_bearer_token(req, env, token) do
    if valid_api_token?(token) do
      # TODO call session service
      {:ok, strip_auth(req), env}
    else
      reply(req, 401, "Bad Authentication Token")
      {:halt, req}
    end
  end

  def valid_api_token?(token) do
    result =
        token
        |> Joken.token
        |> Joken.with_signer(Joken.hs384(@jwt_secret))
        |> Joken.verify

    result.error == nil
  end
end
