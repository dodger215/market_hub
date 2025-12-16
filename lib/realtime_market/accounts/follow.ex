defmodule RealtimeMarket.Accounts.Follow do
  @moduledoc """
  User follow system for following shops/users.
  """

  alias RealtimeMarket.Mongo

  @follows_collection Mongo.follows_collection()

  @doc """
  Follow a user or shop.
  """
  def follow(follower_id, following_id, following_type \\ "user") when following_type in ["user", "shop"] do
    follow_id = Mongo.generate_uuid()
    now = Mongo.now()

    follow = %{
      "_id" => follow_id,
      "follower_id" => follower_id,
      "following_id" => following_id,
      "following_type" => following_type,
      "created_at" => now
    }

    case Mongo.insert_one(@follows_collection, follow) do
      {:ok, _} ->
        # Create notification
        create_follow_notification(follower_id, following_id, following_type)
        {:ok, follow}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unfollow a user or shop.
  """
  def unfollow(follower_id, following_id) do
    Mongo.delete_one(@follows_collection, %{
      "follower_id" => follower_id,
      "following_id" => following_id
    })
  end

  @doc """
  Check if user follows another user/shop.
  """
  def following?(follower_id, following_id) do
    case Mongo.find_one(@follows_collection, %{
      "follower_id" => follower_id,
      "following_id" => following_id
    }) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Get user's followers.
  """
  def get_followers(user_id) do
    followers = Mongo.find(@follows_collection, %{"following_id" => user_id})
    {:ok, followers}
  end

  @doc """
  Get who user is following.
  """
  def get_following(user_id) do
    following = Mongo.find(@follows_collection, %{"follower_id" => user_id})
    {:ok, following}
  end

  @doc """
  Get follower count.
  """
  def follower_count(user_id) do
    pipeline = [
      %{"$match" => %{"following_id" => user_id}},
      %{"$count" => "count"}
    ]

    case Mongo.aggregate(@follows_collection, pipeline) do
      [%{"count" => count}] -> count
      _ -> 0
    end
  end

  defp create_follow_notification(follower_id, following_id, following_type) do
    # Store notification in DB
    notification_id = Mongo.generate_uuid()

    notification = %{
      "_id" => notification_id,
      "user_id" => following_id,
      "type" => "follow",
      "data" => %{
        "follower_id" => follower_id,
        "following_type" => following_type
      },
      "read" => false,
      "created_at" => Mongo.now()
    }

    Mongo.insert_one(Mongo.notifications_collection(), notification)

    # Broadcast via WebSocket
    Phoenix.PubSub.broadcast(
      RealtimeMarket.PubSub,
      "notifications:#{following_id}",
      {:new_notification, notification}
    )
  end
end
