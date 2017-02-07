defmodule HttpClient do
  @callback request(String.t, String.t, [tuple], String.t, List.t) :: any
  @callback stream_body(String.t) :: any
end

defmodule Spacesuit.HttpClient.Hackney do
  @behaviour HttpClient

  def request(method, url, headers, body, pool) do
    :hackney.request(method, url, headers, body, pool)
  end

  def stream_body(body) do
    :hackney.stream_body(body)
  end
end

defmodule Spacesuit.HttpClient.Mock do
  @behaviour HttpClient

  # Implementation only matches expected params
  def request(_get, _url, _headers, "test body", _pool) do
    {:ok, true}
  end

  # Implementation only matches expected params
  def request(_get, _url, _headers, [], _pool) do
    {:ok, false}
  end

  def stream_body(:done) do
    :done
  end

  def stream_body(:error) do
    {:error, "testing: uh-oh"}
  end

  def stream_body(_body) do
    # TODO figure out a better way to keep state here to make sure we
    # trigger all the conditions all the time
    { result, _ } =
      [:done, {:ok, "blank"}]
        |> Enum.shuffle
        |> List.pop_at(0)

    result
  end

end
