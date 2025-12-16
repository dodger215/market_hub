# lib/realtime_market_web/user_socket.ex
defmodule RealtimeMarketWeb.UserSocket do
  @moduledoc """
  Main socket handler for WebSocket connections.
  """
  use Phoenix.Socket

  ## Channels
  channel "chat:*", RealtimeMarketWeb.ChatChannel
  channel "feed:*", RealtimeMarketWeb.FeedChannel
  channel "delivery:*", RealtimeMarketWeb.DeliveryChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  # the current user. To deny access, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case RealtimeMarket.Accounts.Auth.verify_jwt(token) do
      {:ok, user_id} ->
        # Store user_id in socket assigns
        socket = assign(socket, :user_id, user_id)
        {:ok, socket}

      {:error, reason} ->
        # Log the error but still allow connection for public topics
        IO.puts("Socket auth failed: #{inspect(reason)}")
        # Allow connection but without user_id
        {:ok, assign(socket, :user_id, nil)}
    end
  end

  # Connection without token (for public access to delivery tracking)
  def connect(_params, socket, _connect_info) do
    {:ok, assign(socket, :user_id, nil)}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     RealtimeMarketWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket) do
    if socket.assigns.user_id do
      "user_socket:#{socket.assigns.user_id}"
    else
      nil
    end
  end
end
