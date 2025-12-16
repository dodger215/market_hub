defmodule RealtimeMarketWeb.FeedController do
  use RealtimeMarketWeb, :controller

  alias RealtimeMarket.Shops.ProductFeed
  alias RealtimeMarket.Shops.Product

  @doc """
  Get personalized feed for user.
  GET /api/feed
  """
  def index(conn, params) do
    user_id = conn.assigns.current_user_id
    limit = params |> Map.get("limit", "20") |> String.to_integer()
    skip = params |> Map.get("skip", "0") |> String.to_integer()

    case ProductFeed.get_feed_for_user(user_id, limit, skip) do
      {:ok, feed_items} ->
        json(conn, %{
          success: true,
          data: feed_items,
          count: length(feed_items),
          has_more: length(feed_items) == limit
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  Get trending products.
  GET /api/feed/trending
  """
  def trending(conn, params) do
    limit = params |> Map.get("limit", "20") |> String.to_integer()

    trending_products = ProductFeed.get_trending(limit)

    json(conn, %{
      success: true,
      data: trending_products,
      count: length(trending_products)
    })
  end

  @doc """
  Get a specific product from feed.
  GET /api/feed/:product_id
  """
  def show(conn, %{"product_id" => product_id}) do
    case Product.get(product_id) do
      {:ok, product} ->
        # Enrich with media
        {:ok, media} = ProductFeed.get_product_media_for_player(product_id)
        
        enriched_product = Map.merge(product, %{
          "media" => media
        })

        json(conn, %{
          success: true,
          data: enriched_product
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Product not found"})
    end
  end

  @doc """
  Get media for a product.
  GET /api/feed/:product_id/media
  """
  def media(conn, %{"product_id" => product_id}) do
    case ProductFeed.get_product_media_for_player(product_id) do
      {:ok, media} ->
        json(conn, %{
          success: true,
          data: media
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  Like a product.
  POST /api/feed/:product_id/like
  """
  def like(conn, %{"product_id" => product_id}) do
    user_id = conn.assigns.current_user_id

    case ProductFeed.record_engagement(product_id, user_id, "like") do
      {:ok, engagement} ->
        json(conn, %{
          success: true,
          message: "Product liked",
          engagement: engagement
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  Share a product.
  POST /api/feed/:product_id/share
  """
  def share(conn, %{"product_id" => product_id} = params) do
    user_id = conn.assigns.current_user_id
    platform = Map.get(params, "platform", "unknown")
    metadata = %{"platform" => platform}

    case ProductFeed.record_engagement(product_id, user_id, "share", metadata) do
      {:ok, engagement} ->
        json(conn, %{
          success: true,
          message: "Product shared",
          engagement: engagement
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  Save a product.
  POST /api/feed/:product_id/save
  """
  def save(conn, %{"product_id" => product_id}) do
    user_id = conn.assigns.current_user_id

    case ProductFeed.record_engagement(product_id, user_id, "save") do
      {:ok, engagement} ->
        json(conn, %{
          success: true,
          message: "Product saved",
          engagement: engagement
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end
end
