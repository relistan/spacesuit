defmodule MixTasksValidateRoutesTest do
    use ExUnit.Case
    doctest Mix.Tasks.ValidateRoutes

    test "valid routes should be ok" do
        constraint = {:pathvariable, fn(_) -> true end}
        route = {"/path", [constraint], :handler,
            %{
                description: "dummy route",
                uri: URI.parse("http://example.com/"),
                destination: "destination",
                all_actions: "action",
                add_headers: %{ "Accept" => "text/html" }
            }
        }

        res = Mix.Tasks.ValidateRoutes.validate_routes([{"host", [route] }])
        assert :ok = res
    end

    test "health route should be ok" do
        assert :ok = Mix.Tasks.ValidateRoutes.validate_one_route({["/health"], [], Spacesuit.HealthHandler, %{}})
    end

    test "should throw if handler is not an atom" do
        assert_raise RuntimeError, fn ->
            Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [], "not an atom", %{}})
        end
    end

    test "should throw if args is not a map" do
        assert_raise RuntimeError, fn ->
            Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [], :handler, :not_a_map})
        end
    end

    test "invalid path should throw" do
        assert_raise RuntimeError, fn ->
            Mix.Tasks.ValidateRoutes.validate_one_route({:not_a_path, [], :handler, %{}})
        end
    end

    test "add_headers should throw if it is not a map" do
        assert_raise RuntimeError, fn ->
            Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [], :handler, %{ add_headers: "not a map" }})
        end
    end

    test "invalid arg map key should throw" do
        assert_raise RuntimeError, fn ->
            Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [], :handler, %{ bad_option: "oops" }})
        end
    end

    test "invalid uri arg should throw" do
        assert_raise RuntimeError, fn ->
            Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [], :handler, %{ GET: nil }})
        end
    end


    test "invalid constraint path variable should throw" do
      assert_raise RuntimeError, fn ->
        Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [{"not an atom", fn(_) -> true end}], :handler, %{}})
      end
    end

    test "invalid constraint function should throw" do
      assert_raise RuntimeError, fn ->
        Mix.Tasks.ValidateRoutes.validate_one_route({"/path", [{:pathvariable, "not a function"}], :handler, %{}})
      end
    end
end
