defmodule RealtimeMarket.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    RealtimeMarket.OTPStore.init() 
    children = [
      {Mongo, Application.get_env(:realtime_market, :mongo)},
      # Start the Telemetry supervisor
      RealtimeMarketWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: RealtimeMarket.PubSub},
      # Start Finch
      {Finch, name: RealtimeMarket.Finch},
      # Start the Endpoint (http/https)
      RealtimeMarketWeb.Endpoint
      # Start a worker by calling: RealtimeMarket.Worker.start_link(arg)
      # {RealtimeMarket.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RealtimeMarket.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RealtimeMarketWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
