defmodule SpacesuitTest do
  use ExUnit.Case
  doctest Spacesuit

  setup_all do
    routes = [{':_',
         [{'/users/:user_id',
           [{'name', 'users to google'}, {'destination', 'http://localhost:9090'},
            {'map', 'http://localhost:9090/:user_id'}]},
          {'/[...]',
           [{'name', 'others to hacker news'},
            {'destination', 'https://news.ycombinator.com'}, {'map', []}]}]}]

    {:ok, routes: routes}
  end

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "transform_routes does not raise errors", state do
    assert [] != Spacesuit.Router.transform_routes(state[:routes])
  end

  test "compiling routes returns the right structure" do
    uri_str = "http://example.com/users/:user_id"

    %{ map: route_map, uri: uri } = Spacesuit.Router.compile(uri_str)
    assert Enum.all?(route_map, fn(x) -> is_function(x, 1) end)
    assert URI.to_string(uri) == uri_str
  end

  test "build can process the output from compile" do
    uri_str = "http://example.com/users/:user_id"

    route_map = Spacesuit.Router.compile(uri_str)
    result = Spacesuit.Router.build(route_map, [user_id: 123])

    assert result == "http://example.com/users/123"
  end

  test "the right functions are generated for each key" do
    str_output = Spacesuit.Router.func_for_key("generic")
    assert str_output.(nil) == "generic"

    str_output = Spacesuit.Router.func_for_key(":substitution")
    assert str_output.([substitution: 123]) == 123
  end

  test "transforming one route", state do
    [{':_', [ route | _ ]}] = state[:routes]
    output = Spacesuit.Router.transform_one_route(route)

    { _route, _handler, handler_opts } = output

    assert [_one, _two] = Dict.get(handler_opts, :map)
  end
end
