defmodule Spacesuit.AuthMiddleware do
  require Logger

  @http_server     Application.get_env(:spacesuit, :http_server)
  @jwt_secret      Application.get_env(:spacesuit, :jwt_secret)
  @session_service Application.get_env(:spacesuit, :session_service)
  @recv_timeout    500 # How many milliseconds before we timeout call to session-service

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
        if @session_service[:enabled] do
          handle_bearer_token(req, token)
        else 
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

  defp reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: message}
    )
    @http_server.reply(code, %{}, msg, req)
  end

  # Consume a bearer token, validate it, and then either
  # reject it or pass it on to a session service to be
  # enriched.
  def handle_bearer_token(req, token) do
    result = with :ok <- validate_api_token(token),
      {:ok, enriched} <- get_enriched_token(token),
      do: result_with_new_token(req, enriched)

    case result do
      {:ok, _} -> # Just pass on the result
        result

      {:error, error} ->
        Logger.error("Session-service error: #{error}")
        reply(req, 401, "Bad Authentication Token")
        {:halt, req}

      _ -> # Otherwise we blow up the request
        reply(req, 401, "Bad Authentication Token")
        {:halt, req}
    end
  end

  def result_with_new_token(req, token) do
    new_req = %{ req | headers: Map.put(req[:headers], "authorization", token) }
    {:ok, new_req}
  end

  def validate_api_token(token) do
    result =
        token
        |> Joken.token
        |> Joken.with_signer(Joken.hs384(@jwt_secret))
        |> Joken.verify

    case result.error do
      nil -> :ok
      _ -> :error
    end
  end

  defp get_enriched_token(token) do
    headers = [
      "Authorization": "Bearer #{token}",
      "Accept": "Application/json; Charset=utf-8"
    ]
    options = [
      ssl: [{:versions, [:'tlsv1.2']}],
      recv_timeout: @recv_timeout
    ]

    case HTTPoison.get(@session_service[:url], headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: code, body: body}} when code >= 400 and code <= 499 ->
        {:error, body}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
         {:error, reason}
    end
  end
end
