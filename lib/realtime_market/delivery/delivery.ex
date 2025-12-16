defmodule RealtimeMarket.Delivery.Delivery do
  @moduledoc """
  Delivery domain logic.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.deliveries_collection()
  @delivery_persons_collection Mongo.delivery_persons_collection()

  @statuses ["assigned", "in_transit", "arrived", "delivered", "cancelled"]

  @doc """
  Creates a new delivery.
  """
  def create(shop_id, customer_id, delivery_person_id, attrs) do
    delivery_id = Mongo.generate_uuid()
    tracking_token = generate_tracking_token()
    now = Mongo.now()

    delivery = %{
      "_id" => delivery_id,
      "shop_id" => shop_id,
      "customer_id" => customer_id,
      "delivery_person_id" => delivery_person_id,
      "status" => "assigned",
      "tracking_token" => tracking_token,
      "created_at" => now,
      "updated_at" => now,
      "delivered_at" => nil
    }

    case Mongo.insert_one(@collection, delivery) do
      {:ok, _} ->
        # Create initial delivery event
        create_delivery_event(delivery_id, "assigned", "Delivery assigned to driver")
        {:ok, Map.put(delivery, "id", delivery_id), tracking_token}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_tracking_token do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> String.replace(~r/[+\/=]/, "")
    |> String.slice(0, 12)
  end

  @doc """
  Gets delivery by ID.
  """
  def get(delivery_id) do
    case Mongo.find_one(@collection, %{"_id" => delivery_id}) do
      nil -> {:error, :not_found}
      delivery -> {:ok, delivery}
    end
  end

  @doc """
  Gets delivery by tracking token.
  """
  def get_by_tracking_token(token) do
    case Mongo.find_one(@collection, %{"tracking_token" => token}) do
      nil -> {:error, :not_found}
      delivery -> {:ok, delivery}
    end
  end

  @doc """
  Updates delivery status.
  """
  def update_status(delivery_id, status) when status in @statuses do
    update = %{
      "$set" => %{
        "status" => status,
        "updated_at" => Mongo.now()
      }
    }

    if status == "delivered" do
      update = Map.put(update["$set"], "delivered_at", Mongo.now())
      Mongo.update_one(@collection, %{"_id" => delivery_id}, %{"$set" => update})
    else
      Mongo.update_one(@collection, %{"_id" => delivery_id}, update)
    end

    # Create status change event
    create_delivery_event(delivery_id, status, "Status changed to #{status}")
    :ok
  end

  @doc """
  Gets active deliveries for a delivery person.
  """
  def get_active_deliveries(delivery_person_id) do
    deliveries =
      Mongo.find(@collection, %{
        "delivery_person_id" => delivery_person_id,
        "status" => %{"$in" => ["assigned", "in_transit", "arrived"]}
      })

    {:ok, deliveries}
  end

  defp create_delivery_event(delivery_id, event_type, message) do
    event_id = Mongo.generate_uuid()

    event = %{
      "_id" => event_id,
      "delivery_id" => delivery_id,
      "event_type" => event_type,
      "message" => message,
      "created_at" => Mongo.now()
    }

    Mongo.insert_one(Mongo.delivery_events_collection(), event)
  end
end
