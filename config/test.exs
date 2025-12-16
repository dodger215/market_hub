import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :realtime_market, RealtimeMarketWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6Rrp1fxvAgGdZXh8e96gS1KJVwl1OVYusayUE/x525N3aty7UQrkopOUu+7XFxRp",
  server: false

# In test we don't send emails.
config :realtime_market, RealtimeMarket.Mailer,
  adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
