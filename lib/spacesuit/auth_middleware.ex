defmodule Spacesuit.AuthMiddleware do
  require Logger
  use Elixometer

  @http_server Application.get_env(:spacesuit, :http_server)

  @timed key: "timed.authMiddleware-handle", units: :millisecond
  def execute(req, env) do
    case req[:headers]["authorization"] do
      nil ->
        Logger.debug("No auth header")
        {:ok, req, env}

      "Bearer " <> token ->
        case session_service()[:enabled] do
          true ->
            handle_bearer_token(req, env, token)

          false ->
            {:ok, req, env}

          _ ->
            Logger.warn("Session service :enabled not configured!")
            {:ok, req, env}
        end

      authorization ->
        # TODO we got some header but we don't know what it is
        Logger.info("Found unknown authorization header! #{authorization}")
        {:ok, strip_auth(req), env}
    end
  end

  defp handle_bearer_token(req, env, token) do
    if bypass_session_srv?(env) do
      case session_service()[:impl].validate_api_token(token) do
        :ok ->
          {:ok, req, env}

        # Otherwise we blow up the request
        unexpected ->
          Logger.error("auth_middleware error: unexpected response - #{inspect(unexpected)}")
          error_reply(req, 401, "Bad Authentication Token")
          {:stop, req}
      end
    else
      session_service()[:impl].handle_bearer_token(req, env, token, session_service()[:url])
    end
  end

  defp strip_auth(req) do
    %{req | headers: Map.delete(req[:headers], "authorization")}
  end

  # should the session service be bypassed for this route?
  defp bypass_session_srv?(env) do
    case get_in(env, [:handler_opts, :middleware, :session_service]) do
      :disabled -> true
      _ -> false
    end
  end

  defp error_reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(%Spacesuit.ApiMessage{status: "error", message: message})
    @http_server.reply(code, %{}, msg, req)
  end

  # Quick access function for the application settings for this middleware
  def session_service do
    Application.get_env(:spacesuit, :session_service)
  end
end
