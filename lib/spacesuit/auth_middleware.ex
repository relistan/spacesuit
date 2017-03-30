defmodule Spacesuit.AuthMiddleware do
  require Logger
  use Elixometer

  @timed(key: "timed.authMiddleware-handle", units: :millisecond)
  def execute(req, env) do
    session_service = Application.get_env(:spacesuit, :session_service)

    case req[:headers]["authorization"] do
      nil ->
        Logger.debug "No auth header"
        {:ok, req, env}

      "Bearer " <> token ->
        case session_service[:enabled] do
          true ->
            session_service[:impl].handle_bearer_token(req, env, token, session_service[:url])
          false -> 
            {:ok, req, env}
          _ ->
            Logger.warn "Session service :enabled not configured!"
            {:ok, req, env}
        end

      authorization ->
        # TODO we got some header but we don't know what it is
        Logger.info "Found unknown authorization header! #{authorization}"
        {:ok, strip_auth(req), env}
    end
  end

  defp strip_auth(req) do
    %{ req | headers: Map.delete(req[:headers], "authorization") }
  end
end
