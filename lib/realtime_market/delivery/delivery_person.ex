defmodule RealtimeMarket.Delivery.DeliveryPerson do
  @moduledoc """
  Delivery Person schema and logic.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.delivery_persons_collection()

  @doc """
  Creates a new delivery person.
  """
  def create(attrs) do
    delivery_person_id = Mongo.generate_uuid()
    now = Mongo.now()

    delivery_person = %{
      "_id" => delivery_person_id,
      "name" => attrs.name,
      "phone" => attrs.phone,
      "email" => attrs.email,
      "vehicle_type" => attrs.vehicle_type,
      "current_location" => attrs.current_location || %{},
      "is_available" => true,
      "created_at" => now,
      "updated_at" => now
    }

    case Mongo.insert_one(@collection, delivery_person) do
      {:ok, _} -> {:ok, Map.put(delivery_person, "id", delivery_person_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets delivery person by ID.
  """
  def get(delivery_person_id) do
    case Mongo.find_one(@collection, %{"_id" => delivery_person_id}) do
      nil -> {:error, :not_found}
      delivery_person -> {:ok, delivery_person}
    end
  end

  @doc """
  Updates delivery person location.
  """
  def update_location(delivery_person_id, latitude, longitude) do
    Mongo.update_one(@collection, %{"_id" => delivery_person_id}, %{
      "$set" => %{
        "current_location" => %{
          "latitude" => latitude,
          "longitude" => longitude,
          "updated_at" => Mongo.now()
        },
        "updated_at" => Mongo.now()
      }
    })
  end

  @doc """
  Finds available delivery persons near location.
  """
  def find_available_nearby(latitude, longitude, _radius_km \\ 10) do

    Mongo.find(@collection, %{
      "is_available" => true,
      "current_location.latitude" => %{
        "$gte" => latitude - 0.1,
        "$lte" => latitude + 0.1
      },
      "current_location.longitude" => %{
        "$gte" => longitude - 0.1,
        "$lte" => longitude + 0.1
      }
    })
  end

  @doc """
  Marks delivery person as available/unavailable.
  """
  def set_availability(delivery_person_id, is_available) do
    Mongo.update_one(@collection, %{"_id" => delivery_person_id}, %{
      "$set" => %{
        "is_available" => is_available,
        "updated_at" => Mongo.now()
      }
    })
  end
end
