defmodule Spacesuit.Router do
  require Logger

  @routes_file "routes.yaml"

  @http_verbs [:GET, :POST, :PUT, :PATCH, :DELETE]

  def load_routes do
    [routes] = :yamerl_constr.file(@routes_file)
    # Let's validate what we got and at least fail to start if it's busted
#    if !valid_routes?(routes) do
#      raise "Invalid routes! #{inspect(routes)}"
#    end
    transform_routes(routes)
  end

  def valid_routes?(routes) do
    try do
      Enum.all?(routes, fn(r) ->
        {_host, entries} = r
        Enum.all?(entries, fn(e) ->
          {_route, items} = e
          List.keymember?(items, 'description', 0) && (
            List.keymember?(items, 'map', 0) || List.keymember?(items, 'destination', 0)
          )
        end)
      end)
    rescue
      e in MatchError ->
        Logger.error "Bad routes! Cannot parse structure: #{e}"
        false
    end
  end

  def transform_routes(source) do
    Enum.map(source, fn({host, routes}) ->
      {host, Enum.map(routes, &transform_one_route/1)}
    end)
  end

  def transform_one_route(source) do
    {route, opts} = source

    atomized_opts = atomize_opts(opts)

    compiled_opts =
      @http_verbs |> List.foldl(%{}, fn(verb, memo) ->
        case Map.fetch(atomized_opts, verb) do
          {:ok, route_map} ->
            Map.merge(memo, compile(verb, route_map))

          :error ->
            memo # do nothing, we just don't have this verb
        end
      end)

    handler_opts = Map.merge(atomized_opts, compiled_opts)

    {route, Spacesuit.ProxyHandler, handler_opts}
  end

  # Turn nasty structure into a map with atoms
  def atomize_opts(opts) do
    opts |> List.foldl(%{},
      fn({k, v}, memo) ->
        Map.put(memo, String.to_atom(to_string(k)), v)
      end)
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
