defmodule RealtimeMarket.Accounts.JWT do
  @moduledoc """
  JWT implementation using Jason and :crypto for signing.
  Compatible with Elixir 1.14.
  """

  @secret Application.compile_env(:realtime_market, :jwt_secret, "default_secret_change_me")
  @algorithm "HS256"

  @doc """
  Generates a JWT token for a user.
  """
  def generate(user_id, expires_in_hours \\ 168) do  # 7 days default
    header = Jason.encode!(%{"alg" => @algorithm, "typ" => "JWT"})
    |> Base.url_encode64(padding: false)

    payload = Jason.encode!(%{
      "user_id" => user_id,
      "exp" => System.system_time(:second) + expires_in_hours * 3600,
      "iat" => System.system_time(:second),
      "iss" => "realtime_market"
    })
    |> Base.url_encode64(padding: false)

    signing_input = "#{header}.#{payload}"
    signature = hmac_sha256(signing_input, @secret)
    |> Base.url_encode64(padding: false)

    "#{header}.#{payload}.#{signature}"
  end

  @doc """
  Verifies and decodes a JWT token.
  """
  def verify(token) do
    with [header, payload, signature] <- String.split(token, ".", parts: 3),
         expected_signature = hmac_sha256("#{header}.#{payload}", @secret)
                              |> Base.url_encode64(padding: false),
         true <- Plug.Crypto.secure_compare(signature, expected_signature),
         {:ok, decoded_payload} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} <- Jason.decode(decoded_payload),
         true <- claims["exp"] > System.system_time(:second) do
      {:ok, claims["user_id"], claims}
    else
      [_header, _payload, _signature] -> {:error, :invalid_signature}
      _ -> {:error, :invalid_token}
    end
  end

  @doc """
  Decodes JWT without verification (for debugging).
  """
  def peek(token) do
    case String.split(token, ".", parts: 3) do
      [header, payload, _signature] ->
        with {:ok, header_json} <- Base.url_decode64(header, padding: false),
             {:ok, header_map} <- Jason.decode(header_json),
             {:ok, payload_json} <- Base.url_decode64(payload, padding: false),
             {:ok, payload_map} <- Jason.decode(payload_json) do
          {:ok, header_map, payload_map}
        else
          _ -> {:error, :invalid_token}
        end

      _ -> {:error, :invalid_format}
    end
  end

  @doc """
  Verifies a token and returns the user ID.
  """
  def verify_jwt(token) do
    case verify(token) do
      {:ok, user_id, _claims} -> {:ok, user_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp hmac_sha256(data, secret) do
    :crypto.mac(:hmac, :sha256, secret, data)
  end
end
