defmodule SpacesuitProxyHandlerTest do
  use ExUnit.Case
  doctest Spacesuit.ProxyHandler

  test "extracting the peer address from the request" do
    req = %{ peer: {{127,0,0,1},32767} }

    assert Spacesuit.ProxyHandler.extract_peer(req) == "127.0.0.1"
  end

  test "converting headers to Cowboy format" do
    headers = [
      {"cookie", "some-cookie-data"},
      {"Date", "Sun, 18 Dec 2016 12:12:02 GMT"},
      {"Host", "localhost"}
    ]

    processed = Spacesuit.ProxyHandler.hackney_to_cowboy(headers)

    assert "localhost" = Dict.get(processed, "Host")
    assert "not-found" = Dict.get(processed, "Date", "not-found")
    assert "some-cookie-data" = Dict.get(processed, "cookie", "empty") 
  end

  test "converting headers to Hackney format" do
    headers = %{
      "user-agent" => " Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:50.0) Gecko/20100101 Firefox/50.0",
      "accept-language" => "en-US,en;q=0.5",
      "Host" => " localhost:9090"
    }

    req = %{ peer: {{127,0,0,1},32767} }
    processed = Spacesuit.ProxyHandler.cowboy_to_hackney(headers, req)

    assert {"X-Forwarded-For", "127.0.0.1"} =
      List.keyfind(processed, "X-Forwarded-For", 0)

    assert {"accept-language", "en-US,en;q=0.5"} =
      List.keyfind(processed, "accept-language", 0)

    assert nil == List.keyfind(processed, "Host", 0)
  end

  test "building the upstream url when destination is set and no bindings exist" do
    url = Spacesuit.ProxyHandler.build_upstream_url(
      [destination: "the moon", map: %{}], []
    )

    assert ^url = "the moon"
  end
end
