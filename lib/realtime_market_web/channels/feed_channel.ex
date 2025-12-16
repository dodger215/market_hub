defmodule RealtimeMarketWeb.FeedChannel do
  @moduledoc """
  Phoenix Channel for real-time product feed (Reels style).
  """

  use Phoenix.Channel

  alias RealtimeMarket.Accounts.Auth
  alias RealtimeMarket.Shops.ProductFeed

  # Topic format: "feed:user_<user_id>"
  def join("feed:user_" <> user_id, %{"token" => token}, socket) do
    case Auth.authenticate_socket(token) do
      {:ok, user} ->
        if user["_id"] == user_id do
          socket =
            socket
            |> assign(:user_id, user_id)
            |> assign(:user, user)
            |> assign(:current_feed_index, 0)

          send(self(), :load_initial_feed)
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end

      {:error, _} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:load_initial_feed, socket) do
    user_id = socket.assigns.user_id

    case ProductFeed.get_feed_for_user(user_id, 10) do
      {:ok, feed_items} ->
        push(socket, "feed_loaded", %{
          items: feed_items,
          has_more: length(feed_items) == 10
        })

        # Store feed in socket
        socket = assign(socket, :feed_items, feed_items)
        {:noreply, socket}

      {:error, _} ->
        push(socket, "feed_error", %{reason: "failed_to_load"})
        {:noreply, socket}
    end
  end

  def handle_in("view_item", %{"product_id" => product_id}, socket) do
    # Record view engagement
    ProductFeed.record_engagement(product_id, socket.assigns.user_id, "view")
    {:reply, :ok, socket}
  end

  def handle_in("like_item", %{"product_id" => product_id}, socket) do
    ProductFeed.record_engagement(product_id, socket.assigns.user_id, "like")

    # Broadcast like to shop owner
    broadcast_like_notification(product_id, socket.assigns.user_id)

    {:reply, :ok, socket}
  end

  def handle_in("share_item", %{"product_id" => product_id, "platform" => platform}, socket) do
    ProductFeed.record_engagement(product_id, socket.assigns.user_id, "share", %{
      platform: platform
    })

    {:reply, :ok, socket}
  end

  def handle_in("save_item", %{"product_id" => product_id}, socket) do
    ProductFeed.record_engagement(product_id, socket.assigns.user_id, "save")
    {:reply, :ok, socket}
  end

  def handle_in("load_more", %{"skip" => skip}, socket) do
    user_id = socket.assigns.user_id

    case ProductFeed.get_feed_for_user(user_id, 10, skip) do
      {:ok, new_items} ->
        push(socket, "more_feed_items", %{
          items: new_items,
          has_more: length(new_items) == 10
        })
        {:reply, :ok, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "failed_to_load"}}, socket}
    end
  end

  def handle_in("report_item", %{"product_id" => product_id, "reason" => reason}, socket) do
    # Store report
    report_id = RealtimeMarket.Mongo.generate_uuid()

    report = %{
      "_id" => report_id,
      "product_id" => product_id,
      "reporter_id" => socket.assigns.user_id,
      "reason" => reason,
      "status" => "pending",
      "created_at" => RealtimeMarket.Mongo.now()
    }

    RealtimeMarket.Mongo.insert_one(RealtimeMarket.Mongo.reports_collection(), report)

    {:reply, :ok, socket}
  end

  defp broadcast_like_notification(product_id, user_id) do
    # Get product owner
    product = RealtimeMarket.Mongo.find_one(
      RealtimeMarket.Mongo.products_collection(),
      %{"_id" => product_id}
    )

    if product do
      shop = RealtimeMarket.Mongo.find_one(
        RealtimeMarket.Mongo.shops_collection(),
        %{"_id" => product["shop_id"]}
      )

      if shop do
        notification = %{
          "type" => "product_like",
          "product_id" => product_id,
          "liker_id" => user_id,
          "shop_id" => shop["_id"],
          "timestamp" => RealtimeMarket.Mongo.now()
        }

        Phoenix.PubSub.broadcast(
          RealtimeMarket.PubSub,
          "notifications:shop_#{shop["_id"]}",
          {:new_notification, notification}
        )
      end
    end
  end
end
