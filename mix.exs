defmodule RealtimeMarket.MixProject do
  use Mix.Project

  def project do
    [
      app: :realtime_market,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Fix xref warnings
      xref: [exclude: [EEx]]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :eex, :crypto, :ssl, :inets],
      mod: {RealtimeMarket.Application, []},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7.2"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 3.3"},
      {:cors_plug, "~> 3.0"},
      {:plug_cowboy, "~> 2.5"},
      {:jason, "~> 1.4"},
      {:httpoison, "~> 1.8"},  # Downgrade to 1.8 for compatibility

      # MongoDB - Use mongodb (not mongodb_driver) for Elixir 1.14
      {:mongodb_driver, "~> 1.0", override: true},

      # UUID
      {:elixir_uuid, "~> 1.2"},

      # CORS
      {:corsica, "~> 1.3"},

      # Email
      {:gen_smtp, "~> 1.2"},

      # Remove problematic jose dependency - use our custom JWT
      # {:jose, "~> 1.11"},  # REMOVE THIS LINE

      # Other
      {:decimal, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
