defmodule Spacesuit.CorsMiddleware do
  @moduledoc """
    Handles CORS requests for backing services. If the incoming request is
    properly formed and is an OPTIONS request, then we'll serve the response
    directly without further upstream processing. For all other requests,
    we try validate a number of features and determine first if it's a valid
    request at all, and then if we should process it. If we do, we add
    appropriate response headers and send on for upstream processing.
  """

  require Logger
  use Elixometer

  @http_server                    Application.get_env(:spacesuit, :http_server)
  @supported_http_methods         [:GET, :POST, :PUT, :PATCH, :DELETE, :HEAD, :OPTIONS]

  @timed(key: "timed.corsMiddleware-execute", units: :millisecond)
  def execute(req, env) do
    with {true, :enabled?}      <- enabled?(),
         {true, :handled_path?} <- handled_path?(req[:path]),
         {:ok, origin, method}  <- valid_cors_request?(req),
         {:ok, headers}         <- process_cors(origin, method, req) do
      handle_success(req, env, headers)
    else
      # The whole middleware is disabled
      {false, :enabled?} ->
        Logger.debug "CORS middleware disabled, skipping"
        {:ok, req, env}

      {false, :handled_path?} ->
        Logger.debug "No CORS headers set for #{req[:method]} #{req[:path]}"
        {:ok, req, env}

      # OPTIONS request, we handle these ourselves. So short-circuit
      # downstream response and send 200
      {:ok, headers, :handle_ourselves} ->
        with_resp_headers = @http_server.set_resp_headers(headers, req)
        @http_server.reply(200, headers, with_resp_headers)
        {:stop, with_resp_headers}

      # There were no CORS headers, continue processing
      {:ok, {:skip, :valid_cors_request?}} ->
        Logger.debug "No CORS headers set for #{req[:method]} #{req[:path]}"
        {:ok, req, env}

      # There were CORS headers, but they are invalid or malformed
      {:error, :invalid, :valid_cors_request?} ->
        handle_error(req, env)

      # We got a method that we don't allow processing CORS for
      {:error, :unsupported, :process_cors} ->
        handle_error(req, env)

      # It was an OPTIONS request but with invalid headers
      {:error, :invalid_options, :process_cors} ->
        handle_error(req, env)
    end
  end

  # Quick access function for the application settings for this middleware
  def cors do
    Application.get_env(:spacesuit, :cors) || %{}
  end

  # We processed CORS headers and we pass on upstream to other middlewares.
  defp handle_success(req, env, headers) do
    {:ok, @http_server.set_resp_headers(headers, req), env}
  end

  # Something was wrong with the request and we have to stop the processing
  # by all other middlewares.
  defp handle_error(req, _env) do
    origin = req[:headers]["origin"]
    Logger.warn("""
      Invalid CORS request:
        Origin=#{origin}
        Method=#{req[:method]}
        ACCESS_CONTROL_REQUEST_HEADERS=#{req[:headers]["access_control_request_headers"]}
    """ |> String.replace("  ", ""))

    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: "Invalid CORS request"}
    )

    @http_server.reply(403, %{}, msg, req)
    {:stop, req}
  end

  # Do we even have the middleware enabled?
  defp enabled? do
    enabled = Map.get(cors(), :enabled, false)
    {enabled, :enabled?}
  end

  # Is the path something we can send a CORS response for?
  defp handled_path?(path) do
    path_prefixes = (cors()[:path_prefixes] || ["/"])
    result = Enum.any?(path_prefixes, fn(p) -> String.starts_with?(path, p) end)
    {result, :handled_path?}
  end

  # Is this request something we can handle?
  defp valid_cors_request?(req) do
    origin = req[:headers]["origin"]

    cond do
      is_nil(origin) || same_origin?(origin, req) ->
        {:ok, {:skip, :valid_cors_request?}}

      serve_from_origin?(origin) ->
        {:ok, origin, String.to_atom(req[:method])}

      true -> # Default case
        {:error, :invalid, :valid_cors_request?}
    end
  end

  # Do we have headers we're allowed to process?
  def verify_allowed_http_headers(req) do
    # Access control request headers come jammed into a single string
    acr_headers = (req[:headers]["access-control-request-headers"] || "")
    |> String.split(",")
    |> Enum.map(&String.downcase/1)
    |> Enum.map(&String.trim/1)
    |> Enum.into(MapSet.new)

    empty_mapset = MapSet.new([""])

    case acr_headers do
      ^empty_mapset -> {:ok, %{}}

      headers ->
        if valid_control_headers?(headers) do
          {:ok, %{"Access-Control-Allow-Headers" => Enum.join(headers, ",")}}
        else
          :error
        end
    end
  end

  defp valid_control_headers?(headers) do
    allowed_headers = allowed_http_headers()
    MapSet.size(allowed_headers) == 0 || MapSet.subset?(headers, allowed_headers)
  end

  defp process_cors(origin, method, req) do
    if method == :OPTIONS do
      case handle_options_method(origin, method, req) do
        :error -> {:error, :invalid_options, :process_cors}

        {:ok, headers} -> {:ok, headers, :handle_ourselves}
      end
    else
      if supported_http_method?(method) do
        {:ok, origin_headers(origin)}
      else
        {:error, :unsupported, :process_cors}
      end
    end
  end

  def handle_options_method(origin, method, req) do
    case verify_allowed_http_headers(req) do
      {:ok, allow_headers} ->
        method = String.to_atom(req[:headers]["access-control-request-method"] || "")
        if supported_http_method?(method) && allowed_http_method?(method) do
          headers =
            allow_headers
            |> Map.merge(origin_headers(origin))
            |> Map.merge(preflight_header())
            |> Map.put("Access-Control-Allow-Methods", Atom.to_string(method))

          {:ok, headers}
        else
          :error
        end

      _ ->
        :error

    end
  end

  @spec origin_headers(String.t) :: Map.t
  defp origin_headers(origin) do
    if cors()[:any_origin_allowed] do
      %{
        "Access-Control-Allow-Origin" => "*"
       }
    else
      %{
        "Access-Control-Allow-Origin" => origin,
        "Vary" => "Origin"
      }
    end
  end

  @spec preflight_header() :: Map.t
  defp preflight_header do
    max_age = cors()[:preflight_max_age]
    if is_nil(max_age) || (max_age < 0) do
      %{}
    else
      %{"Access-Control-Max-Age" => max_age}
    end
  end

  @spec serve_from_origin?(String.t) :: boolean
  defp serve_from_origin?(origin) do
    !String.contains?(origin || "", "%") &&
      !is_nil(URI.parse(origin).scheme) &&
      allowed_origin?(origin)
  end

  @spec same_origin?(String.t, Req.t) :: boolean
  defp same_origin?(origin, req) do
    origin_uri = URI.parse(origin)
    {req[:scheme], req[:host], req[:port]} == {origin_uri.scheme, origin_uri.host, origin_uri.port}
  end

  @spec allowed_origin?(String.t) :: boolean
  defp allowed_origin?(origin) do
    allowed_origins = cors()[:allowed_origins]
    is_nil(allowed_origins) || Enum.member?(allowed_origins, origin)
  end

  @spec supported_http_method?(atom) :: boolean
  def supported_http_method?(method) do
    Enum.member?(@supported_http_methods, method)
  end

  @spec allowed_http_method?(String.t) :: boolean
  def allowed_http_method?(method) do
    is_nil(cors()[:allowed_http_methods]) || (
        cors()
        |> Map.get(:allowed_http_methods, [])
        |> Enum.member?(method)
      )
  end

  defp allowed_http_headers do
    (cors()[:allowed_http_headers] || [])
    |> Enum.map(&String.downcase/1)
    |> Enum.into(MapSet.new)
  end

end
