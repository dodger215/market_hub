# config/dev.exs
import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :realtime_market, RealtimeMarketWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "Aby1wVjRuTAQwwA/7gvCBSzSAbNcyrTcUN2yAadTW0cGsUeT6HdlRIJvE0n42Cpb",
  watchers: []

# Enable dev routes for dashboard and mailbox
config :realtime_market, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# MongoDB configuration for development
config :realtime_market, :mongo,
  name: :mongo,
  database: "realtime_market",
  hostname: "localhost",
  port: 27017,
  pool_size: 10


# config :realtime_market, :mongo,
#   name: :mongo,
#   database: "realtime_market",
#   # For MongoDB Atlas (adjust with your actual cluster)
#   seeds: ["cluster0-shard-00-00.abcde.mongodb.net:27017"],
#   username: System.get_env("MONGO_USERNAME") || "your_username",
#   password: System.get_env("MONGO_PASSWORD") || "your_password",
#   auth_source: "admin",
#   ssl: true,
#   ssl_opts: [
#     verify: :verify_none
#   ],
#   pool_size: 10

# Or use connection string for MongoDB Atlas:
# config :realtime_market, :mongo,
#   url: System.get_env("MONGO_URL") || "mongodb+srv://username:password@cluster0.abcde.mongodb.net/realtime_market?retryWrites=true&w=majority"
