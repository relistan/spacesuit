# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :spacesuit, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:spacesuit, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# Turn off all file logging
config :logger, backends: [:console]
config :logger, level: String.to_atom(System.get_env("SPACESUIT_LOGGING_LEVEL") || "debug")

# Get rid of the execessive line feeding and level padding in
# the default Elixir logger.
config :logger, :console, 
  format: "$time $metadata[$level] $message\n"

# Because Exometer and Elixometer have a hard dependency on Lager, we have to
# make that all play nice
# --------------------------------------------------------------
# Stop lager redirecting :error_logger messages
config :lager, :error_logger_redirect, false
# Stop lager removing Logger's :error_logger handler
config :lager, :error_logger_whitelist, [Logger.ErrorHandler]
# Stop lager writing a crash log
config :lager, :crash_log, false
# Use LagerLogger as lager's only handler.
config :lager, :handlers, [{LagerLogger, [level: :debug]}]
# --------------------------------------------------------------

# If we have a NEW_RELIC_LICENSE_KEY, we'll use a New Relic reporter
if System.get_env("NEW_RELIC_LICENSE_KEY") != "" do
  config :exometer_core, report: [
    reporters: ["Elixir.Exometer.NewrelicReporter":
      [
        application_name: "Spacesuit #{Mix.env}",
        license_key: System.get_env("NEW_RELIC_LICENSE_KEY"),
        synthesize_metrics: %{
          "proxyHandler-handle" => "HttpDispatcher"
        }
      ]
    ]
  ]

  config :elixometer, reporter: :"Elixir.Exometer.NewrelicReporter",
    update_frequency: 60_000
end

# Health route
config :spacesuit, :health_route, %{ path: "/health", enabled: true }

# Do we call out to an external session service that can process JWT tokens?
config :spacesuit, session_service: %{ enabled: false }

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{Mix.env}.exs"
