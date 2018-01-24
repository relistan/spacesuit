defmodule HttpServer do
  @callback stream_reply(Integer.t(), List.t(), Map.t()) :: any
  @callback stream_body(String.t(), Integer.t(), any) :: any
  @callback reply(Integer.t(), List.t(), Atom.t(), any) :: any
  @callback has_body(Map.t()) :: Boolean.t()
  @callback read_body(Map.t()) :: any
  @callback body_length(Map.t()) :: Integer.t()
  @callback uri(Map.t()) :: String.t()
  @callback set_resp_headers(Map.t(), Map.t()) :: any
end

defmodule Spacesuit.HttpServer.Cowboy do
  @behaviour HttpServer

  def stream_reply(status, down_headers, req) do
    :cowboy_req.stream_reply(status, down_headers, req)
  end

  def stream_body(data, status, downstream) do
    :cowboy_req.stream_body(data, status, downstream)
  end

  def reply(code, headers, req) do
    :cowboy_req.reply(code, headers, req)
  end

  def reply(code, headers, msg, req) do
    :cowboy_req.reply(code, headers, msg, req)
  end

  def has_body(req) do
    :cowboy_req.has_body(req)
  end

  def read_body(req) do
    :cowboy_req.read_body(req)
  end

  def body_length(req) do
    :cowboy_req.body_length(req)
  end

  def uri(req) do
    :cowboy_req.uri(req)
  end

  def set_resp_headers(headers, req) do
    :cowboy_req.set_resp_headers(headers, req)
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

  def reply(_code, _headers, _req) do
    :ok
  end

  def reply(_code, _headers, _msg, _req) do
    :ok
  end

  def has_body(req) do
    req[:body] != nil
  end

  def read_body(req) do
    # Simulate a success request and return the body if we passed one in
    {:ok, req[:body], req}
  end

  def body_length(req) do
    String.length(req[:body] || "")
  end

  def uri(req) do
    req[:url]
  end

  def set_resp_headers(headers, req) do
    {_, with_resp_headers} =
      Map.get_and_update(req, :resp_headers, fn h -> {h, Map.merge(h || %{}, headers)} end)

    with_resp_headers
  end
end
