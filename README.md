Spacesuit
=========

![spacesuit build](https://travis-ci.org/Nitro/spacesuit.svg?branch=master)

An API gateway written in Elixir, built on top of the Cowboy web server and
Hackney http client. Supports streaming requests, remapping by hostname, HTTP
method, and endpoint.

Sample config:
```ruby
  ":_" => [ # Match any hostname
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
`iex -S mix run`

Coverage
--------

You can view the coverage output in test mode by running:
```
MIX_ENV=test mix coveralls.html
```
