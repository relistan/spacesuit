defmodule SpacesuitSessionServiceTest do
  use ExUnit.Case
  import Mock

  doctest Spacesuit.SessionService

  @jwt_secret Application.get_env(:spacesuit, :jwt_secret)

  setup_all do
    token = %Joken.Token{ claims: %{
      acct: "1",
      azp: "beowulf@geatland.example.com",
      exp: (DateTime.utc_now |> DateTime.to_unix) + 100,
      iat: (DateTime.utc_now |> DateTime.to_unix) - 100,
      jti: "556fe518-a942-4a47-92fc-5cf6ed9f4aaa",
    } }
    |> Joken.sign(Joken.hs384(@jwt_secret))
    |> Joken.get_compact

    ok_body = Poison.encode!(%{ data: token })
    ok_response = {:ok, %HTTPoison.Response{status_code: 200, body: ok_body }}

    {:ok, token: token, ok_response: ok_response}
  end

  describe "validate_api_token/1" do
    test "recognizes valid tokens", state do
      assert Spacesuit.SessionService.validate_api_token(state[:token]) == :ok
    end

    test "rejects invalid tokens" do
      assert {:error, :validation, "Invalid signature"} = Spacesuit.SessionService.validate_api_token("junk!")
    end
  end

  describe "get_enriched_token/2" do
    test "with a good token", state do
      %{token: token, ok_response: response } = state

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.get_enriched_token(token, "example.com")
        expected_json = Poison.encode!(%{ data: token })
        assert {:ok, ^expected_json} = result
      end
    end

    test "with a bad token", state do
      response = {:ok, %HTTPoison.Response{status_code: 404, body: "error message"}}

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.get_enriched_token(state[:token], "example.com")
        assert {:error, :http, 404, "error message"} = result
      end
    end

    test "with an unexpected response", state do
      # Session service must not accept/follow redirects
      response = {:ok, %HTTPoison.Response{status_code: 301}}

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.get_enriched_token(state[:token], "example.com")
        assert {:error, :http, 500, _body} = result
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

    test "invalid token signature returns a :stop request" do
      token = "garbage"
      req = %{ prove_identity: "proof" }
      result = Spacesuit.SessionService.handle_bearer_token(req, %{}, token, "example.com")
      assert {:stop, ^req} = result
    end

    test "bad http response from the session service returns a :stop request", state do
      token = state[:token]
      response = {:ok, %HTTPoison.Response{status_code: 301}}
      req = %{ prove_identity: "proof" } # We pass this request back as well

      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> response end] do
        result = Spacesuit.SessionService.handle_bearer_token(req, %{}, token, "example.com")
        assert {:stop, ^req} = result
      end
    end

    test "returns invalid token for an expired token" do
      token = %Joken.Token{ claims: %{
        acct: "1",
        azp: "beowulf@geatland.example.com",
        exp: (DateTime.utc_now |> DateTime.to_unix) - 100,
        iat: (DateTime.utc_now |> DateTime.to_unix) - 300,
        jti: "556fe518-a942-4a47-92fc-5cf6ed9f4aaa",
      } }
      |> Joken.sign(Joken.hs384(@jwt_secret))
      |> Joken.get_compact

      result = Spacesuit.SessionService.handle_bearer_token(%{}, %{}, token, "example.com")
      assert {:stop, %{}} = result
    end
  end

  describe "unexpired?/1" do
    test "If passed anything but a unix epoch integer, we say it's expired" do
      assert Spacesuit.SessionService.unexpired?("asdf") == false
    end

    test "If passed an expired time, it's expired" do
      expired = DateTime.to_unix(DateTime.utc_now) - 10
      assert Spacesuit.SessionService.unexpired?(expired) == false
    end

    test "If passed a valid time, its ok" do
      valid = DateTime.to_unix(DateTime.utc_now) + 10
      assert Spacesuit.SessionService.unexpired?(valid) == true
    end
  end
end
