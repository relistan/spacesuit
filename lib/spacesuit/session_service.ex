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
  @moduledoc """
    Mock session service used in testing the AuthHandler
  """

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
      "error" -> {:stop, req}
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
    Consume a bearer token, validate it, and then either
    reject it or pass it on to a session service to be
    enriched.
  """
  def handle_bearer_token(req, env, token, url) do
  result = with :ok   <- validate_api_token(token),
      {:ok, enriched} <- get_enriched_token(token, url),
      {:ok, parsed}   <- parse_response_body(enriched),
      do: result_with_new_token(req, env, parsed)

    case result do
      {:ok, _, _} -> # Just pass on the result
        result

      {:error, type, code, error} ->
        Logger.error "Session-service #{inspect(type)} error: #{inspect(error)}"
        if is_binary(error) do
          @http_server.reply(code, %{}, error, req)
        else
          error_reply(req, 503, "Upstream error")
        end
        {:stop, req}

      {:error, type, error} ->
        Logger.error "Session-service #{inspect(type)} error: #{inspect(error)}"
        error_reply(req, 401, "Bad Authentication Token")
        {:stop, req}

      unexpected -> # Otherwise we blow up the request
        Logger.error "Session-service error: unexpected response - #{inspect(unexpected)}"
        error_reply(req, 401, "Bad Authentication Token")
        {:stop, req}
    end
  end

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
      error ->   {:error, :validation, error}
    end
  end

  @doc """
    Exchange the token for an enriched token from the Session service. This
    expects the body of the response to be the new token. The current token
    is passed in the Authorization header as a bearer token.
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
          {:error, :http, code, body}
          
        {:error, %HTTPoison.Error{reason: reason}} ->
           {:error, :http, 500, reason}

        unexpected ->
           {:error, :http, 500, "Unexpected response from #{url}: #{inspect(unexpected)}"}
      end
    end
  end

  @spec parse_response_body(String.t) :: Tuple.t
  def parse_response_body(body) do
    Logger.debug "Parsing response: #{inspect(body)}"
    case Poison.decode(body) do
      {:ok, data} -> Map.fetch(data, "data")
      {:error, :parser, error} -> {:error, :parsing, error}
    end
  end

  @spec result_with_new_token(Map.t, Map.t, String.t) :: Tuple.t
  def result_with_new_token(req, env, token) do
    new_req = %{
      req | headers: Map.put(req[:headers], "authorization", "Bearer #{token}")
    }
    {:ok, new_req, env}
  end

  @spec error_reply(Map.t, String.t, String.t) :: nil
  defp error_reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: message}
    )
    @http_server.reply(code, %{}, msg, req)
  end
end
