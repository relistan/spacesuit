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
      "user-agent" => " Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:50.0) Gecko/20100101 Firefox/50.0",
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
    url = Spacesuit.ProxyHandler.build_upstream_url(
      "GET", [destination: "the moon", map: %{}], []
    )

    assert ^url = "the moon"
  end

  test "building the upstream url when bindings exist" do
    route_map = Spacesuit.Router.compile(:GET, "http://elsewhere.example.com/:asdf")

    url = Spacesuit.ProxyHandler.build_upstream_url(
      "GET", route_map, [asdf: "foo"]
    )
    
    assert ^url = "http://elsewhere.example.com/foo"
  end
end
