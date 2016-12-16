# Debugging middleware that just prints the environment for
# every request

defmodule Spacesuit.DebugMiddleware do
  require Logger

  def execute(req, env) do
    Logger.info inspect(req)
    Logger.info inspect(env)
    {:ok, req, env}
  end
end
