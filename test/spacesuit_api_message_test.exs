defmodule SpacesuitApiMessageTest do
  use ExUnit.Case
  doctest Spacesuit.ApiMessage

  test "encodes messages properly" do
    msg = Spacesuit.ApiMessage.encode(%Spacesuit.ApiMessage{status: "error", message: "message"})
    assert "{\"status\":" <> _ = msg
  end

  test "decodes messages properly" do
    msg = Spacesuit.ApiMessage.decode("{\"status\":\"error\",\"message\":\"message\"}")
    assert msg.status == "error"
    assert msg.message == "message"
  end
end
