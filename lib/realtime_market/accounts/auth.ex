defmodule RealtimeMarket.Accounts.Auth do
  @moduledoc """
  Authentication service with OTP.
  """

  alias RealtimeMarket.Accounts.User
  alias RealtimeMarket.Accounts.JWT

  @otp_length 6
  @otp_validity_minutes 10

  # In-memory OTP store (use Redis in production)
  @otp_store :ets.new(:otp_store, [:set, :public, :named_table])

  @doc """
  Generates and stores OTP for phone number.
  """
  def generate_otp(phone_number) do
    otp = Enum.map(1..@otp_length, fn _ -> Enum.random(0..9) end) |> Enum.join()
    expires_at = DateTime.utc_now() |> DateTime.add(@otp_validity_minutes * 60, :second)

    :ets.insert(@otp_store, {phone_number, otp, expires_at})

    # In production, send via SMS service
    {:ok, otp}
  end

  @doc """
  Verifies OTP and returns JWT on success.
  """
  def verify_otp(phone_number, otp) do
    case :ets.lookup(@otp_store, phone_number) do
      [{^phone_number, ^otp, expires_at}] ->
        if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          :ets.delete(@otp_store, phone_number)

          # Get or create user
          case User.get_by_phone(phone_number) do
            {:ok, user} ->
              token = JWT.generate(user["_id"])
              User.update_last_login(user["_id"])
              {:ok, token, user}

            {:error, :not_found} ->
              # Auto-create user with random username
              username = "user_#{String.slice(phone_number, -8..-1)}"
              {:ok, user} = User.create(%{phone_number: phone_number, username: username})
              token = JWT.generate(user["_id"])
              {:ok, token, user}
          end
        else
          :ets.delete(@otp_store, phone_number)
          {:error, :expired}
        end

      _ ->
        {:error, :invalid_otp}
    end
  end

  @doc """
  Verifies JWT and extracts user_id.
  """
  def verify_jwt(token) do
    case JWT.verify(token) do
      {:ok, user_id, _payload} -> {:ok, user_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Authenticates socket connection via token.
  """
  def authenticate_socket(token) do
    case verify_jwt(token) do
      {:ok, user_id} ->
        case User.get(user_id) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, :user_not_found}
        end

      {:error, _} ->
        {:error, :invalid_token}
    end
  end
end
