defmodule RealtimeMarket.Chat.Message do
  @moduledoc """
  Chat message domain logic.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.messages_collection()

  @sender_types ["user", "ai", "system"]

  @doc """
  Creates a new message.
  """
  def create(room_id, sender_type, sender_id, content)
      when sender_type in @sender_types do
    message_id = Mongo.generate_uuid()
    now = Mongo.now()

    message = %{
      "_id" => message_id,
      "chat_room_id" => room_id,
      "sender_type" => sender_type,
      "sender_id" => sender_id,
      "content" => content,
      "created_at" => now
    }

    case Mongo.insert_one(@collection, message) do
      {:ok, _} ->
        # Update room's updated_at
        update_room_timestamp(room_id)
        {:ok, Map.put(message, "id", message_id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_room_timestamp(room_id) do
    Mongo.update_one(
      Mongo.chat_rooms_collection(),
      %{"_id" => room_id},
      %{"$set" => %{"updated_at" => Mongo.now()}}
    )
  end

  @doc """
  Gets messages for a room with pagination.
  """
  def get_room_messages(room_id, limit \\ 50, before_id \\ nil) do
    query = %{"chat_room_id" => room_id}

    query =
      if before_id do
        case get(before_id) do
          {:ok, before_message} ->
            Map.put(query, "created_at", %{"$lt" => before_message["created_at"]})

          _ ->
            query
        end
      else
        query
      end

    messages =
      Mongo.find(@collection, query,
        sort: %{"created_at" => -1},
        limit: limit
      )

    {:ok, Enum.reverse(messages)}
  end

  @doc """
  Gets a single message by ID.
  """
  def get(message_id) do
    case Mongo.find_one(@collection, %{"_id" => message_id}) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  @doc """
  Creates a system message.
  """
  def create_system_message(room_id, content) do
    create(room_id, "system", nil, content)
  end

  @doc """
  Creates an AI message.
  """
  def create_ai_message(room_id, content) do
    create(room_id, "ai", "ai_system", content)
  end
end
