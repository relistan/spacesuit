defmodule Spacesuit.Router do
  require Logger

  @http_verbs [:GET, :POST, :PUT, :PATCH, :DELETE]

  def load_routes do
    Application.get_env(:spacesuit, :routes) |> transform_routes
  end

  def transform_routes(source) do
    Enum.map(source, fn({host, routes}) ->
      {host, Enum.map(routes, &transform_one_route/1)}
    end)
  end

  def transform_one_route(source) do
    {route, opts} = source

    # Loop over the map, replacing values with compiled routes
    compiled_opts =
      @http_verbs |> List.foldl(opts, fn(verb, memo) ->
        case Map.fetch(opts, verb) do
          {:ok, route_map} ->
            Map.merge(memo, compile(verb, route_map))

          :error ->
            memo # do nothing, we just don't have this verb
        end
      end)

    {route, Spacesuit.ProxyHandler, compiled_opts}
  end

  # Returns a function that will handle the route substitution
  def func_for_key(key) do
    case key do
      # When beginning with a colon we know it's a substitution
      ":" <> lookup_key_str ->
        lookup_key = String.to_atom(lookup_key_str) 

        fn(bindings) ->
          Keyword.fetch!(bindings, lookup_key)
        end
      _ ->
        # Otherwise it's just text
        fn(_) -> key end
    end
  end

  def build(method, route_map, bindings) do
    verb = method |> String.upcase |> String.to_atom

    uri = Map.get(route_map, :uri)
    map = Map.get(route_map, verb)

    path = map
      |> Enum.map(fn(x) -> x.(bindings) end)
      |> Enum.join("/")

    URI.to_string(%{ uri | path: path })
  end

  def compile(verb, route_map) do
    uri = URI.parse(to_string(route_map))

    map = if uri.path != nil do
      String.split(uri.path, "/")
        |> Enum.map(&func_for_key/1)
    else
      [] 
    end

    Map.put(%{ uri: uri }, verb, map)
  end
end
