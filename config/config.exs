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

config :realtime_market, RealtimeMarket.Services.Email,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  ssl: true,
  tls: :always,
  auth: :always,
  port: 465

# Arkesel SMS Configuration
config :realtime_market, :arkesel_api_key, System.get_env("ARKESEL_API_KEY")

# Paystack Configuration
config :realtime_market, :paystack_secret_key, System.get_env("PAYSTACK_SECRET_KEY")
config :realtime_market, :paystack_public_key, System.get_env("PAYSTACK_PUBLIC_KEY")

# CORS Configuration
config :cors_plug,
  origin: ["http://localhost:3000", "http://localhost:4000"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

# WebSocket Configuration
config :realtime_market, RealtimeMarketWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your-secret-key-base",
  render_errors: [view: RealtimeMarketWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: RealtimeMarket.PubSub,
  # Enable WebSocket
  live_view: [signing_salt: "your-signing-salt"],
  # WebSocket transport
  websocket: [timeout: 45_000],
  longpoll: false



import_config "#{config_env()}.exs"
