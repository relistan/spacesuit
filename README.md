Spacesuit
=========

![spacesuit build](https://travis-ci.org/Nitro/spacesuit.svg?branch=master)

An API gateway written in Elixir, built on top of the Cowboy web server and
Hackney http client. Supports streaming requests, remapping by hostname, HTTP
method, and endpoint. Now also includes full CORS support with middleware,
allowing backing services to offload CORS to Spacesuit.

Sample config:
```ruby
  "[...]:_" => [ # Match any hostname/port
    { "/users/:user_id", %{
      description: "users to [::1]:9090",
      GET: "http://[::1]:9090/:user_id", # ipv6 localhost (thanks osx)
      POST: "http://[::1]:9090/:user_id"
    }},

    {"/users/something/:user_id", %{
      description: "users/something to [::1]:9090",
      all_actions: "http://[::1]:9090/something/:user_id"
    }},

    {"/[...]", %{
      description: "others to hacker news",
      destination: "https://news.ycombinator.com"
    }}
  ]
```

Installation
------------

You need to have Elixir and the BEAM VM installed. On OSX the easiest way to do
that is to `brew install elixir`. Next you need to install dependencies, with
`mix deps.get`. Now you're ready to roll.

*Note*: To run `mix compile` or `mix test` you also have to install Rebar3, the Erlang build system.
On OSX, use `brew install rebar` to install it.

Running
-------

Spacesuit listens on 8080 and waits for requests. You can start it up by running
`iex -S mix run` or `mix run --no-halt`.

Configuration
-------------

Spacesuit relies on the `mix` configuration system with a common config in
`config/config.exs` and environment based configs merged on top of that. If you
were running in the `dev` environment, for example, `config/config.exs` would
get loaded first and then `config/dev.exs` would be loaded afterward.
Additionally, it can be configured with some environment variables. The most
common of these are

* `MIX_ENV` which describes the current evironment
* `SPACESUIT_LOGGING_LEVEL` which is a string corresponding to the minimum level of
  logging we'll show in the console. (e.g. `SPACESUIT_LOGGING_LEVEL="warn"`)

If you use New Relic for monitoring your applications, you can also turn on basic
metric support in Spacesuit by providing the standard New Relic environment variable
for your license key:

* `NEW_RELIC_LICENSE_KEY` the string value containing your New Relic license, as
  provided to any other New Relic agent.

Route Configuration
-------------------

The routes support a fairly extensive pattern match, primarily from the
underlying Cowboy web server. The good documentation on that is [available
here](https://ninenines.eu/docs/en/cowboy/1.0/guide/routing/). Spacesuit supports
outbound remapping using a very similar syntax, as shown above.

The routes operate as a drop-through list so the first match will be the one
used. This means you need to order your routes from the most specific to the
least specific in descending order. E.g. if you have a wildcard match that will
match all hostnames, it needs to be below any routes that match on specific
hostnames. If you've written network access lists before, these operate in a
similar manner.

Once you have written your routes, a good step is to run the `mix validate_routes`
task, which will load the routes for the current `MIX_ENV` and check them all
for correctness.

CORS Middleware
---------------

Spacesuit contains a CORS middleware which handles offloading CORS support from
backend services. You can enable this in the config following the examples set
there. **Note** if upstream services have CORS handling enabled internally and
are sending CORS headers, responses from those services will override any from
Spacesuit, even if CORS is enabled, *except* for `OPTIONS` requests which will
be served from Spacesuit all the time if CORS support is enabled for an endpoint.

Coverage
--------

You can view the coverage output in test mode by running:
```
MIX_ENV=test mix coveralls.html
```
