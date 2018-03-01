defmodule Spacesuit.Router do
  require Logger

  @http_verbs [:GET, :POST, :PUT, :PATCH, :DELETE, :HEAD, :OPTIONS]

  def load_routes do
    Application.get_env(:spacesuit, :routes)
    |> transform_routes
    |> Enum.reverse()
  end

  def transform_routes(source) do
    Enum.map(source, fn {host, routes} ->
      compiled_routes =
        routes
        |> Enum.map(&transform_one_route/1)

      # Look this up every time, but it's in ETS and this isn't
      # high throughput anyway
      stored_route = Application.get_env(:spacesuit, :health_route)

      # We add a health route to each hostname if configured
      case stored_route[:enabled] do
        true ->
          health_route = [{[stored_route[:path]], [], Spacesuit.HealthHandler, %{}}]
          {host, health_route ++ compiled_routes}

        false ->
          {host, compiled_routes}
      end
    end)
  end

  def transform_one_route(source) do
    {route, opts} = source

    compiled_opts =
      opts
      |> process_verbs
      |> process_headers
      |> add_all_actions

    constraints = Map.get(compiled_opts, :constraints, [])
    compiled_opts = Map.delete(compiled_opts, :constraints)

    {route, constraints, Spacesuit.ProxyHandler, compiled_opts}
  end

  # Expose the verbs to the outside
  def get_http_verbs do
    @http_verbs
  end

  # Loop over the map, replacing values with compiled routes
  defp process_verbs(opts) do
    @http_verbs
    |> List.foldl(opts, fn verb, memo ->
      case Map.fetch(opts, verb) do
        {:ok, map} ->
          Map.put(memo, verb, compile(map))

        :error ->
          # do nothing, we just don't have this verb
          memo
      end
    end)
  end

  # Will insert custom headers into each request. Currently only
  # static headers are supported. Does not modify the casing of
  # the headers: they will passed as specified in the config.
  defp process_headers(opts) do
    case Map.fetch(opts, :add_headers) do
      {:ok, headers} ->
        valid_opts =
          Enum.map(headers, fn {header, value} ->
            {to_string(header), to_string(value)}
          end)

        Map.put(opts, :add_headers, Map.new(valid_opts))

      :error ->
        opts
    end
  end

  # If the all_actions key is present, let's add them all.
  # This lets us specify `all_actions: route_map` in the config
  # instead of writing a line for each and every HTTP verb.
  defp add_all_actions(opts) do
    case Map.fetch(opts, :all_actions) do
      {:ok, route_map} ->
        @http_verbs
        |> List.foldl(opts, fn verb, memo ->
          Map.put(memo, verb, compile(route_map))
        end)

      :error ->
        opts
    end
  end

  # Returns a function that will handle the route substitution
  def func_for_key(key) do
    case key do
      # When beginning with a colon we know it's a substitution
      ":" <> lookup_key_str ->
        lookup_key = String.to_atom(lookup_key_str)

        fn bindings, _ ->
          bindings |> Keyword.fetch!(lookup_key)
        end

      # Remainder wildcard matches are built from path_info
      "..]" ->
        fn _, path_info ->
          path_info |> Enum.join("/")
        end

      # Otherwise it's just text
      _ ->
        fn _, _ -> key end
    end
  end

  # Construct the upstream URL using the route_map which contains
  # the compiled routes, and the request method, query string, and
  # bindings.
  def build(method, qs, state, bindings, path_info) do
    verb = method |> String.upcase() |> String.to_atom()

    [uri, map] = Map.get(state, verb)

    path =
      map
      |> Enum.map(fn x -> x.(bindings, path_info) end)
      |> Enum.join("/")

    uri
    |> Map.merge(path_and_query(path, qs))
    |> URI.to_string()
  end

  defp path_and_query(path, qs) when byte_size(qs) < 1 do
    %{path: path}
  end

  defp path_and_query(path, qs) do
    %{path: path, query: qs}
  end

  def compile(map) do
    uri = URI.parse(to_string(map))

    compiled_map =
      if uri.path != nil do
        # Order of split strings is important so we end up
        # with output like "/part1/part2" vs "/part1//part2"
        String.split(uri.path, ["/[.", "[.", "/"])
        |> Enum.map(&func_for_key/1)
      else
        []
      end

    [uri, compiled_map]
  end
end
