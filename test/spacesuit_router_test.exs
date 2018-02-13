defmodule SpacesuitRouterTest do
  use ExUnit.Case
  doctest Spacesuit.Router

  setup_all do
    routes = %{
      'oh-my.example.com' => [
        {'/somewhere',
         %{
           description: 'oh my example',
           all_actions: 'http://example.com',
           add_headers: %{
             "X-Something-Invalid": 123,
             "X-Something-Awesome": "awesome"
           }
         }}
      ],
      ':_' => [
        {'/users/:user_id',
         %{
           description: 'users to localhost',
           GET: 'http://localhost:9090/:user_id',
           POST: 'http://example.com:9090/:user_id',
           OPTIONS: 'http://ui.example.com:9090/:user_id'
         }},
        {'/[...]',
         %{
           description: 'others to hacker news',
           destination: 'https://news.ycombinator.com'
         }}
      ]
    }

    {:ok, routes: routes}
  end

  test "that transform_routes does not raise errors", state do
    assert [] != Spacesuit.Router.transform_routes(state[:routes])
  end

  test "that compiling routes returns a uri and list of functions" do
    uri_str = "http://example.com/users/:user_id"

    [uri, route_map] = Spacesuit.Router.compile(uri_str)
    assert Enum.all?(route_map, fn x -> is_function(x, 2) end)

    parsed_uri = URI.parse(uri)
    assert parsed_uri.host == "example.com"
  end

  test "that build() can process the output from compile" do
    uri_str = "http://example.com/users/:user_id[...]"
    route_map = %{GET: Spacesuit.Router.compile(uri_str)}

    result = Spacesuit.Router.build("get", "", route_map, [user_id: 123], ["doc"])
    assert result == "http://example.com/users/123/doc"
  end

  test "that build() can process the output from compile when only a path_map exists" do
    uri_str = "http://example.com/users/[...]"
    route_map = %{GET: Spacesuit.Router.compile(uri_str)}

    result = Spacesuit.Router.build("get", "", route_map, [], ["123"])
    assert result == "http://example.com/users/123"
  end

  test "the right functions are generated for each key" do
    str_output = Spacesuit.Router.func_for_key("generic")
    assert str_output.(nil, nil) == "generic"

    str_output = Spacesuit.Router.func_for_key(":substitution")
    assert str_output.([substitution: 123], nil) == 123

    str_output = Spacesuit.Router.func_for_key("..]")
    assert str_output.(nil, ["part1", "part2"]) == "part1/part2"
  end

  test "transforming one route with http verbs", state do
    %{
      ':_' => [route | _]
    } = state[:routes]

    output = Spacesuit.Router.transform_one_route(route)
    {_route, [], _handler, handler_opts} = output

    assert [_one, _two] = Map.get(handler_opts, :GET)
  end

  test "transforming one route with :all_actions" do
    route =
      {'/users/:user_id',
       %{
         description: 'users to localhost',
         all_actions: 'http://localhost:9090/:user_id'
       }}

    output = Spacesuit.Router.transform_one_route(route)
    {_route, [], _handler, handler_opts} = output

    assert [_one, _two] = Map.get(handler_opts, :GET)
    assert [_one, _two] = Map.get(handler_opts, :OPTIONS)
  end

  test "transforming one route with :constraints" do
    route =
      {'/users/:user_id',
        %{
          description: 'users to localhost',
          GET: 'http://localhost:9090/:user_id',
          constraints: [{:user_id, :int}]
        }}

    output = Spacesuit.Router.transform_one_route(route)
    {_route, constraint, _handler, handler_opts} = output

    assert [_one, _two] = Map.get(handler_opts, :GET)
    assert [{:user_id, :int}] = constraint
  end

  test "adds health route when configured to", state do
    Application.put_env(:spacesuit, :health_route, %{enabled: true, path: "/health"})
    [health_route | _] = Spacesuit.Router.transform_routes(state[:routes])

    assert {':_', [{["/health"], [], Spacesuit.HealthHandler, %{}} | _]} = health_route
  end

  test "does not add health route when configured not to", state do
    Application.put_env(:spacesuit, :health_route, %{enabled: false, path: "/health"})
    [first_route | _] = Spacesuit.Router.transform_routes(state[:routes])

    {':_', [{route_path, [], handler, _map} | _]} = first_route
    assert "/health" != route_path
    assert Spacesuit.HealthHandler != handler
  end

  test "generates routes that are properly ordered", state do
    Application.put_env(:spacesuit, :routes, state[:routes])
    assert {'oh-my.example.com', _} = List.first(Spacesuit.Router.load_routes())
    assert {':_', _} = List.last(Spacesuit.Router.load_routes())
  end

  test "transforms headers into String:String maps", state do
    %{
      'oh-my.example.com' => [route | _]
    } = state[:routes]

    output = Spacesuit.Router.transform_one_route(route)
    {_route, [], _handler, handler_opts} = output

    assert map_size(handler_opts[:add_headers]) == 2
    assert handler_opts[:add_headers]["X-Something-Invalid"] == "123"
    assert handler_opts[:add_headers]["X-Something-Awesome"] == "awesome"
  end
end
