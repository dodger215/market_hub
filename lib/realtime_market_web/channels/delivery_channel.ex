defmodule RealtimeMarketWeb.DeliveryChannel do
  @moduledoc """
  Phoenix Channel for real-time delivery tracking.
  """

  use Phoenix.Channel

  alias RealtimeMarket.Accounts.Auth
  alias RealtimeMarket.Delivery.{Delivery, Tracker}
  alias RealtimeMarket.Delivery.Geo

  # Topic format: "delivery:delivery_<delivery_id>"
  # or "delivery:token_<tracking_token>" for customers
  def join("delivery:" <> topic, %{"token" => token}, socket) do
    case parse_topic(topic) do
      {:delivery_id, delivery_id} ->
        join_by_delivery_id(delivery_id, token, socket)

      {:tracking_token, tracking_token} ->
        join_by_tracking_token(tracking_token, socket)

      _ ->
        {:error, %{reason: "invalid_topic"}}
    end
  end

  defp parse_topic("delivery_" <> delivery_id), do: {:delivery_id, delivery_id}
  defp parse_topic("token_" <> tracking_token), do: {:tracking_token, tracking_token}
  defp parse_topic(_), do: :error

  defp join_by_delivery_id(delivery_id, token, socket) do
    case Auth.authenticate_socket(token) do
      {:ok, user} ->
        case Delivery.get(delivery_id) do
          {:ok, delivery} ->
            # Check if user is authorized
            if user["_id"] in [delivery["shop_id"], delivery["customer_id"], delivery["delivery_person_id"]] do
              socket =
                socket
                |> assign(:delivery_id, delivery_id)
                |> assign(:user_id, user["_id"])
                |> assign(:user_role, get_user_role(user["_id"], delivery))
                |> assign(:delivery, delivery)

              send(self(), :after_join)
              {:ok, socket}
            else
              {:error, %{reason: "unauthorized"}}
            end

          {:error, _} ->
            {:error, %{reason: "delivery_not_found"}}
        end

      {:error, _} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  defp join_by_tracking_token(tracking_token, socket) do
    # Public tracking without authentication
    case Delivery.get_by_tracking_token(tracking_token) do
      {:ok, delivery} ->
        socket =
          socket
          |> assign(:delivery_id, delivery["_id"])
          |> assign(:user_id, nil)
          |> assign(:user_role, :customer)
          |> assign(:delivery, delivery)

        send(self(), :after_join)
        {:ok, socket}

      {:error, _} ->
        {:error, %{reason: "delivery_not_found"}}
    end
  end

  defp get_user_role(user_id, delivery) do
    cond do
      user_id == delivery["shop_id"] -> :shop_owner
      user_id == delivery["customer_id"] -> :customer
      user_id == delivery["delivery_person_id"] -> :delivery_person
      true -> :observer
    end
  end

  def handle_info(:after_join, socket) do
    # Send delivery details and location history
    delivery = socket.assigns.delivery

    # Get latest location
    latest_location =
      case Tracker.get_latest_location(delivery["_id"]) do
        {:ok, location} -> location
        _ -> nil
      end

    # Get location history
    {:ok, history} = Tracker.get_location_history(delivery["_id"], 50)

    # Get ETA if available
    eta = case Tracker.calculate_eta(delivery["_id"]) do
      {:ok, eta_seconds} -> eta_seconds
      _ -> nil
    end

    push(socket, "delivery_details", %{
      delivery: delivery,
      latest_location: latest_location,
      location_history: history,
      eta_seconds: eta
    })

    {:noreply, socket}
  end

  def handle_in("location_update", %{"latitude" => lat, "longitude" => lng}, socket) do
    # Only delivery person can update location
    if socket.assigns.user_role == :delivery_person do
      delivery_id = socket.assigns.delivery_id

      case Tracker.record_location(delivery_id, lat, lng) do
        {:ok, location} ->
          # Broadcast to all subscribers
          broadcast_location_update(socket, location)

          # Calculate and broadcast ETA update
          broadcast_eta_update(socket, delivery_id)

          {:reply, :ok, socket}

        {:error, _} ->
          {:reply, {:error, %{reason: "location_update_failed"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  def handle_in("update_status", %{"status" => status}, socket) do
    delivery_id = socket.assigns.delivery_id
    user_role = socket.assigns.user_role

    # Check authorization
    authorized? = user_role in [:shop_owner, :delivery_person] ||
                  (user_role == :customer && status in ["delivered", "cancelled"])

    if authorized? do
      case Delivery.update_status(delivery_id, status) do
        :ok ->
          # Get updated delivery
          {:ok, delivery} = Delivery.get(delivery_id)

          # Broadcast status change
          broadcast_status_change(socket, status, delivery)

          {:reply, :ok, socket}

        _ ->
          {:reply, {:error, %{reason: "status_update_failed"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  defp broadcast_location_update(socket, location) do
    broadcast!(socket, "location_updated", %{
      latitude: location["latitude"],
      longitude: location["longitude"],
      recorded_at: location["recorded_at"],
      speed: calculate_speed(socket.assigns.delivery_id) # Optional
    })
  end

  defp broadcast_status_change(socket, status, delivery) do
    broadcast!(socket, "status_changed", %{
      status: status,
      delivered_at: delivery["delivered_at"],
      updated_at: delivery["updated_at"]
    })
  end

  defp broadcast_eta_update(socket, delivery_id) do
    case Tracker.calculate_eta(delivery_id) do
      {:ok, eta_seconds} ->
        broadcast!(socket, "eta_updated", %{eta_seconds: eta_seconds})

      _ ->
        :ok
    end
  end

  defp calculate_speed(delivery_id) do
    # Implementation similar to Tracker.calculate_eta
    # Returns speed in km/h
    nil # Simplified for brevity
  end

  def handle_in("get_eta", _params, socket) do
    delivery_id = socket.assigns.delivery_id

    case Tracker.calculate_eta(delivery_id) do
      {:ok, eta_seconds} ->
        {:reply, {:ok, %{eta_seconds: eta_seconds}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end
end
