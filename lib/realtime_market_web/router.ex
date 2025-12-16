defmodule RealtimeMarketWeb.Router do
  use RealtimeMarketWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"  # Add CORS support
  end

  # Public API routes (no authentication required)
  scope "/api", RealtimeMarketWeb do
    pipe_through :api

    # Auth endpoints
    post "/auth/request-otp", AuthController, :request_otp
    post "/auth/verify-otp", AuthController, :verify_otp
    post "/auth/register", AuthController, :register
    get "/auth/check-username/:username", AuthController, :check_username

    # Health check
    get "/health", AuthController, :health
  end

  # Protected API routes (require authentication)
  pipeline :api_auth do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"
    plug :authenticate  # Custom authentication plug
  end

  scope "/api", RealtimeMarketWeb do
    pipe_through :api_auth

    # Protected routes here (to be added later)
    # get "/profile", UserController, :profile
    # get "/shops", ShopController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:realtime_market, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: RealtimeMarketWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Custom authentication plug
  defp authenticate(conn, _opts) do
    case get_auth_token(conn) do
      {:ok, token} ->
        case RealtimeMarket.Accounts.Auth.verify_jwt(token) do
          {:ok, user_id} ->
            # Store user_id in conn assigns for use in controllers
            assign(conn, :current_user_id, user_id)

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid token"})
            |> halt()
        end

      :error ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing authentication token"})
        |> halt()
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end
end
