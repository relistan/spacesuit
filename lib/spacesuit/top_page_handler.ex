defmodule Spacesuit.TopPageHandler do

  #@upstream_url "http://localhost:9090/"
  @upstream_url "https://news.ycombinator.com/"

  def init(incoming, state) do
    method = Map.get(incoming, :method) |> String.downcase
    ups_headers = cowboy_to_hackney(Map.get(incoming, :headers))

    case request_upstream(method, @upstream_url, ups_headers, incoming, []) do
      {:ok, status, headers, upstream} ->
        down_headers = hackney_to_cowboy(headers)
        # This always does a chunked reply, which is a shame because we
        # usually have the content-length. TODO figure this out.
        downstream = :cowboy_req.stream_reply(status, down_headers, incoming)
        stream(downstream, upstream)
      {:error, :econnrefused} ->
        :cowboy_req.reply(502, %{}, "Bad Gateway", incoming)
    end
    
    {:ok, incoming, state}
  end

  defp request_upstream(method, url, ups_headers, incoming, _) do
    case Map.fetch(incoming, :has_body) do
      {:ok, true}  ->
        :hackney.request(method, url, ups_headers, Map.fetch(incoming, :body), [])
      {:ok, false} ->
        :hackney.request(method, url, ups_headers, [], [])
    end
  end

  # Convert headers from Hackney list format to Cowboy map format
  defp hackney_to_cowboy(headers) do
    List.foldl(headers, %{}, fn({k,v}, memo) -> Map.put(memo, k, v) end)
  end

  # Convery headers from Cowboy map format to Hackney list format
  defp cowboy_to_hackney(headers) do
    if headers == nil do
      []
    else
      Map.delete(headers, :host) 
        #|> Map.put("user-agent", "Spacesuit 0.1.0")
        |> Map.to_list
    end
  end

  defp stream(incoming, upstream) do
    case :hackney.stream_body(upstream) do
      {:ok, data} ->
        :ok = :cowboy_req.stream_body(data, :nofin, incoming)
        stream(incoming, upstream)
      :done -> 
        :ok = :cowboy_req.stream_body(<<>>, :fin, incoming)
        :ok
      {:error, reason} ->
        IO.puts "Error! #{reason}"
    end
  end

  def terminate(_reason, _incoming, _state), do: :ok
end

# %{bindings: [], body_length: 0, has_body: false,
#   headers: %{"accept" => "*/*", "host" => "localhost:8080",
#     "user-agent" => "curl/7.43.0"}, host: "localhost", host_info: :undefined,
#   method: "GET", path: "/", path_info: :undefined,
#   peer: {{127, 0, 0, 1}, 55777}, pid: #PID<0.292.0>, port: 8080, qs: "",
#   ref: :http, scheme: "http", streamid: 1, version: :"HTTP/1.1"}
