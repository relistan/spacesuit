defmodule Spacesuit.ProxyHandler do
  require Logger

  # Callback from the Cowboy handler
  def init(req, state) do
    route_name = Dict.get(state, :name, "un-named")
    Logger.info "Processing '#{route_name}'"

    %{ bindings: bindings } = req

    ups_url = build_upstream_url(state, bindings)
    method = Map.get(req, :method) |> String.downcase
    ups_headers = Map.get(req, :headers) |> cowboy_to_hackney(req)

    case request_upstream(method, ups_url, ups_headers, req, []) do
      {:ok, status, headers, upstream} ->
        down_headers = headers |> hackney_to_cowboy
        # This always does a chunked reply, which is a shame because we
        # usually have the content-length. TODO figure this out.
        downstream = :cowboy_req.stream_reply(status, down_headers, req)
        stream(upstream, downstream)
      {:error, :econnrefused} ->
        :cowboy_req.reply(502, %{}, "Bad Gateway - Connection refused", req)
      {:error, :closed} ->
        :cowboy_req.reply(502, %{}, "Bad Gateway - Connection closed", req)
    end
    
    {:ok, req, state}
  end

  # Run the route builder to generate the correct upstream URL
  defp build_upstream_url(state, bindings) do
    case bindings do
      [] ->
        Dict.get(state, :destination)
      _ ->
        Spacesuit.Router.build(state, bindings)
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

  # Find the peer from the request and format it into a string
  # we can pass in the X-Forwarded-For header.
  def extract_peer(req) do
    {:ok, {ip, _port}} = Map.fetch(req, :peer)

    ip
      |> Tuple.to_list
      |> Enum.map(&(Integer.to_string(&1)))
      |> Enum.join(".")
  end

  # Convery headers from Cowboy map format to Hackney list format
  def cowboy_to_hackney(headers, req) do
    peer = extract_peer(req)

    (headers || %{})
      |> Map.put("X-Forwarded-For", peer)
      |> Map.drop([ "host", "Host" ])
      #|> Map.put("user-agent", "Spacesuit 0.1.0")
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
        IO.puts "Error! #{reason}"
      _ ->
        IO.puts "Unexpected non-match in stream/2!"
    end
  end

  def terminate(_reason, _downstream, _state), do: :ok
end
