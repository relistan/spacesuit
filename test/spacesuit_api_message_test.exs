defmodule SpacesuitApiMessageTest do
  use ExUnit.Case
  doctest Spacesuit.ApiMessage

  test "encodes messages properly" do
    msg = Spacesuit.ApiMessage.encode(%Spacesuit.ApiMessage{errorCode: "error", errorMessage: "message"})
    assert msg == "{\"errorMessage\":\"message\",\"errorCode\":\"error\"}"
  end

  test "decodes messages properly" do
    msg = Spacesuit.ApiMessage.decode("{\"errorCode\":\"error\",\"errorMessage\":\"message\"}")
    assert msg.errorCode == "error"
    assert msg.errorMessage == "message"
  end
end
