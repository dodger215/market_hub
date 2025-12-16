defmodule RealtimeMarket.Shops.ProductFeed do
  @moduledoc """
  Instagram Reels-style product feed system.
  """

  alias RealtimeMarket.Mongo
  alias RealtimeMarket.Accounts.Follow
  alias RealtimeMarket.Shops.Product

  @products_collection Mongo.products_collection()
  @media_collection Mongo.product_media_collection()

  @doc """
  Get personalized product feed for user (Reels style).
  """
  def get_feed_for_user(user_id, limit \\ 20, skip \\ 0) do
    # 1. Get users/shops the user follows
    {:ok, following} = Follow.get_following(user_id)

    following_ids = Enum.map(following, fn f -> f["following_id"] end)

    # 2. Query products from followed shops + popular products
    feed_query = %{
      "$or" => [
        %{"shop_id" => %{"$in" => following_ids}},
        %{"popularity_score" => %{"$gte" => 50}} # Popular products
      ]
    }

    feed_items = Mongo.find(@products_collection, feed_query,
      sort: %{
        "created_at" => -1,
        "popularity_score" => -1
      },
      limit: limit,
      skip: skip
    )

    # 3. Enrich with media
    enriched_items = Enum.map(feed_items, fn product ->
      media = get_product_media(product["_id"])
      shop_info = get_shop_info(product["shop_id"])

      Map.merge(product, %{
        "media" => media,
        "shop" => shop_info,
        "type" => determine_media_type(media)
      })
    end)

    # 4. Sort by engagement score
    sorted_items = Enum.sort_by(enriched_items, &calculate_engagement_score(&1), :desc)

    {:ok, sorted_items}
  end

  @doc """
  Get trending products (for Explore page).
  """
  def get_trending(limit \\ 20) do
    pipeline = [
      %{"$match" => %{"created_at" => %{"$gte" => DateTime.add(DateTime.utc_now(), -7, :day)}}},
      %{"$sort" => %{"popularity_score" => -1, "views" => -1}},
      %{"$limit" => limit},
      %{"$lookup" => %{
        "from" => "product_media",
        "localField" => "_id",
        "foreignField" => "product_id",
        "as" => "media"
      }},
      %{"$lookup" => %{
        "from" => "shops",
        "localField" => "shop_id",
        "foreignField" => "_id",
        "as" => "shop"
      }},
      %{"$addFields" => %{
        "shop" => %{"$arrayElemAt" => ["$shop", 0]},
        "has_video" => %{"$gt" => [%{"$size" => %{"$filter" => %{
          "input" => "$media",
          "as" => "m",
          "cond" => %{"$eq" => ["$$m.image.media_type", "video"]}
        }}}, 0]}
      }},
      %{"$sort" => %{"has_video" => -1, "popularity_score" => -1}} # Prioritize videos
    ]

    Mongo.aggregate(@products_collection, pipeline)
  end

  @doc """
  Record engagement (view, like, share).
  """
  def record_engagement(product_id, user_id, engagement_type, metadata \\ %{}) do
    engagement_id = Mongo.generate_uuid()
    now = Mongo.now()

    engagement = %{
      "_id" => engagement_id,
      "product_id" => product_id,
      "user_id" => user_id,
      "type" => engagement_type,
      "metadata" => metadata,
      "created_at" => now
    }

    Mongo.insert_one(Mongo.engagements_collection(), engagement)

    # Update product popularity score
    update_popularity_score(product_id, engagement_type)

    {:ok, engagement}
  end

  @doc """
  Get product media for Reels player.
  """
  def get_product_media_for_player(product_id) do
    media = Mongo.find(@media_collection, %{"product_id" => product_id},
      sort: %{"created_at" => 1}
    )

    # Add audio track if available
    media_with_audio = Enum.map(media, fn item ->
      audio_track = get_audio_track_for_product(product_id)
      Map.put(item, "audio", audio_track)
    end)

    {:ok, media_with_audio}
  end

  @doc """
  Add audio to product media.
  """
  def add_audio_to_product(product_id, audio_url, duration_seconds \\ nil) do
    audio_id = Mongo.generate_uuid()

    audio = %{
      "_id" => audio_id,
      "product_id" => product_id,
      "type" => "audio",
      "url" => audio_url,
      "duration_seconds" => duration_seconds,
      "created_at" => Mongo.now()
    }

    Mongo.insert_one(Mongo.audio_collection(), audio)
    {:ok, audio}
  end

  defp get_product_media(product_id) do
    Mongo.find(@media_collection, %{"product_id" => product_id},
      sort: %{"created_at" => 1}
    )
  end

  defp get_shop_info(shop_id) do
    case Mongo.find_one(Mongo.shops_collection(), %{"_id" => shop_id}) do
      nil -> %{}
      shop -> %{
        "id" => shop["_id"],
        "name" => shop["shop_name"],
        "avatar" => shop["avatar_url"]
      }
    end
  end

  defp determine_media_type(media) do
    has_video = Enum.any?(media, fn m ->
      m["image"]["media_type"] == "video"
    end)

    if has_video, do: "video", else: "image"
  end

  defp calculate_engagement_score(product) do
    base_score = product["popularity_score"] || 0
    views = product["views"] || 0
    likes = product["likes"] || 0
    shares = product["shares"] || 0
    recency = DateTime.diff(DateTime.utc_now(), product["created_at"])

    # Formula: (likes * 2 + shares * 3 + views * 0.1) / (recency_hours + 1)
    recency_hours = max(recency / 3600, 1)
    (likes * 2 + shares * 3 + views * 0.1) / recency_hours + base_score
  end

  defp update_popularity_score(product_id, engagement_type) do
    score_increment = case engagement_type do
      "view" -> 1
      "like" -> 5
      "share" -> 10
      "save" -> 3
      "comment" -> 4
      _ -> 1
    end

    Mongo.update_one(@products_collection, %{"_id" => product_id}, %{
      "$inc" => %{"popularity_score" => score_increment},
      "$set" => %{"updated_at" => Mongo.now()}
    })
  end

  defp get_audio_track_for_product(product_id) do
    case Mongo.find_one(Mongo.audio_collection(), %{"product_id" => product_id}) do
      nil -> nil
      audio -> %{
        "url" => audio["url"],
        "duration" => audio["duration_seconds"]
      }
    end
  end
end
