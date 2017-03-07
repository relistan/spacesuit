defmodule SpacesuitSessionServiceTest do
  use ExUnit.Case
  import Mock

  doctest Spacesuit.SessionService

  setup_all do
    token = "eyJhbGciOiJIUzM4NCIsInR5cCI6IkpXVCJ9.eyJhY2N0IjoiMSIsImF6cCI6ImthcmwubWF0dGhpYXNAZ29uaXRyby5jb20iLCJkZWxlZ2F0ZSI6IiIsImV4cCI6IjIwMTctMDItMDNUMTU6MDc6MTRaIiwiZmVhdHVyZXMiOlsidGVhbWRvY3MiLCJjb21iaW5lIiwiZXNpZ24iXSwiaWF0IjoiMjAxNy0wMi0wM1QxNDowNzoxNC40MTMyMTg2OTNaIiwianRpIjoiNTU2ZmU1MTgtYTk0Mi00YTQ3LTkyZmMtNWNmNmVkOWY0YWFhIiwicGVybXMiOlsiYWNjb3VudHM6cmVhZCIsImdyb3VwczpyZWFkIiwidXNlcnM6d3JpdGUiXSwic3ViIjoiY3NzcGVyc29uQGdvbml0cm8uY29tIn0.6eWCzu6yHhgzuvUPaNloNl09uUfaN6nqhK1W--TQwtMk29tf5C5SV-hTT2pxnSxe"

    ok_response = {:ok, %HTTPoison.Response{status_code: 200, body: token}}

    {:ok, token: token, ok_response: ok_response}
  end

  describe "validate_api_token/1" do
    test "recognizes valid tokens", state do
      assert Spacesuit.SessionService.validate_api_token(state[:token]) == :ok
    end

    test "rejects invalid tokens" do
      assert Spacesuit.SessionService.validate_api_token("junk!") == :error
    end
  end

  describe "get_enriched_token/2" do
    test "with a good token", state do
      %{token: token, ok_response: response } = state

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.get_enriched_token(token, "example.com")
        assert {:ok, ^token} = result
      end
    end

    test "with a bad token", state do
      response = {:ok, %HTTPoison.Response{status_code: 404, body: "error message"}}

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.get_enriched_token(state[:token], "example.com")
        assert {:error, 404, "error message"} = result
      end
    end

    test "with an unexpected response", state do
      # Session service must not accept/follow redirects
      response = {:ok, %HTTPoison.Response{status_code: 301}}

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.get_enriched_token(state[:token], "example.com")
        assert {:error, 500, _body} = result
      end
    end

    test "passes the right headers", state do
      token = state[:token]
      # Don't care what we return, just look at the headers
      validate_headers = fn(_url, headers, _options) ->
        assert Keyword.get(headers, :"Authorization") == "Bearer #{token}"
      end

      with_mock HTTPoison, [get: validate_headers] do
        Spacesuit.SessionService.get_enriched_token(token, "example.com")
      end
    end
  end

  describe "handle_bearer_token/4" do
    test "the happy path returns a modified request", state do
      %{token: token, ok_response: response } = state

      req = %{ headers: %{ "authorization" => "overwrite this" } }
      expected = %{ headers: %{ "authorization" => "Bearer #{token}" } }

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.handle_bearer_token(req, %{}, token, "example.com")
        assert {:ok, ^expected, %{}} = result
      end
    end

    test "unhappy path returns a :stop request", state do
      token = state[:token]
      response = {:ok, %HTTPoison.Response{status_code: 301}}

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.handle_bearer_token(%{}, %{}, token, "example.com")
        assert {:stop, %{}} = result
      end
    end
  end
end
