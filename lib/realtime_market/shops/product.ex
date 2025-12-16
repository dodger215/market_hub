defmodule RealtimeMarket.Shops.Product do
  @moduledoc """
  Product domain logic.
  """

  alias RealtimeMarket.Mongo

  @products_collection Mongo.products_collection()
  @media_collection Mongo.product_media_collection()
  @variances_collection Mongo.product_variances_collection()

  @doc """
  Creates a new product.
  """
  def create(shop_id, attrs) do
    product_id = Mongo.generate_uuid()
    now = Mongo.now()

    # Get next SKU for the shop
    sku = get_next_sku(shop_id)

    product = %{
      "_id" => product_id,
      "sku" => sku,
      "shop_id" => shop_id,
      "name" => attrs.name,
      "description" => attrs.description,
      "price" => Decimal.new(attrs.price),
      "stock_quantity" => attrs.stock_quantity,
      "created_at" => now,
      "updated_at" => now
    }

    case Mongo.insert_one(@products_collection, product) do
      {:ok, _} ->
        # Add media if provided
        if attrs.media do
          create_media(product_id, attrs.media)
        end

        # Add variances if provided
        if attrs.variances do
          create_variances(product_id, attrs.variances)
        end

        {:ok, Map.put(product, "id", product_id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_next_sku(shop_id) do
    pipeline = [
      %{"$match" => %{"shop_id" => shop_id}},
      %{"$group" => %{"_id" => nil, "max_sku" => %{"$max" => "$sku"}}}
    ]

    case Mongo.aggregate(@products_collection, pipeline) do
      [%{"max_sku" => max_sku}] when is_integer(max_sku) -> max_sku + 1
      _ -> 1
    end
  end

  defp create_media(product_id, media_list) do
    media_docs =
      Enum.map(media_list, fn media ->
        %{
          "_id" => Mongo.generate_uuid(),
          "product_id" => product_id,
          "image" => %{
            "media_type" => media.media_type,
            "tag" => media.tag,
            "url" => media.url
          },
          "created_at" => Mongo.now()
        }
      end)

    Enum.each(media_docs, &Mongo.insert_one(@media_collection, &1))
  end

  defp create_variances(product_id, variances) do
    variance_docs =
      Enum.map(variances, fn variance ->
        %{
          "_id" => Mongo.generate_uuid(),
          "product_id" => product_id,
          "name" => variance.name,
          "options" => variance.options,
          "created_at" => Mongo.now()
        }
      end)

    Enum.each(variance_docs, &Mongo.insert_one(@variances_collection, &1))
  end

  @doc """
  Gets products by shop ID.
  """
  def get_by_shop(shop_id) do
    products = Mongo.find(@products_collection, %{"shop_id" => shop_id})
    {:ok, products}
  end

  @doc """
  Gets product with media and variances.
  """
  def get_with_details(product_id) do
    case Mongo.find_one(@products_collection, %{"_id" => product_id}) do
      nil ->
        {:error, :not_found}

      product ->
        media = Mongo.find(@media_collection, %{"product_id" => product_id})
        variances = Mongo.find(@variances_collection, %{"product_id" => product_id})

        details = Map.merge(product, %{
          "media" => media,
          "variances" => variances
        })

        {:ok, details}
    end
  end

  @doc """
  Updates stock quantity.
  """
  def update_stock(product_id, delta) do
    Mongo.update_one(@products_collection, %{"_id" => product_id}, %{
      "$inc" => %{"stock_quantity" => delta},
      "$set" => %{"updated_at" => Mongo.now()}
    })
  end
end
