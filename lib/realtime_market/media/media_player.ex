defmodule RealtimeMarket.Media.MediaPlayer do
  @moduledoc """
  Media player for handling video/image/audio playback in feed.
  """

  alias RealtimeMarket.Mongo

  @doc """
  Get media playlist for a product (videos with audio).
  """
  def get_product_playlist(product_id) do
    # Get all media for product
    media = Mongo.find(Mongo.product_media_collection(), %{"product_id" => product_id},
      sort: %{"created_at" => 1}
    )

    # Get audio tracks
    audio = Mongo.find(Mongo.audio_collection(), %{"product_id" => product_id})

    # Group media by type and prepare playlist
    playlist = Enum.map(media, fn item ->
      %{
        id: item["_id"],
        type: item["image"]["media_type"],
        url: item["image"]["url"],
        thumbnail_url: item["thumbnail_url"] || item["image"]["url"],
        duration: Map.get(item["metadata"] || %{}, "duration", 0),
        audio_track: get_audio_for_media(item, audio),
        created_at: item["created_at"]
      }
    end)

    {:ok, playlist}
  end

  @doc """
  Generate signed URL for media (for secure access).
  """
  def generate_signed_url(media_url, _expires_in \\ 3600) do
    # In production, use CloudFront/S3 signed URLs
    # For now, return original URL
    {:ok, media_url}
  end

  @doc """
  Get recommended next media item based on user preferences.
  """
  def get_next_recommendation(current_product_id, user_id) do
    # Get user's viewing history
    views = Mongo.find(Mongo.engagements_collection(), %{
      "user_id" => user_id,
      "type" => "view"
    })

    # Get similar products (based on category, shop, etc.)
    current_product = Mongo.find_one(Mongo.products_collection(), %{
      "_id" => current_product_id
    })

    if current_product do
      # Find products from same shop or similar category
      similar_products = Mongo.find(Mongo.products_collection(), %{
        "$or" => [
          %{"shop_id" => current_product["shop_id"]},
          %{"category" => current_product["category"]}
        ],
        "_id" => %{"$ne" => current_product_id}
      },
      limit: 10,
      sort: %{"popularity_score" => -1})

      # Filter out already viewed products
      viewed_ids = Enum.map(views, & &1["product_id"])
      new_products = Enum.filter(similar_products, fn p ->
        p["_id"] not in viewed_ids
      end)

      case new_products do
        [] -> get_trending_product(current_product_id)
        [next | _] -> {:ok, next}
      end
    else
      get_trending_product(nil)
    end
  end

  @doc """
  Handle media buffering and quality switching.
  """
  def get_media_qualities(media_url) do
    # Return available qualities for adaptive streaming
    # This would integrate with HLS/DASH in production
    [
      %{quality: "1080p", url: "#{media_url}?quality=1080", bitrate: 4000},
      %{quality: "720p", url: "#{media_url}?quality=720", bitrate: 2500},
      %{quality: "480p", url: "#{media_url}?quality=480", bitrate: 1000},
      %{quality: "360p", url: "#{media_url}?quality=360", bitrate: 600}
    ]
  end

  @doc """
  Record playback statistics.
  """
  def record_playback_stats(product_id, user_id, stats) do
    playback_id = Mongo.generate_uuid()

    playback_stats = %{
      "_id" => playback_id,
      "product_id" => product_id,
      "user_id" => user_id,
      "stats" => stats,
      "created_at" => Mongo.now()
    }

    Mongo.insert_one("playback_stats", playback_stats)

    # Update product views
    Mongo.update_one(Mongo.products_collection(), %{"_id" => product_id}, %{
      "$inc" => %{"views" => 1, "watch_time" => Map.get(stats, :watch_time, 0)}
    })

    {:ok, playback_stats}
  end

  defp get_audio_for_media(media_item, audio_tracks) do
    # Find matching audio track based on media type or duration
    Enum.find(audio_tracks, fn audio ->
      audio["metadata"]["media_id"] == media_item["_id"] ||
      audio["metadata"]["duration"] == Map.get(media_item["metadata"] || %{}, "duration")
    end)
  end

  defp get_trending_product(exclude_id) do
    # Get a trending product as fallback
    pipeline = [
      %{"$match" => %{"_id" => %{"$ne" => exclude_id}}},
      %{"$sort" => %{"popularity_score" => -1}},
      %{"$limit" => 1}
    ]

    case Mongo.aggregate(Mongo.products_collection(), pipeline) do
      [product | _] -> {:ok, product}
      [] -> {:error, :no_products}
    end
  end
end
