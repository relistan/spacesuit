defmodule SpacesuitAuthMiddlewareTest do
  use ExUnit.Case
  doctest Spacesuit.AuthMiddleware

  setup_all do
    token = "eyJhbGciOiJIUzM4NCIsInR5cCI6IkpXVCJ9.eyJhY2N0IjoiMSIsImF6cCI6ImthcmwubWF0dGhpYXNAZ29uaXRyby5jb20iLCJkZWxlZ2F0ZSI6IiIsImV4cCI6IjIwMTctMDItMDNUMTU6MDc6MTRaIiwiZmVhdHVyZXMiOlsidGVhbWRvY3MiLCJjb21iaW5lIiwiZXNpZ24iXSwiaWF0IjoiMjAxNy0wMi0wM1QxNDowNzoxNC40MTMyMTg2OTNaIiwianRpIjoiNTU2ZmU1MTgtYTk0Mi00YTQ3LTkyZmMtNWNmNmVkOWY0YWFhIiwicGVybXMiOlsiYWNjb3VudHM6cmVhZCIsImdyb3VwczpyZWFkIiwidXNlcnM6d3JpdGUiXSwic3ViIjoiY3NzcGVyc29uQGdvbml0cm8uY29tIn0.6eWCzu6yHhgzuvUPaNloNl09uUfaN6nqhK1W--TQwtMk29tf5C5SV-hTT2pxnSxe"

    {:ok, token: token}
  end

  describe "handling non-bearer tokens" do
    test "passes through OK when there is no auth header" do
      assert {:ok, %{}, %{}} = Spacesuit.AuthMiddleware.execute(%{}, %{})   
    end

    test "'authorization' header is stripped when present" do
      req = %{ headers: %{ "authorization" => "sometoken" }}
      env = %{}

      assert {:ok, %{ headers: %{} }, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
    end
  end

  describe "handling bearer tokens" do
    test "with a valid token", state do
      req = %{ headers: %{ "authorization" => "Bearer #{state[:token]}" }, pid: self(), streamid: 1, method: "GET" }
      env = %{}

      assert {:ok, %{ headers: _headers }, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
    end

    test "with valid bearer token and without session service" do
      Application.put_env(:spacesuit, :session_service, %{ enabled: false })
      req = %{ headers: %{ "authorization" => "Bearer balloney" }, pid: self(), streamid: 1, method: "GET" }
      env = %{}

      # Should just pass through unaffected
      assert {:ok, ^req, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
    end

    test "with an invalid token when session service is enabled" do
      Application.put_env(:spacesuit, :session_service, %{ enabled: true, impl: Spacesuit.MockSessionService })

      req = %{ headers: %{ "authorization" => "Bearer error" }, pid: self(), streamid: 1, method: "GET" }
      env = %{}

      # Unrecognized, we pass it on as is
      assert {:stop, ^req} = Spacesuit.AuthMiddleware.execute(req, env)
    end

   test "with a valid token when session service is enabled" do
      Application.put_env(:spacesuit, :session_service, %{ enabled: true, impl: Spacesuit.MockSessionService })

      req = %{ headers: %{ "authorization" => "Bearer ok" }, pid: self(), streamid: 1, method: "GET" }
      env = %{}

      # Unrecognized, we pass it on as is
      assert {:ok, ^req, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
    end

   test "with a missing token when session service is enabled" do
      Application.put_env(:spacesuit, :session_service, %{ enabled: true, impl: Spacesuit.MockSessionService })

      req = %{ headers: %{ "authorization" => "Bearer " }, pid: self(), streamid: 1, method: "GET" }
      env = %{}

      # Unrecognized, we pass it on as is
      assert {:ok, ^req, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
    end
  end
end
