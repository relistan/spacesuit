defmodule Spacesuit.Router do
  require Logger

  @http_verbs [:GET, :POST, :PUT, :PATCH, :DELETE, :HEAD]

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

        fn(bindings, _) ->
          bindings |> Keyword.fetch!(lookup_key)
        end

      # Remainder wildcard matches are built from path_info
      "..]" ->
        fn(_, path_info) ->
          path_info |> Enum.join("/")
        end
           
      # Otherwise it's just text
      _ ->
        fn(_, _) -> key end
    end
  end

  def build(method, qs, route_map, bindings, path_info) do
    verb = method |> String.upcase |> String.to_atom

    uri = Map.get(route_map, :uri)
    map = Map.get(route_map, verb)

    path = map
      |> Enum.map(fn(x) -> x.(bindings, path_info) end)
      |> Enum.join("/")

    uri
      |> Map.merge(path_and_query(path, qs))
      |> URI.to_string
  end

  defp path_and_query(path, qs) when byte_size(qs) < 1 do
    %{ path: path }
  end

  defp path_and_query(path, qs) do
    %{ path: path, query: qs }
  end

  def compile(verb, route_map) do
    uri = URI.parse(to_string(route_map))

    map = if uri.path != nil do
      # Order of split strings is important so we end up
      # with output like "/part1/part2" vs "/part1//part2"
      String.split(uri.path, ["/[.", "[.", "/"])
        |> Enum.map(&func_for_key/1)
    else
      [] 
    end

    Map.put(%{ uri: uri }, verb, map)
  end
end
