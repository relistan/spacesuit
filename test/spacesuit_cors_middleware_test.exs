defmodule SpacesuitCorsMiddlewareTest do
  use ExUnit.Case
  doctest Spacesuit.CorsMiddleware

  setup_all do
    req = %{
      :headers => %{"origin" => "http://localhost"},
      :scheme  => "http",
      :host    => "www.example.com",
      :port    => 80,
      :path    => "/matched",
      :method  => "GET"
    }
    {:ok, req: req}
  end

  describe "changing various configuration settings" do
    test "passes all requests when the middleware is disabled", state do
      # Override the :enabled setting
      current = Application.get_env(:spacesuit, :cors)
      Application.put_env(:spacesuit, :cors, Map.merge(current, %{enabled: false}))

      # This would fail if the CORS support were enabled
      req = Map.merge(state[:req], %{:headers => %{"origin" => ""}})
      env = %{}
      assert {:ok, ^req, ^env} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "allows any origin when configured to do so", state do
      current = Application.get_env(:spacesuit, :cors)
      Application.put_env(:spacesuit, :cors, Map.merge(current, %{any_origin_allowed: true}))

      req = Map.merge(state[:req], 
        %{
          :host => "example.com",
          :method => "OPTIONS",
          :headers => %{
            "origin" => "http://www.example.com",
            "Access-Control-Request-Method" => "GET"
          }
        }
      )
      env = %{}

      {:stop, req2} = Spacesuit.CorsMiddleware.execute(req, env)
      assert req2[:resp_headers]["Access-Control-Allow-Origin"] == "*"
    end

    test "limits allowed HTTP methods when set" do
      Application.put_env(:spacesuit, :cors, %{allowed_http_methods: [:GET]})
      assert Spacesuit.CorsMiddleware.allowed_http_method?(:PUT) == false
      assert Spacesuit.CorsMiddleware.allowed_http_method?(:GET) == true
    end
  end

  describe "handling non-matching request paths" do
    test "passes through OK" do
      req = %{path: "/not-matched"}
      env = %{}
      assert {:ok, ^req, ^env} = Spacesuit.CorsMiddleware.execute(req, env)
    end
  end

  describe "handling common CORS request" do
    test "passes through requests without an origin header" do
      req = %{path: "/matched"}
      env = %{}
      assert {:ok, ^req, ^env} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "passes through same origin requests with a port number", state do
      req = Map.merge(
        state[:req],
        %{:port => 9000, :headers => %{"origin" => "http://www.example.com:9000"}}
      )
      env = %{}
      assert {:ok, ^req, ^env} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "passes through same origin requests without a port number", state do
      req = Map.merge(state[:req],%{:headers => %{"origin" => "http://www.example.com"}})
      env = %{}
      assert {:ok, ^req, ^env} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "does not consider subdomains to be the same origin", state do
      req = Map.merge(state[:req], %{:host => "example.com", :headers => %{"origin" => "http://www.example.com"}})
      env = %{}
      {_, req2, _} = Spacesuit.CorsMiddleware.execute(req, env)
      assert req2[:resp_headers]["Access-Control-Allow-Origin"] == "http://www.example.com"
    end

    test "does not consider different ports to be the same origin", state do
      req = Map.merge(
        state[:req],
        %{
          :headers => %{"origin" => "http://www.example.com:9000"},
          :host => "www.example.com:9001"
        })
      env = %{}
      {_, req2, _} = Spacesuit.CorsMiddleware.execute(req, env)
      assert req2[:resp_headers]["Access-Control-Allow-Origin"] == "http://www.example.com:9000"
    end

    test "does not consider different protocols to be the same origin", state do
      req = Map.merge(
        state[:req],
        %{
          :headers => %{"origin" => "https://www.example.com:9000"},
          :host => "www.example.com:9000"
        })
      env = %{}
      {_, req2, _} = Spacesuit.CorsMiddleware.execute(req, env)
      assert req2[:resp_headers]["Access-Control-Allow-Origin"] == "https://www.example.com:9000"
    end

    test "forbids an empty origin header", state do
      req = Map.merge(state[:req], %{:headers => %{"origin" => ""}})
      env = %{}
      assert {:stop, _} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "forbids an invalid origin header", state do
      req = Map.merge(state[:req], %{:headers => %{"origin" => "localhost"}})
      env = %{}
      assert {:stop, _} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "forbids an unrecognized HTTP method", state do
      req = Map.merge(state[:req], %{ :method => "FOO", })
      env = %{}
      assert {:stop, _} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "forbids an empty Access-Control-Request-Method header in a preflight request", state do
      req = Map.merge(
        state[:req],
        %{
          :method => "OPTIONS",
          :headers => %{"origin" => "http://localhost", "Access-Control-Request-Method" => ""}
        })
      env = %{}
      assert {:stop, _} = Spacesuit.CorsMiddleware.execute(req, env)
    end

    test "handles a simple cross-origin request", state do
      {:ok, with_resp_headers, _} = Spacesuit.CorsMiddleware.execute(state[:req], %{})
      resp_headers = with_resp_headers[:resp_headers]
      assert "http://localhost" = resp_headers["Access-Control-Allow-Origin"]
      assert is_nil resp_headers["Access-Control-Allow-Headers"]
      assert is_nil resp_headers["Access-Control-Allow-Methods"]
      assert is_nil resp_headers["Access-Control-Expose-Headers"]
      assert is_nil resp_headers["Access-Control-Max-Age"]
      assert "Origin" = resp_headers["Vary"]
    end

    test "handles a basic preflight request", state do
      req = Map.merge(
        state[:req],
        %{
          :method => "OPTIONS",
          :headers => %{"origin" => "http://localhost", "Access-Control-Request-Method" => "PUT"}
        })
      {:stop, with_resp_headers} = Spacesuit.CorsMiddleware.execute(req, %{})
      resp_headers = with_resp_headers[:resp_headers]
      assert "http://localhost" = resp_headers["Access-Control-Allow-Origin"]
      assert is_nil resp_headers["Access-Control-Allow-Headers"]
      assert "PUT" = resp_headers["Access-Control-Allow-Methods"]
      assert is_nil resp_headers["Access-Control-Expose-Headers"]
      assert "3600" = resp_headers["Access-Control-Max-Age"]
      assert "Origin" = resp_headers["Vary"]
    end

  test "handles a preflight request with request headers", state do
    req = Map.merge(
      state[:req],
      %{
        :method => "OPTIONS",
        :headers => %{
          "origin" => "http://localhost",
          "Access-Control-Request-Method" => "PUT",
          "Access-Control-Request-Headers" => "X-Header1, X-Header2"
        }
      })
      {:stop, with_resp_headers} = Spacesuit.CorsMiddleware.execute(req, %{})
      resp_headers = with_resp_headers[:resp_headers]
      assert "http://localhost" = resp_headers["Access-Control-Allow-Origin"]
      assert "x-header1,x-header2" = resp_headers["Access-Control-Allow-Headers"]
      assert "PUT" = resp_headers["Access-Control-Allow-Methods"]
      assert is_nil resp_headers["Access-Control-Expose-Headers"]
      assert "3600" = resp_headers["Access-Control-Max-Age"]
      assert "Origin" = resp_headers["Vary"]
    end
  end
end
