defmodule RealtimeMarket.Delivery.Geo do
  @moduledoc """
  Geographic calculations using Haversine formula.
  """

  @earth_radius_km 6371
  @earth_radius_miles 3959

  @doc """
  Calculates distance between two coordinates in kilometers.
  """
  def haversine_distance({lat1, lon1}, {lat2, lon2}, unit \\ :km) do
    # Convert to radians
    {lat1_rad, lon1_rad, lat2_rad, lon2_rad} = {
      degrees_to_radians(lat1),
      degrees_to_radians(lon1),
      degrees_to_radians(lat2),
      degrees_to_radians(lon2)
    }

    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(dlon / 2) * :math.sin(dlon / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    distance_km = @earth_radius_km * c

    case unit do
      :km -> distance_km
      :miles -> distance_km * 0.621371
      :meters -> distance_km * 1000
    end
  end

  defp degrees_to_radians(degrees) do
    degrees * :math.pi() / 180
  end

  @doc """
  Checks if location is within radius of target.
  """
  def within_radius?(location, target, radius_km) do
    distance = haversine_distance(location, target, :km)
    distance <= radius_km
  end

  @doc """
  Calculates bearing between two coordinates.
  """
  def bearing({lat1, lon1}, {lat2, lon2}) do
    {lat1_rad, lon1_rad, lat2_rad, lon2_rad} = {
      degrees_to_radians(lat1),
      degrees_to_radians(lon1),
      degrees_to_radians(lat2),
      degrees_to_radians(lon2)
    }

    dlon = lon2_rad - lon1_rad

    y = :math.sin(dlon) * :math.cos(lat2_rad)
    x = :math.cos(lat1_rad) * :math.sin(lat2_rad) -
        :math.sin(lat1_rad) * :math.cos(lat2_rad) * :math.cos(dlon)

    bearing_rad = :math.atan2(y, x)
    degrees = bearing_rad * 180 / :math.pi()
    (degrees + 360) |> rem(360)
  end
end
