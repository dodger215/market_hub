defmodule RealtimeMarket.Delivery.Tracker do
  @moduledoc """
  Real-time delivery tracking logic.
  """

  alias RealtimeMarket.Mongo
  alias RealtimeMarket.Delivery.Geo

  @collection Mongo.delivery_locations_collection()

  @doc """
  Records a location update for a delivery.
  """
  def record_location(delivery_id, latitude, longitude) do
    location_id = Mongo.generate_uuid()
    now = Mongo.now()

    location = %{
      "_id" => location_id,
      "delivery_id" => delivery_id,
      "latitude" => Decimal.new(latitude),
      "longitude" => Decimal.new(longitude),
      "recorded_at" => now
    }

    case Mongo.insert_one(@collection, location) do
      {:ok, _} ->
        # Check for nearby status
        check_nearby_status(delivery_id, latitude, longitude)
        {:ok, Map.put(location, "id", location_id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_nearby_status(delivery_id, latitude, longitude) do
    # Get destination coordinates (in production, fetch from delivery)
    destination = {40.7128, -74.0060} # Example: NYC

    distance = Geo.haversine_distance({latitude, longitude}, destination)

    if distance < 0.1 do # 100 meters
      # Update status to "arrived" if not already
      RealtimeMarket.Delivery.Delivery.update_status(delivery_id, "arrived")
      create_nearby_event(delivery_id)
    end
  end

  defp create_nearby_event(delivery_id) do
    event_id = Mongo.generate_uuid()

    event = %{
      "_id" => event_id,
      "delivery_id" => delivery_id,
      "event_type" => "nearby",
      "message" => "Driver is nearby!",
      "created_at" => Mongo.now()
    }

    Mongo.insert_one(Mongo.delivery_events_collection(), event)
  end

  @doc """
  Gets location history for a delivery.
  """
  def get_location_history(delivery_id, limit \\ 100) do
    locations =
      Mongo.find(@collection, %{"delivery_id" => delivery_id},
        sort: %{"recorded_at" => -1},
        limit: limit
      )

    {:ok, Enum.reverse(locations)}
  end

  @doc """
  Gets latest location for a delivery.
  """
  def get_latest_location(delivery_id) do
    case Mongo.find_one(@collection, %{"delivery_id" => delivery_id},
           sort: %{"recorded_at" => -1}
         ) do
      nil -> {:error, :not_found}
      location -> {:ok, location}
    end
  end

  @doc """
  Calculates estimated time of arrival.
  """
  def calculate_eta(delivery_id) do
    # Get last 2 locations to calculate speed
    case get_location_history(delivery_id, 2) do
      {:ok, [current, previous]} ->
        distance = Geo.haversine_distance(
          {current["latitude"], current["longitude"]},
          {previous["latitude"], previous["longitude"]}
        )

        time_diff = DateTime.diff(current["recorded_at"], previous["recorded_at"])

        if time_diff > 0 do
          speed = distance / time_diff # km per second

          # Get remaining distance to destination
          destination = {40.7128, -74.0060}
          remaining = Geo.haversine_distance(
            {current["latitude"], current["longitude"]},
            destination
          )

          eta_seconds = if speed > 0, do: round(remaining / speed), else: nil
          {:ok, eta_seconds}
        else
          {:error, :insufficient_data}
        end

      _ ->
        {:error, :insufficient_data}
    end
  end
end
