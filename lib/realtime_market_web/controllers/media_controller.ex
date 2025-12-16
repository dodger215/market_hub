defmodule RealtimeMarketWeb.MediaController do
  use RealtimeMarketWeb, :controller

  alias RealtimeMarket.Accounts.Auth
  alias RealtimeMarket.Media.MediaStorage

  def upload(conn, %{"product_id" => product_id, "file" => file, "type" => media_type}) do
    with {:ok, user} <- Auth.authenticate_token(conn),
         :ok <- authorize_product_upload(user, product_id) do

      case MediaStorage.upload_product_media(product_id, file, media_type) do
        {:ok, media} ->
          json(conn, %{success: true, media: media})

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: reason})
      end
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})
    end
  end

  defp authorize_product_upload(user, product_id) do
    # Check if user owns the product's shop
    product = RealtimeMarket.Mongo.find_one(
      RealtimeMarket.Mongo.products_collection(),
      %{"_id" => product_id}
    )

    if product do
      shop = RealtimeMarket.Mongo.find_one(
        RealtimeMarket.Mongo.shops_collection(),
        %{"_id" => product["shop_id"]}
      )

      if shop && shop["owner_id"] == user["_id"] do
        :ok
      else
        {:error, :forbidden}
      end
    else
      {:error, :not_found}
    end
  end
end
