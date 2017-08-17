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

### Cross-Origin Resource Sharing

Spacesuit provides middleware that implements Cross-Origin Resource Sharing (CORS).

CORS is a protocol that allows web applications to make requests from a browser
across different domains. A full specification can be found [here](https://www.w3.org/TR/cors/).

#### Configuring the CORS filter

The middleware can be configured within the routes configuration file. For a full
listing of configuration options, see the [config.exs](blob/master/config/config.exs#L70-L84).

The available options include:

* path_prefixes - filter paths by a whitelist of path prefixes
* allowed_origins - allow only requests with origins from a whitelist (by default all origins are allowed)
* allowed_http_methods - allow only HTTP methods from a whitelist for preflight requests (by default all methods are allowed)
* allowed_http_headers - allow only HTTP headers from a whitelist for preflight requests (by default all headers are allowed)
* preflight_max_age - set how long the results of a preflight request can be cached in a preflight result cache (by default 1 hour)
* allowed_origins - enable/disable serving requests with origins not in whitelist as non-CORS requests (by default they are forbidden)
* any_origin_allowed - enable/disable serving requests with origins not in whitelist as non-CORS requests (by default they are forbidden)

### AuthN Middleware with Session Service Integration

Spacesuit provide an AuthN middleware, coupled with a session-providing service, that **when
enabled**, supplies a mechanism to exchange lightweight access tokens for fuller fledged session
tokens.

When the session service integration is disabled, all requests are passed through to whatever
backend service is matched by the active route configuration for the current request. However, if
enabled, in the presence of a request containing an `Authorization` HTTP header with a bearer token,
the AuthN middleware will make a request to the configured session service and exchange the API
access token for a richer session token, which will then be passed to the backend service instead
of the access token provided by the client initially.

If the session service is enabled in your configuration, and there are routes that should not have this exchange occur, the middleware can be configured on a route-by-route basis to skip any token
enrichment and instead forward the request through to the backing service, bypassing the session
service. An example route follows:

```ruby
...
    {"/users/:user_id/un-enriched", %{
      description: "XXX",
      all_actions: "http://[::1]:9090/:user_id/un-enriched",
      middleware: %{
        session_service: :disabled
      }
    }},

...
```

Coverage
--------

You can view the coverage output in test mode by running:
```
MIX_ENV=test mix coveralls.html
```
