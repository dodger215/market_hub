defmodule RealtimeMarket.Mongo do
  @moduledoc """
  Supervised MongoDB connection and query interface using the mongodb package.
  """

  use Supervisor

  alias Mongo

  @collection_users "users"
  @collection_delivery_persons "delivery_persons"
  @collection_shops "shops"
  @collection_products "products"
  @collection_product_media "product_media"
  @collection_product_variances "product_variances"
  @collection_chat_rooms "chat_rooms"
  @collection_messages "messages"
  @collection_deliveries "deliveries"
  @collection_delivery_locations "delivery_locations"
  @collection_delivery_events "delivery_events"
  @collection_subscriptions "subscriptions"

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Get MongoDB configuration
    mongo_config = Application.get_env(:realtime_market, :mongo)

    children = [
      {Mongo, [name: :mongo, database: mongo_config[:database], seeds: mongo_config[:seeds]]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Collection name helpers
  def users_collection, do: @collection_users
  def delivery_persons_collection, do: @collection_delivery_persons
  def shops_collection, do: @collection_shops
  def products_collection, do: @collection_products
  def product_media_collection, do: @collection_product_media
  def product_variances_collection, do: @collection_product_variances
  def chat_rooms_collection, do: @collection_chat_rooms
  def messages_collection, do: @collection_messages
  def deliveries_collection, do: @collection_deliveries
  def delivery_locations_collection, do: @collection_delivery_locations
  def delivery_events_collection, do: @collection_delivery_events
  def subscriptions_collection, do: @collection_subscriptions

  # Generic CRUD operations
  def insert_one(collection, document) do
    Mongo.insert_one(:mongo, collection, document)
  end

  def find_one(collection, filter, opts \\ []) do
    Mongo.find_one(:mongo, collection, filter, opts)
  end

  def find(collection, filter, opts \\ []) do
    Mongo.find(:mongo, collection, filter, opts)
    |> Enum.to_list()
  end

  def update_one(collection, filter, update) do
    Mongo.update_one(:mongo, collection, filter, update)
  end

  def delete_one(collection, filter) do
    Mongo.delete_one(:mongo, collection, filter)
  end

  def delete_many(collection, filter) do
    Mongo.delete_many(:mongo, collection, filter)
  end

  def aggregate(collection, pipeline) do
    Mongo.aggregate(:mongo, collection, pipeline, [])
    |> Enum.to_list()
  end

  # UUID generation helper
  def generate_uuid do
    UUID.uuid4()
  end

  # Timestamp helpers
  def now do
    DateTime.utc_now()
  end

  def timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
