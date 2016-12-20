defmodule Spacesuit.ApiMessage do
  @derive [Poison.Encoder]
  defstruct [:status, :message]

  def encode(api_message) do
    Poison.encode!(api_message)
  end

  def decode(str) do
    Poison.decode!(str, as: %Spacesuit.ApiMessage{})
  end
end
