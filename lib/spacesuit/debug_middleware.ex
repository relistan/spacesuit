# Debugging middleware that just prints the environment for
# every request

defmodule Spacesuit.DebugMiddleware do
  require Logger

  def execute(req, env) do
    Logger.debug(inspect(req))
    Logger.debug(inspect(env))
    {:ok, req, env}
  end
end
