defmodule SessionService do
  @moduledoc """
    Describe a SessionService implementation. Use for handling auth derived
    from bearer tokens.
  """

  @callback validate_api_token(String.t) :: Tuple.t
  @callback handle_bearer_token(Map.t, Map.t, String.t, String.t) :: Tuple.t
end

defmodule Spacesuit.MockSessionService do
  @behaviour SessionService

  def validate_api_token(token) do
    case token do
      "ok" ->    :ok
      "error" -> :error
      _ ->       :error
    end
  end

  def handle_bearer_token(req, env, token, _url) do
    case token do
      "ok" ->    {:ok, req, env}
      "error" -> {:stop, req, env}
      _ ->       {:ok, req, env}
    end
  end
end

defmodule Spacesuit.SessionService do
  @moduledoc """
    Implementation of a SessionService that calls out to an external service
    over HTTP, passing the original bearer token, and receiving back a JSON
    blob containing an enriched/modified token.
  """
  require Logger
  use Elixometer

  @behaviour SessionService

  @jwt_secret      Application.get_env(:spacesuit, :jwt_secret)
  @http_server     Application.get_env(:spacesuit, :http_server)
  @recv_timeout    500 # How many milliseconds before we timeout call to session-service

  @doc """
    Do a quick validation on the token provided
  """
  def validate_api_token(token) do
    result =
        token
        |> Joken.token
        |> Joken.with_signer(Joken.hs384(@jwt_secret))
        |> Joken.verify

    case result.error do
      nil -> :ok
      _ ->   :error
    end
  end

  @doc """
    Exchange the token for an enriched token from the Session service
  """
  @spec get_enriched_token(String.t, String.t) :: String.t
  def get_enriched_token(token, url) do
    headers = [
      "Authorization": "Bearer #{token}",
      "Accept": "Application/json; Charset=utf-8"
    ]
    options = [
      ssl: [{:versions, [:'tlsv1.2']}],
      recv_timeout: @recv_timeout
    ]

    timed("timed.sessionService-get", :millisecond) do
      case HTTPoison.get(url, headers, options) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          {:ok, body}

        {:ok, %HTTPoison.Response{status_code: code, body: body}} when code >= 400 and code <= 499 ->
          {:error, code, body}
          
        {:error, %HTTPoison.Error{reason: reason}} ->
           {:error, 500, reason}

        unexpected ->
           {:error, 500, "Unexpected response from #{url}: #{inspect(unexpected)}"}
      end
    end
  end

  @spec result_with_new_token(Map.t, Map.t, String.t) :: Tuple.t
  def result_with_new_token(req, env, token) do
    new_req = %{
      req | headers: Map.put(req[:headers], "authorization", "Bearer #{token}")
    }
    {:ok, new_req, env}
  end

  @doc """
    Consume a bearer token, validate it, and then either
    reject it or pass it on to a session service to be
    enriched.
  """
  def handle_bearer_token(req, env, token, url) do
    result = with :ok <- validate_api_token(token),
      {:ok, enriched} <- get_enriched_token(token, url),
      do: result_with_new_token(req, env, enriched)

    case result do
      {:ok, _, _} -> # Just pass on the result
        result

      {:error, code, error} ->
        Logger.error("Session-service error: #{error}")
        @http_server.reply(code, %{}, error, req)
        {:stop, req, env}

      unexpected -> # Otherwise we blow up the request
        Logger.error "Session-service unexpected response: #{inspect(unexpected)}"
        error_reply(req, 401, "Bad Authentication Token")
        {:stop, req, env}
    end
  end

  defp error_reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: message}
    )
    @http_server.reply(code, %{}, msg, req)
  end
end
