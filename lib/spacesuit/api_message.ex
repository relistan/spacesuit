# Encapsulate the API messages we hand back. Ideally
# this would support a config option to return whatever
# the API uses. i.e. protobuf, msgpack, JSON

# Just does JSON for now
defmodule Spacesuit.ApiMessage do
  @derive [Poison.Encoder]
  defstruct [:errorCode, :errorMessage]

  def encode(api_message) do
    Poison.encode!(api_message)
  end

  def decode(str) do
    Poison.decode!(str, as: %Spacesuit.ApiMessage{})
  end
end
