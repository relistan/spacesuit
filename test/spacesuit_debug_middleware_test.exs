defmodule SpacesuitDebugMiddlewareTest do
  use ExUnit.Case
  doctest Spacesuit.DebugMiddleware

  test "doesn't interfere with anything" do
    assert {:ok, %{}, %{}} = Spacesuit.DebugMiddleware.execute(%{}, %{})
  end
end
