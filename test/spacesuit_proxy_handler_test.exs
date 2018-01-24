defmodule SpacesuitProxyHandlerTest do
  use ExUnit.Case
  doctest Spacesuit.ProxyHandler

  test "formatting the peer address from the request" do
    peer = {{127,0,0,1},32767}

    assert Spacesuit.ProxyHandler.format_peer(peer) == "127.0.0.1"
  end

  describe "converting headers to Cowboy format" do
    test "converts headers to a map" do
      headers = [
        {"cookie", "some-cookie-data"},
        {"Date", "Sun, 18 Dec 2016 12:12:02 GMT"},
        {"Host", "localhost"}
      ]

      processed = Spacesuit.ProxyHandler.hackney_to_cowboy(headers)
      assert "localhost" = Map.get(processed, "host")
      assert "not-found" = Map.get(processed, "date", "not-found")
      assert "some-cookie-data" = Map.get(processed, "cookie", "empty") 
    end

    test "downcases all the response headers" do
      headers = [
        {"cookie", "some-cookie-data"},
        {"Date", "Sun, 18 Dec 2016 12:12:02 GMT"},
        {"Host", "localhost"}
      ]

      processed = Spacesuit.ProxyHandler.hackney_to_cowboy(headers)
      assert Enum.all?(Map.keys(processed), fn k -> k == String.downcase(k) end)
    end
  end

  test "adding headers specified in the config" do
    headers = %{
      "user-agent" => Enum.join([
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:50.0) ",
        "Gecko/20100101 Firefox/50.0"
      ], ""),
      "accept-language" => "en-US,en;q=0.5",
      "Host" => " localhost:9090"
    }
    added_headers = %{ "Add-One" => "1", "Add-Two" => "2"}
    all_headers = Spacesuit.ProxyHandler.add_headers_to(headers, added_headers)

    assert all_headers["Add-One"] == "1"
    assert all_headers["Add-Two"] == "2"
  end

  test "doesn't crash on nil added_headeres" do
    result = Spacesuit.ProxyHandler.add_headers_to(%{}, nil)

    assert %{} == result
  end

  test "converting headers to Hackney format and adding proxy info" do
    headers = %{
      "user-agent" => Enum.join([
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:50.0) ",
        "Gecko/20100101 Firefox/50.0"
      ], ""),
      "accept-language" => "en-US,en;q=0.5",
      "Host" => " localhost:9090",
      "x-forwarded-for" => "example.com"
    }

    peer = Spacesuit.ProxyHandler.format_peer({{127,0,0,1},32767})
    # Cowboy sends the URL through in this format
    original_url = [[["http", 58], "//", "localhost", [58, "8080"]], "/v1/people/123/things", "", ""]
    processed = Spacesuit.ProxyHandler.cowboy_to_hackney(headers, peer, original_url)

    assert {"x-forwarded-for", "example.com, 127.0.0.1"} =
      List.keyfind(processed, "x-forwarded-for", 0)

    assert {"accept-language", "en-US,en;q=0.5"} =
      List.keyfind(processed, "accept-language", 0)

    assert {"x-forwarded-url", ^original_url} =
      List.keyfind(processed, "x-forwarded-url", 0)

    assert {"x-forwarded-host", "localhost"} =
      List.keyfind(processed, "x-forwarded-host", 0)

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
    uri_str = "http://elsewhere.example.com/:asdf"

    route_map = %{ GET: Spacesuit.Router.compile(uri_str) }

    req = %{ bindings: [asdf: "foo"], method: "GET", qs: "", path_info: [] }
    url = Spacesuit.ProxyHandler.build_upstream_url(req, route_map)
    
    assert ^url = "http://elsewhere.example.com/foo"
  end

  test "building the upstream url when there is a query string" do
    uri_str = "http://elsewhere.example.com/:asdf"
    route_map = %{ GET: Spacesuit.Router.compile(uri_str) }

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
