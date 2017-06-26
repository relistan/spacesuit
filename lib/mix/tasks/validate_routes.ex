defmodule Mix.Tasks.ValidateRoutes do
  use Mix.Task

  @shortdoc "Validate the routes for an environment"

  @valid_map_keys Spacesuit.Router.get_http_verbs ++
    [:description, :destination, :all_actions, :uri]

  def run(_) do
    IO.puts "\nValidating Spacesuit Routes"
    IO.puts "----------------------------\n"

    routes = Spacesuit.Router.load_routes

    validate_routes(routes)
    case :cowboy_router.compile(routes) do
      {:error, _} -> IO.puts "ERROR: Cowboy unable to compile routes!"
      _ -> IO.puts "OK: Cowboy compiled successfully"
    end
  end

  # All the generated routes match this pattern
  def validate_one_route({path, handler, args}) do
    if !is_binary(path) do
      raise "Expected path matcher, found #{inspect(path)}"
    end

    IO.puts "Checking: #{path}"

    if !is_atom(handler) do
      raise "Expected handler module, found #{inspect(handler)}"
    end

    if !is_map(args) do
      raise "Expected route function map, found #{inspect(args)}"
    end

    for {key, _value} <- args do
      if !(key in @valid_map_keys) do
        raise "Expected key to be one of #{inspect(@valid_map_keys)}, got #{inspect(key)}"
      end
    end

    case args[:uri] do
      %URI{authority: _auth, path: _path, scheme: _scheme} -> :ok
      _ ->
        raise "Constructed URI appears to be incomplete! #{inspect(args[:uri])}"
    end
  end

  # The health route has a different format, so just match that one
  def validate_one_route({["/health"], [], Spacesuit.HealthHandler, %{}}) do
  end

  def validate_routes(routes) do
    routes
      |> Enum.each(fn {host, routes} ->
           if !is_binary(host) do
             raise "Expected host matcher, found #{inspect(host)}"
           end

           for route <- routes do
             validate_one_route(route)
           end
         end)

    IO.puts "----------------------------\n"
    IO.puts "Generated routes are formatted properly"
  end
end
