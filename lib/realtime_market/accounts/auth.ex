defmodule RealtimeMarket.Accounts.Auth do
  @moduledoc """
  Authentication module for OTP and JWT handling.
  """

  alias RealtimeMarket.Accounts.{User, JWT}
  alias RealtimeMarket.Mongo

  @otp_collection "otp_tokens"
  @otp_expiry_seconds 600  # 10 minutes

  @doc """
  Generates OTP for a phone number.
  """
  def generate_otp(phone_number) do
    # Clean phone number
    clean_phone = String.replace(phone_number, ~r/\D/, "")

    # Generate 6-digit OTP
    otp = :rand.uniform(1_000_000) - 1
    |> Integer.to_string()
    |> String.pad_leading(6, "0")

    # Store OTP
    otp_id = Mongo.generate_uuid()
    now = Mongo.now()

    otp_doc = %{
      "_id" => otp_id,
      "phone_number" => clean_phone,
      "otp" => otp,
      "created_at" => now,
      "expires_at" => DateTime.add(now, @otp_expiry_seconds, :second)
    }

    # Delete old OTPs for this phone
    Mongo.delete_many(@otp_collection, %{"phone_number" => clean_phone})

    # Insert new OTP
    case Mongo.insert_one(@otp_collection, otp_doc) do
      {:ok, _} ->
        # In production, send via SMS
        if Mix.env() == :dev do
          IO.puts("DEBUG OTP for #{clean_phone}: #{otp}")
        end
        {:ok, otp}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies OTP and generates JWT token.
  """
  def verify_otp(phone_number, otp) do
    clean_phone = String.replace(phone_number, ~r/\D/, "")

    # Find OTP
    case Mongo.find_one(@otp_collection, %{
      "phone_number" => clean_phone,
      "otp" => otp
    }) do
      nil ->
        {:error, :invalid_otp}

      otp_doc ->
        # Check expiration
        if DateTime.compare(DateTime.utc_now(), otp_doc["expires_at"]) == :lt do
          # Get user
          case User.get_by_phone(clean_phone) do
            {:ok, user} ->
              # Generate JWT token
              token = JWT.generate(user["_id"])

              # Delete used OTP
              Mongo.delete_one(@otp_collection, %{"_id" => otp_doc["_id"]})

              {:ok, token, user}

            {:error, :not_found} ->
              # User doesn't exist yet (first-time registration)
              {:error, :user_not_found}
          end
        else
          # OTP expired
          Mongo.delete_one(@otp_collection, %{"_id" => otp_doc["_id"]})
          {:error, :expired}
        end
    end
  end

  @doc """
  Verifies JWT token from WebSocket connection.
  """
  def authenticate_socket(token) do
    case JWT.verify_jwt(token) do
      {:ok, user_id} ->
        case User.get_by_id(user_id) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, :user_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies JWT token (alias for verify_jwt).
  """
  def verify_jwt(token) do
    JWT.verify_jwt(token)
  end

   @doc """
  Generates a short-lived token for specific actions.
  """
  def generate_action_token(user_id, _action, expires_in_seconds \\ 300) do
    JWT.generate(user_id, div(expires_in_seconds, 3600))
  end

  @doc """
  Validates password (when you add password auth later).
  """
  def validate_password(password, hashed_password) do
    # Implement password validation with bcrypt or similar
    # For now, basic comparison
    password == hashed_password
  end
end
