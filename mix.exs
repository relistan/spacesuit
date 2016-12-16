defmodule Spacesuit.Mixfile do
  use Mix.Project
  use Mix.Config

  def project do
    [app: :spacesuit,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:logger, :cowboy, :hackney],
      mod: { Spacesuit, [] }
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:hackney, "~> 1.6.3"},
      {:cowboy, github: "extend/cowboy"}
    ]
  end

  config :logger,
    backends: [:console],
    compile_time_purge_level: :info
end
