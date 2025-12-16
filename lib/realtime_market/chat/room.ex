defmodule RealtimeMarket.Chat.Room do
  @moduledoc """
  Chat room domain logic.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.chat_rooms_collection()

  @room_types ["user_user", "user_shop", "user_ai"]

  @doc """
  Creates a new chat room.
  """
  def create(type, participant_ids \\ []) when type in @room_types do
    room_id = Mongo.generate_uuid()
    now = Mongo.now()

    room = %{
      "_id" => room_id,
      "type" => type,
      "participant_ids" => participant_ids,
      "created_at" => now,
      "updated_at" => now
    }

    case Mongo.insert_one(@collection, room) do
      {:ok, _} -> {:ok, Map.put(room, "id", room_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets or creates a user-shop chat room.
  """
  def get_or_create_user_shop(user_id, shop_id) do
    participant_ids = [user_id, shop_id]

    case Mongo.find_one(@collection, %{
           "type" => "user_shop",
           "participant_ids" => %{"$all" => participant_ids}
         }) do
      nil ->
        create("user_shop", participant_ids)

      room ->
        {:ok, room}
    end
  end

  @doc """
  Gets room by ID.
  """
  def get(room_id) do
    case Mongo.find_one(@collection, %{"_id" => room_id}) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  @doc """
  Gets user's chat rooms.
  """
  def get_user_rooms(user_id) do
    rooms =
      Mongo.find(@collection, %{
        "$or" => [
          %{"type" => "user_user", "participant_ids" => user_id},
          %{"type" => "user_shop", "participant_ids" => user_id},
          %{"type" => "user_ai", "participant_ids" => user_id}
        ]
      })

    {:ok, rooms}
  end

  @doc """
  Adds participant to room.
  """
  def add_participant(room_id, user_id) do
    Mongo.update_one(@collection, %{"_id" => room_id}, %{
      "$addToSet" => %{"participant_ids" => user_id},
      "$set" => %{"updated_at" => Mongo.now()}
    })
  end
end
