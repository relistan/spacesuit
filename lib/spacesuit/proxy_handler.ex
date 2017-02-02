defmodule Spacesuit.ProxyHandler do
  require Logger

  # Callback from the Cowboy handler
  def init(req, state) do
    route_name = Map.get(state, :description, "un-named")
    Logger.info "Processing '#{route_name}'"

    %{ bindings: bindings, method: method, headers: headers, peer: peer } = req

    # Prepare some things we'll need
    ups_url     = build_upstream_url(method, state, bindings)
    peer        = format_peer(peer)
    ups_headers = cowboy_to_hackney(headers, peer)

    # Make the proxy request
    handle_request(req, ups_url, ups_headers, method)
    
    {:ok, req, state}
  end

  defp handle_request(req, ups_url, ups_headers, method) do
    case request_upstream(method, ups_url, ups_headers, req, []) do
      {:ok, status, headers, upstream} ->
        down_headers = headers |> hackney_to_cowboy
        # This always does a chunked reply, which is a shame because we
        # usually have the content-length. TODO figure this out.
        downstream = :cowboy_req.stream_reply(status, down_headers, req)
        stream(upstream, downstream)

      {:error, :econnrefused} ->
        error_reply(req, 503, "Service Unavailable - Connection refused")

      {:error, :closed} ->
        error_reply(req, 502, "Bad Gateway - Connection closed")

      {:error, :timeout} ->
        error_reply(req, 502, "Bad Gateway - Connection timeout")

      {:error, :bad_request} ->
        error_reply(req, 400, "Bad Request")

      unexpected ->
        Logger.warn "Received unexpected upstream response: '#{inspect(unexpected)}'"
    end
  end

  # Run the route builder to generate the correct upstream URL based
  # on the bindings and the request method/http verb.
  def build_upstream_url(method, state, bindings) do
    case bindings do
      [] ->
        state[:destination]
      _ ->
        Spacesuit.Router.build(method, state, bindings)
    end
  end

  # Make the request to the destination using Hackney
  defp request_upstream(method, url, ups_headers, downstream, _) do
    case Map.fetch(downstream, :has_body) do
      {:ok, true}  ->
        # This reads the whole incoming body into RAM. TODO see if we can not do that.
        :hackney.request(method, url, ups_headers, Map.fetch(downstream, :body), [])
      {:ok, false} ->
        :hackney.request(method, url, ups_headers, [], [])
    end
  end

  # Convert headers from Hackney list format to Cowboy map format.
  # Drops some headers we don't want to pass through.
  def hackney_to_cowboy(headers) do
    headers 
      |> List.foldl(%{}, fn({k,v}, memo) -> Map.put(memo, k, v) end)
      |> Map.drop([ "Date", "date", "Content-Length", "content-length",
          "Transfer-Encoding", "transfer-encoding" ])
  end

  # Format the peer from the request into a string that
  # we can pass in the X-Forwarded-For header.
  def format_peer(peer) do
    {ip, _port} = peer

    ip
      |> Tuple.to_list
      |> Enum.map(&(Integer.to_string(&1)))
      |> Enum.join(".")
  end

  # Convery headers from Cowboy map format to Hackney list format
  def cowboy_to_hackney(headers, peer) do
    (headers || %{})
      |> Map.put("X-Forwarded-For", peer)
      |> Map.drop([ "host", "Host" ])
      |> Map.to_list
  end

  # Copy data from one connection to the other until there is no more
  defp stream(upstream, downstream) do
    case :hackney.stream_body(upstream) do
      {:ok, data} ->
        :ok = :cowboy_req.stream_body(data, :nofin, downstream)
        stream(upstream, downstream)
      :done -> 
        :ok = :cowboy_req.stream_body(<<>>, :fin, downstream)
        :ok
      {:error, reason} ->
        Logger.error "Error in stream/2: #{reason}"
      _ ->
        Logger.error "Unexpected non-match in stream/2!"
    end
  end

  # Send messages back to Cowboy, encoded in the format used
  # by the API
  def error_reply(req, code, message) do
    msg = Spacesuit.ApiMessage.encode(
      %Spacesuit.ApiMessage{status: "error", message: message}
    )
    :cowboy_req.reply(code, %{}, msg, req)
  end

  def terminate(_reason, _downstream, _state), do: :ok
end
