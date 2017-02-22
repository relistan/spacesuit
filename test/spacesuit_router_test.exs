defmodule SpacesuitRouterTest do
  use ExUnit.Case
  doctest Spacesuit.Router

  setup_all do
    routes =
        %{':_' =>
          [{'/users/:user_id',
            %{
              description: 'users to localhost',
              destination: 'http://localhost:9090',
              GET: 'http://localhost:9090/:user_id',
              POST: 'http://example.com:9090/:user_id',
            }},
          {'/[...]',
            %{
              description: 'others to hacker news',
              destination: 'https://news.ycombinator.com',
              GET: []
             }
          }
          ]
        }

    {:ok, routes: routes}
  end

  test "that transform_routes does not raise errors", state do
    assert [] != Spacesuit.Router.transform_routes(state[:routes])
  end

  test "that compiling routes returns the right structure" do
    uri_str = "http://example.com/users/:user_id"

    %{ GET: route_map, uri: uri } = Spacesuit.Router.compile(:GET, uri_str)
    assert Enum.all?(route_map, fn(x) -> is_function(x, 1) end)
    assert URI.to_string(uri) == uri_str
  end

  test "that build() can process the output from compile" do
    uri_str = "http://example.com/users/:user_id"
    route_map = Spacesuit.Router.compile(:GET, uri_str)

    result = Spacesuit.Router.build("get", "", route_map, [user_id: 123])
    assert result == "http://example.com/users/123"
  end

  test "the right functions are generated for each key" do
    str_output = Spacesuit.Router.func_for_key("generic")
    assert str_output.(nil) == "generic"

    str_output = Spacesuit.Router.func_for_key(":substitution")
    assert str_output.([substitution: 123]) == 123
  end

  test "transforming one route", state do
    %{
      ':_' => [ route | _ ]
    } = state[:routes]

    output = Spacesuit.Router.transform_one_route(route)
    { _route, _handler, handler_opts } = output

    assert [ _one, _two ] = Map.get(handler_opts, :GET)
  end
end
