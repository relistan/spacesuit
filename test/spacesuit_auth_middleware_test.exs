defmodule SpacesuitAuthMiddlewareTest do
  use ExUnit.Case
  doctest Spacesuit.AuthMiddleware

  test "'authorization' header is stripped when present" do
    req = %{ headers: %{ "authorization" => "sometoken" }}
    env = %{}

    assert {:ok, %{ headers: %{} }, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
  end

  test "bearer token processing strips the header and decodes the token" do
    tok = :base64.encode("Yo mama rides a red commode")
    req = %{ headers: %{ "authorization" => "Bearer #{tok}" }, pid: self(), streamid: 1, method: "GET" }
    env = %{}

    assert {:ok, %{ headers: %{} }, ^env} = Spacesuit.AuthMiddleware.execute(req, env)
  end

  test "recognizes unauthorized access" do
    req = %{ headers: %{ "authorization" => "magic!" }, pid: self(), streamid: 1, method: "GET" }
    env = %{}

    assert {:halt, ^req} = Spacesuit.AuthMiddleware.execute(req, env)
  end
end
