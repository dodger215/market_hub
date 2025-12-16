defmodule RealtimeMarket.Accounts.User do
  @moduledoc """
  User domain logic and MongoDB operations.
  """

  alias RealtimeMarket.Mongo

  @collection Mongo.users_collection()

  @doc """
  Creates a new user.
  """
  def create(attrs) do
    user_id = Mongo.generate_uuid()
    now = Mongo.now()

    user = %{
      "_id" => user_id,
      "phone_number" => attrs.phone_number,
      "username" => attrs.username,
      "created_at" => now,
      "last_login" => now,
      "updated_at" => now
    }

    case Mongo.insert_one(@collection, user) do
      {:ok, _} -> {:ok, Map.put(user, "id", user_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Finds a user by phone number.
  """
  def get_by_phone(phone_number) do
    case Mongo.find_one(@collection, %{"phone_number" => phone_number}) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Finds a user by username.
  """
  def get_by_username(username) do
    case Mongo.find_one(@collection, %{"username" => username}) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Finds a user by ID.
  """
  def get(id) do
    case Mongo.find_one(@collection, %{"_id" => id}) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Updates user's last login timestamp.
  """
  def update_last_login(user_id) do
    Mongo.update_one(@collection, %{"_id" => user_id}, %{
      "$set" => %{"last_login" => Mongo.now(), "updated_at" => Mongo.now()}
    })
  end
end
