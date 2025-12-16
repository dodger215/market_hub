defmodule RealtimeMarketWeb.Router do
  use RealtimeMarketWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"
    plug RealtimeMarketWeb.AuthPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
  end

  # Public API routes
  scope "/api", RealtimeMarketWeb do
    pipe_through :api

    # Auth endpoints
    post "/auth/request-otp", AuthController, :request_otp
    post "/auth/verify-otp", AuthController, :verify_otp
    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    get "/auth/check-username/:username", AuthController, :check_username
    get "/auth/health", AuthController, :health

    # Public media (no auth required for viewing)
    get "/media/:id", MediaController, :show

    # Public follow stats
    get "/follow/stats/:user_id", FollowController, :stats
  end

  # Protected API routes
  scope "/api", RealtimeMarketWeb do
    pipe_through :api_auth

    # Media uploads (protected)
    post "/media/upload", MediaController, :upload
    delete "/media/:id", MediaController, :delete

    # Follow system (protected)
    post "/follow", FollowController, :follow
    post "/unfollow", FollowController, :unfollow
    get "/followers", FollowController, :followers
    get "/following", FollowController, :following
    get "/follow/check/:following_id", FollowController, :check
    get "/follow/stats", FollowController, :stats

    # Feed API (protected)
    get "/feed", FeedController, :index
    get "/feed/trending", FeedController, :trending
    get "/feed/:product_id", FeedController, :show
    get "/feed/:product_id/media", FeedController, :media
    post "/feed/:product_id/like", FeedController, :like
    post "/feed/:product_id/share", FeedController, :share
    post "/feed/:product_id/save", FeedController, :save

    # User profile
    get "/profile", UserController, :profile
    put "/profile", UserController, :update
    get "/profile/feed", UserController, :user_feed

    # Shop management
    get "/shops", ShopController, :index
    post "/shops", ShopController, :create
    get "/shops/:id", ShopController, :show
    put "/shops/:id", ShopController, :update

    # Product management
    get "/shops/:shop_id/products", ProductController, :index
    post "/shops/:shop_id/products", ProductController, :create
    get "/products/:id", ProductController, :show
    put "/products/:id", ProductController, :update

    # Chat
    get "/chat/rooms", ChatController, :rooms
    get "/chat/rooms/:id/messages", ChatController, :messages
    post "/chat/rooms", ChatController, :create_room
    post "/chat/rooms/:id/messages", ChatController, :send_message

    # Delivery
    get "/delivery/track/:token", DeliveryController, :track
    post "/delivery/:id/status", DeliveryController, :update_status
    get "/delivery/active", DeliveryController, :active_deliveries

    # Payments
    post "/payments/initialize", PaymentController, :initialize
    post "/payments/verify", PaymentController, :verify
    get "/payments/history", PaymentController, :history
  end

  # Development routes
  if Application.compile_env(:realtime_market, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      import Phoenix.LiveDashboard.Router
      live_dashboard "/dashboard", metrics: RealtimeMarketWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
