defmodule RealtimeMarketWeb.AuthController do
  use RealtimeMarketWeb, :controller

  alias RealtimeMarket.Accounts.{Auth, User}

  @doc """
  Health check endpoint.
  """
  def health(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: "1.0.0"
    })
  end

  @doc """
  Registers a new user with phone number and username.
  """
  def register(conn, %{"phone_number" => phone_number, "username" => username}) do
    case User.get_by_phone(phone_number) do
      {:ok, _user} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "User already exists"})

      {:error, :not_found} ->
        case User.create(%{phone_number: phone_number, username: username}) do
          {:ok, user} ->
            # Generate OTP for verification
            {:ok, otp} = Auth.generate_otp(phone_number)

            conn
            |> put_status(:created)
            |> json(%{
              success: true,
              message: "User registered. Verify with OTP.",
              user_id: user["_id"],
              otp: if(Mix.env() == :dev, do: otp, else: nil)
            })

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: inspect(reason)})
        end
    end
  end

  @doc """
  Checks if a username is available.
  """
  def check_username(conn, %{"username" => username}) do
    case User.get_by_username(username) do
      {:ok, _user} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Username already taken"})

      {:error, :not_found} ->
        conn
        |> put_status(:ok)
        |> json(%{available: true})
    end
  end

  @doc """
  Requests OTP for a phone number.
  """
  def request_otp(conn, %{"phone_number" => phone_number}) do
    case Auth.generate_otp(phone_number) do
      {:ok, otp} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          message: "OTP sent",
          otp: if(Mix.env() == :dev, do: otp, else: nil) # Only return OTP in dev
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  @doc """
  Verifies OTP and returns JWT token.
  """
  def verify_otp(conn, %{"phone_number" => phone_number, "otp" => otp}) do
    case Auth.verify_otp(phone_number, otp) do
      {:ok, token, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          token: token,
          user: %{
            id: user["_id"],
            username: user["username"],
            phone_number: user["phone_number"],
            created_at: user["created_at"]
          }
        })

      {:error, :invalid_otp} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid OTP"})

      {:error, :expired} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "OTP expired"})
    end
  end
end
