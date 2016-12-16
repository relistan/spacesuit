defmodule Spacesuit.ProxyHandler do

  #@upstream_url "http://localhost:9090/"

  def init(incoming, state) do
    # :cowboy_req.binding/2 can fetch bindings from routing URL
    [{:destination, upstream_url}] = state

    method = Map.get(incoming, :method) |> String.downcase
    ups_headers = Map.get(incoming, :headers) |> cowboy_to_hackney(incoming)

    case request_upstream(method, upstream_url, ups_headers, incoming, []) do
      {:ok, status, headers, upstream} ->
        down_headers = headers |> hackney_to_cowboy
        # This always does a chunked reply, which is a shame because we
        # usually have the content-length. TODO figure this out.
        downstream = :cowboy_req.stream_reply(status, down_headers, incoming)
        stream(upstream, downstream)
      {:error, :econnrefused} ->
        :cowboy_req.reply(502, %{}, "Bad Gateway - Connection refused", incoming)
      {:error, :closed} ->
        :cowboy_req.reply(502, %{}, "Bad Gateway - Connection closed", incoming)
    end
    
    {:ok, incoming, state}
  end

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
  defp hackney_to_cowboy(headers) do
    headers 
      |> List.foldl(%{}, fn({k,v}, memo) -> Map.put(memo, k, v) end)
      |> Map.drop([ "Date", "date", "Content-Length", "content-length",
          "Transfer-Encoding", "transfer-encoding" ])
  end

  # Find the peer from the request and format it into a string
  # we can pass in the X-Forwarded-For header.
  defp extract_peer(req) do
    {:ok, {ip, _port}} = Map.fetch(req, :peer)

    ip
      |> Tuple.to_list
      |> Enum.map(&(Integer.to_string(&1)))
      |> Enum.join(".")
  end

  # Convery headers from Cowboy map format to Hackney list format
  defp cowboy_to_hackney(headers, req) do
    peer = extract_peer(req)

    (headers || %{})
      |> Map.put("X-Forwarded-For", peer)
      |> Map.drop([ "host", "Host" ])
      #|> Map.put("user-agent", "Spacesuit 0.1.0")
      |> Map.to_list
  end

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

# %{bindings: [], body_length: 0, has_body: false,
#   headers: %{"accept" => "*/*", "host" => "localhost:8080",
#     "user-agent" => "curl/7.43.0"}, host: "localhost", host_info: :undefined,
#   method: "GET", path: "/", path_info: :undefined,
#   peer: {{127, 0, 0, 1}, 55777}, pid: #PID<0.292.0>, port: 8080, qs: "",
#   ref: :http, scheme: "http", streamid: 1, version: :"HTTP/1.1"}
