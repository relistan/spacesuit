defmodule Spacesuit.CorsMiddleware do
  require Logger
  use Elixometer

  @http_server                    Application.get_env(:spacesuit, :http_server)
  @cors                           Application.get_env(:spacesuit, :cors)
  @supported_http_methods         [:GET, :POST, :PUT, :PATCH, :DELETE, :HEAD, :OPTIONS]
  @access_control_request_headers Enum.map(@cors[:access_control_request_headers] || [], fn(s) -> String.downcase(s) end)
                                  |> Enum.into(MapSet.new)

  @timed(key: "timed.corsMiddleware-execute", units: :millisecond)
  def execute(req, env) do
    result = with :ok          <- verify_enabled(),
         :ok                   <- validate_path(req),
         {:ok, origin, method} <- parse_cors_request(req),
         {:ok, headers}        <- get_cors_headers(origin, method, req) do
      {:ok, @http_server.set_resp_headers(headers, req), env}
    else
      {:ok, headers, :OPTIONS} ->
        with_resp_headers = @http_server.set_resp_headers(headers, req)
        @http_server.reply(200, with_resp_headers, req)
        {:stop, with_resp_headers}
      :skip ->
        Logger.debug "no CORS headers set for #{req[:method]} #{req[:path]}"
        {:ok, req, env}
      {:error, :invalid_cors_request} ->
        headers = req[:headers]
        Logger.warn "Invalid CORS request;Origin=#{headers["origin"]};Method=#{req[:method]};ACCESS_CONTROL_REQUEST_HEADERS=#{headers["access_control_request_headers"]}"
        msg = Spacesuit.ApiMessage.encode(
          %Spacesuit.ApiMessage{status: "error", message: "Invalid CORS request"}
        )
        @http_server.reply(403, %{}, msg, req)
        {:stop, req}
    end
    result
  end

  defp verify_enabled() do
    if @cors[:enabled] do
      :ok
    else
      :skip
    end
  end

  defp validate_path(req) do
    path_prefixes = @cors[:path_prefixes] || ["/"]
    path = req[:path]
    if Enum.any?(path_prefixes, fn(p) -> String.starts_with?(path, p) end) do
      :ok
    else
      :skip
    end
  end

  defp parse_cors_request(req) do
    origin = req[:headers]["origin"]
    if !serve_from_origin?(origin) do
      if is_nil(origin) || @cors[:serve_forbidden_origins] do
        :skip
      else
        {:error, :invalid_cors_request}
      end
    else
      if is_same_origin?(origin, req) do
        :skip
      else
        {:ok, origin, String.to_atom(req[:method])}
      end
    end
  end

  defp verify_access_control_request_headers(req) do
    case String.split(req[:headers]["Access-Control-Request-Headers"] || "", ",") do
      [""]    -> {:ok, %{}}
      headers ->
        accessControlRequestHeaders =
          Enum.map(headers, fn(s) -> s |> String.downcase |> String.trim end)
          |> Enum.into(MapSet.new)

        if MapSet.subset?(accessControlRequestHeaders, @access_control_request_headers) do
          {:ok, %{"Access-Control-Allow-Headers" => Enum.join(accessControlRequestHeaders, ",")}}
        else
          :error
        end
    end
  end

  defp get_cors_headers(origin, method, req) do
    case method do
      :OPTIONS ->
        result = with {:ok, allowHeaders} <- verify_access_control_request_headers(req) do
          method = String.to_atom(req[:headers]["Access-Control-Request-Method"]) || ""
          if !is_supported_http_method?(method) or !is_allowed_http_method?(method) do
            {:error, :invalid_cors_request}
          else
            headers =
              allowHeaders
              |> Map.merge(origin_headers(origin))
              |> Map.merge(preflight_header())
              |> Map.put("Access-Control-Allow-Methods", Atom.to_string(method))
            {:ok, headers, :OPTIONS}
          end
        else
          :error -> {:error, :invalid_cors_request}
        end
        result
      _ ->
        if is_supported_http_method? method do
          {:ok, origin_headers(origin)}
        else
          {:error, :invalid_cors_request}
        end
    end
  end

  @spec origin_headers(String.t) :: Map.t
  defp origin_headers(origin) do
    if @cors[:any_origin_allowed] do
      %{"Access-Control-Allow-Origin" => "*"}
    else
      %{
        "Access-Control-Allow-Origin" => origin,
        "Vary" => "Origin"
      }
    end
  end

  @spec preflight_header() :: Map.t
  defp preflight_header() do
    max_age = @cors[:preflight_max_age]
    if is_nil(max_age) or max_age < 0 do
      %{}
    else
      %{"Access-Control-Max-Age" => max_age}
    end
  end

  @spec serve_from_origin?(String.t) :: boolean
  defp serve_from_origin?(origin) do
    case String.split(origin || "", "%") do
      [""]        -> false
      [_, _]      -> false
      [candidate] -> !is_nil(URI.parse(candidate).scheme) && is_allowed_origin?(candidate)
    end
  end

  @spec is_same_origin?(String.t, Req.t) :: boolean
  defp is_same_origin?(origin, req) do
    hostUri = origin |> String.downcase |> URI.parse
    originUri = "#{req[:scheme]}://#{req[:host]}:#{req[:port]}" |> URI.parse
    {hostUri.scheme, hostUri.host, hostUri.port} == {originUri.scheme, originUri.host, originUri.port}
  end

  @spec is_allowed_origin?(String.t) :: boolean
  defp is_allowed_origin?(origin) do
    allowed_origins = @cors[:allowed_origins]
    is_nil(allowed_origins) || Enum.member? allowed_origins, origin
  end

  @spec is_supported_http_method?(atom) :: boolean
  defp is_supported_http_method?(method) do
    Enum.member? @supported_http_methods, method
  end

  @spec is_allowed_http_method?(String.t) :: boolean
  defp is_allowed_http_method?(method) do
    allowed_http_methods = @cors[:allowed_http_methods]
    is_nil(allowed_http_methods) || Enum.member? allowed_http_methods, method
  end
end
