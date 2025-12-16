# config/config.exs
import Config

config :realtime_market,
  ecto_repos: []

config :realtime_market, RealtimeMarketWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "supersecretkeythatsatleast64charslongsupersecretkeythatsatleast64charslong",
  render_errors: [view: RealtimeMarketWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: RealtimeMarket.PubSub

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# MongoDB Configuration (common settings)
config :realtime_market, :mongo,
  name: :mongo,
  database: "realtime_market"

config :realtime_market, :jwt_secret, System.get_env("JWT_SECRET") || "your-jwt-secret-key-here"

import_config "#{config_env()}.exs"
