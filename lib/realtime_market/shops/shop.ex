defmodule RealtimeMarket.Shops.Shop do
  @moduledoc """
  Shop domain logic.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.shops_collection()

  @doc """
  Creates a new shop.
  """
  def create(owner_id, attrs) do
    shop_id = Mongo.generate_uuid()
    now = Mongo.now()

    shop = %{
      "_id" => shop_id,
      "owner_id" => owner_id,
      "shop_name" => attrs.shop_name,
      "location" => attrs.location,
      "category" => attrs.category,
      "subscription_plan" => attrs.subscription_plan || "free",
      "created_at" => now,
      "updated_at" => now
    }

    case Mongo.insert_one(@collection, shop) do
      {:ok, _} -> {:ok, Map.put(shop, "id", shop_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets shop by ID.
  """
  def get(shop_id) do
    case Mongo.find_one(@collection, %{"_id" => shop_id}) do
      nil -> {:error, :not_found}
      shop -> {:ok, shop}
    end
  end

  @doc """
  Gets shops by owner ID.
  """
  def get_by_owner(owner_id) do
    shops = Mongo.find(@collection, %{"owner_id" => owner_id})
    {:ok, shops}
  end

  @doc """
  Checks if user owns shop.
  """
  def owns_shop?(user_id, shop_id) do
    case Mongo.find_one(@collection, %{"_id" => shop_id, "owner_id" => user_id}) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Updates shop subscription.
  """
  def update_subscription(shop_id, plan) do
    Mongo.update_one(@collection, %{"_id" => shop_id}, %{
      "$set" => %{
        "subscription_plan" => plan,
        "updated_at" => Mongo.now()
      }
    })
  end
end
