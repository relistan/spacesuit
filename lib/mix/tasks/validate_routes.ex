defmodule Mix.Tasks.ValidateRoutes do
  use Mix.Task

  @shortdoc "Validate the routes for an environment"

  @valid_map_keys Spacesuit.Router.get_http_verbs() ++
                    [:description, :destination, :all_actions, :uri, :add_headers, :middleware, :constraints]

  def run(_) do
    IO.puts("\nValidating Spacesuit Routes")
    IO.puts("----------------------------\n")

    routes = Spacesuit.Router.load_routes()

    validate_routes(routes)

    case :cowboy_router.compile(routes) do
      {:error, _} -> IO.puts("ERROR: Cowboy unable to compile routes!")
      _ -> IO.puts("OK: Cowboy compiled successfully")
    end
  end

  # The health route has a different format, so just match that one
  def validate_one_route({["/health"], [], Spacesuit.HealthHandler, %{}}) do
    :ok
  end

  # All the generated routes match this pattern
  def validate_one_route({path, constraints, handler, args}) do
    if !is_binary(path) do
      raise "Expected path matcher, found #{inspect(path)}"
    end

    IO.puts("Checking: #{path}")

    if !is_atom(handler) do
      raise "Expected handler module, found #{inspect(handler)}"
    end

    if !is_list(constraints) do
      raise "Expected list of constraints, found #{inspect(constraints)}"
    end

    for {path_variable, function} <- constraints do
      # This should probably also test if the path contains that path_variable
      if !is_atom(path_variable) do
        raise "Expected path variable in constraint, found #{inspect(path_variable)}"
      end

      if !is_function(function) do
        raise "Expected function to test constraint, found #{inspect(function)}"
      end
    end

    if !is_map(args) do
      raise "Expected route function map, found #{inspect(args)}"
    end

    for {key, value} <- args do
      if !(key in @valid_map_keys) do
        raise "Expected key to be one of #{inspect(@valid_map_keys)}, got #{inspect(key)}"
      end

      # If this is an http verb, let's make sure we got a proper URI passed to us
      if key in Spacesuit.Router.get_http_verbs() do
        if is_nil(value) do
          raise "Invalid route URI: nil"
        end

        [uri, _map] = value

        case uri do
          %URI{authority: _auth, path: _path, scheme: _scheme} ->
            :ok

          _ ->
            raise "Constructed URI for #{key} appears to be incomplete! #{inspect(args[:uri])}"
        end
      end
    end

    if !is_nil(args[:add_headers]) && !is_map(args[:add_headers]) do
      raise "Expected add_headers option is not a map, #{inspect(args[:add_headers])}"
    end

    if !is_nil(args[:middleware]) && !is_map(args[:middleware]) do
      raise "Expected middleware option is not a map, #{inspect(args[:middleware])}"
    end
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

    IO.puts("----------------------------\n")
    IO.puts("Generated routes are formatted properly")
    :ok
  end
end
