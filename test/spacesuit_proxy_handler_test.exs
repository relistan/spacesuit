defmodule SpacesuitProxyHandlerTest do
  use ExUnit.Case
  doctest Spacesuit.ProxyHandler

  test "formatting the peer address from the request" do
    peer = {{127,0,0,1},32767}

    assert Spacesuit.ProxyHandler.format_peer(peer) == "127.0.0.1"
  end

  test "converting headers to Cowboy format" do
    headers = [
      {"cookie", "some-cookie-data"},
      {"Date", "Sun, 18 Dec 2016 12:12:02 GMT"},
      {"Host", "localhost"}
    ]

    processed = Spacesuit.ProxyHandler.hackney_to_cowboy(headers)

    assert "localhost" = Map.get(processed, "Host")
    assert "not-found" = Map.get(processed, "Date", "not-found")
    assert "some-cookie-data" = Map.get(processed, "cookie", "empty") 
  end

  test "converting headers to Hackney format" do
    headers = %{
      "user-agent" => Enum.join([
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:50.0) ",
        "Gecko/20100101 Firefox/50.0"
      ], ""),
      "accept-language" => "en-US,en;q=0.5",
      "Host" => " localhost:9090"
    }

    peer = Spacesuit.ProxyHandler.format_peer({{127,0,0,1},32767})
    processed = Spacesuit.ProxyHandler.cowboy_to_hackney(headers, peer)

    assert {"X-Forwarded-For", "127.0.0.1"} =
      List.keyfind(processed, "X-Forwarded-For", 0)

    assert {"accept-language", "en-US,en;q=0.5"} =
      List.keyfind(processed, "accept-language", 0)

    assert nil == List.keyfind(processed, "Host", 0)
  end

  test "building the upstream url when destination is set and no bindings exist" do
    req = %{ bindings: [], method: "GET", qs: "", path_info: [] }
    url = Spacesuit.ProxyHandler.build_upstream_url(
      req, %{destination: "the moon", map: %{}}
    )

    assert ^url = "the moon"
  end

  test "building the upstream url when bindings exist" do
    route_map = Spacesuit.Router.compile(:GET, "http://elsewhere.example.com/:asdf")

    req = %{ bindings: [asdf: "foo"], method: "GET", qs: "", path_info: [] }
    url = Spacesuit.ProxyHandler.build_upstream_url(req, route_map)
    
    assert ^url = "http://elsewhere.example.com/foo"
  end

  test "building the upstream url when there is a query string" do
    route_map = Spacesuit.Router.compile(:GET, "http://elsewhere.example.com/:asdf")

    req = %{
      bindings: [asdf: "foo"], method: "GET",
      qs: "shakespeare=literature", path_info: []
    }
    url = Spacesuit.ProxyHandler.build_upstream_url(req, route_map)

    assert ^url = "http://elsewhere.example.com/foo?shakespeare=literature"
  end

  test "request_upstream passes the body when there is one" do
    result = Spacesuit.ProxyHandler.request_upstream(
      "get", "http://example.com",
      [{"Content-Type", "html"}], %{has_body: true, body: "test body"}
    )

    assert {:ok, true} = result
  end

  test "request_upstream skips the body when there isn't one" do
    result = Spacesuit.ProxyHandler.request_upstream(
      "get", "http://example.com",
      [{"Content-Type", "html"}], %{has_body: false}
    )

    assert {:ok, false} = result
  end

  test "stream calls complete properly" do
    assert :ok = Spacesuit.ProxyHandler.stream(:done, nil)
  end

  test "stream calls handle errors" do
    assert :ok = Spacesuit.ProxyHandler.stream(:error, nil)
  end

  test "stream recurses" do
    assert :ok =  Spacesuit.ProxyHandler.stream(nil, nil)
  end
end
