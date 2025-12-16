defmodule RealtimeMarketWeb.FollowController do
  use RealtimeMarketWeb, :controller

  alias RealtimeMarket.Accounts.{Auth, Follow, User}
  alias RealtimeMarket.Shops.Shop

  plug :authenticate when action in [:follow, :unfollow, :followers, :following]

  @doc """
  Follow a user or shop.
  POST /api/follow
  {
    "following_id": "user_or_shop_id",
    "type": "user" | "shop"
  }
  """
  def follow(conn, %{"following_id" => following_id, "type" => type}) do
    user_id = conn.assigns.current_user_id

    # Validate the entity being followed exists
    case validate_following_exists(following_id, type) do
      {:ok, _} ->
        case Follow.follow(user_id, following_id, type) do
          {:ok, follow} ->
            json(conn, %{
              success: true,
              data: %{
                id: follow["_id"],
                follower_id: user_id,
                following_id: following_id,
                type: type,
                created_at: follow["created_at"]
              },
              message: "Successfully followed"
            })

          {:error, :already_following} ->
            conn
            |> put_status(:conflict)
            |> json(%{error: "Already following"})

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Failed to follow"})
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "#{type} not found"})
    end
  end

  @doc """
  Unfollow a user or shop.
  POST /api/unfollow
  {
    "following_id": "user_or_shop_id"
  }
  """
  def unfollow(conn, %{"following_id" => following_id}) do
    user_id = conn.assigns.current_user_id

    Follow.unfollow(user_id, following_id)

    json(conn, %{
      success: true,
      message: "Successfully unfollowed"
    })
  end

  @doc """
  Get user's followers.
  GET /api/followers
  """
  def followers(conn, _params) do
    user_id = conn.assigns.current_user_id

    {:ok, followers} = Follow.get_followers(user_id)

    # Enrich follower data
    enriched_followers = Enum.map(followers, fn follower ->
      case User.get_by_id(follower["follower_id"]) do
        {:ok, user} ->
          %{
            id: user["_id"],
            username: user["username"],
            avatar: user["avatar"],
            is_following_back: Follow.following?(user["_id"], user_id),
            followed_at: follower["created_at"]
          }
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)

    json(conn, %{
      success: true,
      data: enriched_followers,
      count: length(enriched_followers)
    })
  end

  @doc """
  Get who user is following.
  GET /api/following
  """
  def following(conn, params) do
    user_id = conn.assigns.current_user_id
    type = Map.get(params, "type", "all") # "all", "user", "shop"

    {:ok, following} = Follow.get_following(user_id)

    # Filter by type if specified
    filtered_following = case type do
      "user" -> Enum.filter(following, &(&1["following_type"] == "user"))
      "shop" -> Enum.filter(following, &(&1["following_type"] == "shop"))
      _ -> following
    end

    # Enrich following data
    enriched_following = Enum.map(filtered_following, fn follow ->
      case follow["following_type"] do
        "user" ->
          case User.get_by_id(follow["following_id"]) do
            {:ok, user} ->
              %{
                id: user["_id"],
                username: user["username"],
                avatar: user["avatar"],
                type: "user",
                followed_at: follow["created_at"]
              }
            _ -> nil
          end

        "shop" ->
          case Shop.get(follow["following_id"]) do
            {:ok, shop} ->
              %{
                id: shop["_id"],
                name: shop["shop_name"],
                avatar: shop["avatar"],
                type: "shop",
                followed_at: follow["created_at"]
              }
            _ -> nil
          end
      end
    end)
    |> Enum.filter(& &1)

    json(conn, %{
      success: true,
      data: enriched_following,
      count: length(enriched_following)
    })
  end

  @doc """
  Check if user follows another user/shop.
  GET /api/follow/check/:following_id
  """
  def check(conn, %{"following_id" => following_id}) do
    user_id = conn.assigns.current_user_id

    is_following = Follow.following?(user_id, following_id)

    json(conn, %{
      success: true,
      data: %{
        is_following: is_following
      }
    })
  end

  @doc """
  Get follower/following counts.
  GET /api/follow/stats/:user_id?
  """
  def stats(conn, %{"user_id" => target_user_id}) do
    follower_count = Follow.follower_count(target_user_id)
    following_count = get_following_count(target_user_id)

    json(conn, %{
      success: true,
      data: %{
        follower_count: follower_count,
        following_count: following_count
      }
    })
  end

  def stats(conn, _params) do
    user_id = conn.assigns.current_user_id
    follower_count = Follow.follower_count(user_id)
    following_count = get_following_count(user_id)

    json(conn, %{
      success: true,
      data: %{
        follower_count: follower_count,
        following_count: following_count
      }
    })
  end

  defp validate_following_exists(following_id, type) do
    case type do
      "user" ->
        case User.get_by_id(following_id) do
          {:ok, _} -> {:ok, :user}
          _ -> {:error, :not_found}
        end

      "shop" ->
        case Shop.get(following_id) do
          {:ok, _} -> {:ok, :shop}
          _ -> {:error, :not_found}
        end

      _ ->
        {:error, :invalid_type}
    end
  end

  defp get_following_count(user_id) do
    pipeline = [
      %{"$match" => %{"follower_id" => user_id}},
      %{"$count" => "count"}
    ]

    case Mongo.aggregate(Mongo.follows_collection(), pipeline) do
      [%{"count" => count}] -> count
      _ -> 0
    end
  end

  # Authentication plug for protected routes
  defp authenticate(conn, _opts) do
    case get_auth_token(conn) do
      {:ok, token} ->
        case RealtimeMarket.Accounts.Auth.verify_jwt(token) do
          {:ok, user_id} ->
            assign(conn, :current_user_id, user_id)

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid token"})
            |> halt()
        end

      :error ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing authentication token"})
        |> halt()
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end
end
