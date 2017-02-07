defmodule HttpServer do
  @callback stream_reply(Integer.t, List.t, Map.t) :: any
  @callback stream_body(String.t, Integer.t, any) :: any
  @callback reply(Integer.t, List.t, Atom.t, any) :: any
end

defmodule Spacesuit.HttpServer.Cowboy do
  @behaviour HttpServer

  def stream_reply(status, down_headers, req) do
    :cowboy_req.stream_reply(status, down_headers, req)
  end

  def stream_body(data, status, downstream) do
    :cowboy_req.stream_body(data, status, downstream)
  end

  def reply(code, headers, msg, req) do
    :cowboy_req.reply(code, headers, msg, req)
  end
end

defmodule Spacesuit.HttpServer.Mock do
  @behaviour HttpServer

  def stream_reply(_status, _down_headers, _req) do
    :ok
  end

  def stream_body(_data, _status, _downstream) do
    :ok
  end

  def reply(_code, _headers, _msg, _req) do
    :ok
  end
end
