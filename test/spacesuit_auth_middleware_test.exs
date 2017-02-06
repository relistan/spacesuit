defmodule SpacesuitAuthMiddlewareTest do
  use ExUnit.Case
  doctest Spacesuit.AuthMiddleware

  setup_all do
    token = "eyJhbGciOiJIUzM4NCIsInR5cCI6IkpXVCJ9.eyJhY2N0IjoiMSIsImF6cCI6ImthcmwubWF0dGhpYXNAZ29uaXRyby5jb20iLCJkZWxlZ2F0ZSI6IiIsImV4cCI6IjIwMTctMDItMDNUMTU6MDc6MTRaIiwiZmVhdHVyZXMiOlsidGVhbWRvY3MiLCJjb21iaW5lIiwiZXNpZ24iXSwiaWF0IjoiMjAxNy0wMi0wM1QxNDowNzoxNC40MTMyMTg2OTNaIiwianRpIjoiNTU2ZmU1MTgtYTk0Mi00YTQ3LTkyZmMtNWNmNmVkOWY0YWFhIiwicGVybXMiOlsiYWNjb3VudHM6cmVhZCIsImdyb3VwczpyZWFkIiwidXNlcnM6d3JpdGUiXSwic3ViIjoiY3NzcGVyc29uQGdvbml0cm8uY29tIn0.6eWCzu6yHhgzuvUPaNloNl09uUfaN6nqhK1W--TQwtMk29tf5C5SV-hTT2pxnSxe"

    {:ok, token: token}
  end

  test "passes through OK when there is no auth header" do
    assert {:ok, %{}, %{}} = Spacesuit.AuthMiddleware.execute(%{}, %{})   
  end

  test "'authorization' header is stripped when present" do
    req = %{ headers: %{ "authorization" => "sometoken" }}
    env = %{}

    assert {:ok, %{ headers: %{} }, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
  end

  test "recognizes unauthorized access" do
    req = %{ headers: %{ "authorization" => "magic!" }, pid: self(), streamid: 1, method: "GET" }
    env = %{}

    assert {:halt, ^req} = Spacesuit.AuthMiddleware.execute(req, env)
  end

  test "recognizes valid tokens", state do
    assert Spacesuit.AuthMiddleware.valid_api_token?(state[:token]) == true
  end

  test "rejects invalid tokens" do
    assert Spacesuit.AuthMiddleware.valid_api_token?("junk!") == false
  end

  test "handling valid bearer token", state do
    req = %{ headers: %{ "authorization" => "Bearer #{state[:token]}" }, pid: self(), streamid: 1, method: "GET" }
    env = %{}

    assert {:ok, %{ headers: _headers }, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
  end

  test "handling invalid bearer token" do
    req = %{ headers: %{ "authorization" => "Bearer balloney" }, pid: self(), streamid: 1, method: "GET" }
    env = %{}

    assert {:halt, %{ headers: _headers }} = Spacesuit.AuthMiddleware.execute(req, env)
  end
end
