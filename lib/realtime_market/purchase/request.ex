defmodule RealtimeMarket.Purchase.Request do
  @moduledoc """
  Purchase request system.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.purchase_requests_collection()

  @doc """
  Creates a new purchase request.
  """
  def create(shop_id, customer_id, attrs) do
    request_id = Mongo.generate_uuid()
    now = Mongo.now()

    request = %{
      "_id" => request_id,
      "shop_id" => shop_id,
      "customer_id" => customer_id,
      "status" => "pending",
      "items" => attrs[:items] || [],
      "delivery_info" => attrs[:delivery_info] || %{},
      "total_price" => attrs[:total_price],
      "customer_location" => attrs[:customer_location],
      "shop_location" => attrs[:shop_location],
      "payment_status" => "pending",
      "payment_method" => attrs[:payment_method] || "pay_on_delivery",
      "created_at" => now,
      "updated_at" => now,
      "delivered_at" => nil
    }

    case Mongo.insert_one(@collection, request) do
      {:ok, _} -> {:ok, Map.put(request, "id", request_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets pending requests for a shop.
  """
  def get_pending_for_shop(shop_id) do
    requests = Mongo.find(@collection, %{
      "shop_id" => shop_id,
      "status" => %{"$in" => ["pending", "confirmed", "ready_for_delivery"]}
    })
    {:ok, requests}
  end

  @doc """
  Gets request by ID.
  """
  def get(request_id) do
    case Mongo.find_one(@collection, %{"_id" => request_id}) do
      nil -> {:error, :not_found}
      request -> {:ok, request}
    end
  end

  @doc """
  Assigns delivery to a purchase request.
  """
  def assign_delivery(request_id, delivery_person_id, delivery_info) do
    Mongo.update_one(@collection, %{"_id" => request_id}, %{
      "$set" => %{
        "delivery_person_id" => delivery_person_id,
        "delivery_info" => delivery_info,
        "status" => "out_for_delivery",
        "updated_at" => Mongo.now()
      }
    })
  end

  @doc """
  Updates purchase request status.
  """
  def update_status(request_id, status) do
    Mongo.update_one(@collection, %{"_id" => request_id}, %{
      "$set" => %{
        "status" => status,
        "updated_at" => Mongo.now()
      }
    })
  end
end
