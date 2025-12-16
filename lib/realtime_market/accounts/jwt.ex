defmodule RealtimeMarket.Accounts.JWT do
  @moduledoc """
  Simple JWT implementation without external dependencies.
  Uses HMAC-SHA256 for signing.
  """

  @secret Application.compile_env!(:realtime_market, :jwt_secret)
  @algorithm "HS256"

  @doc """
  Generates a JWT token for a user.
  """
  def generate(user_id, expires_in_hours \\ 24) do
    header = %{
      "alg" => @algorithm,
      "typ" => "JWT"
    }

    payload = %{
      "user_id" => user_id,
      "exp" => DateTime.utc_now() |> DateTime.add(expires_in_hours, :hour) |> DateTime.to_unix(),
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "iss" => "realtime_market"
    }

    encoded_header = Base.url_encode64(Jason.encode!(header), padding: false)
    encoded_payload = Base.url_encode64(Jason.encode!(payload), padding: false)

    signature = sign("#{encoded_header}.#{encoded_payload}")

    "#{encoded_header}.#{encoded_payload}.#{signature}"
  end

  @doc """
  Verifies and decodes a JWT token.
  """
  def verify(token) do
    case String.split(token, ".") do
      [encoded_header, encoded_payload, signature] ->
        # Verify signature
        data = "#{encoded_header}.#{encoded_payload}"
        expected_signature = sign(data)

        if Plug.Crypto.secure_compare(signature, expected_signature) do
          # Decode payload
          case decode_payload(encoded_payload) do
            {:ok, payload} ->
              # Check expiration
              if payload["exp"] > DateTime.utc_now() |> DateTime.to_unix() do
                {:ok, payload["user_id"], payload}
              else
                {:error, :expired}
              end

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:error, :invalid_signature}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc """
  Decodes a JWT token without verification (for debugging).
  """
  def decode(token) do
    case String.split(token, ".") do
      [encoded_header, encoded_payload, _signature] ->
        case {decode_header(encoded_header), decode_payload(encoded_payload)} do
          {{:ok, header}, {:ok, payload}} -> {:ok, header, payload}
          {{:error, reason}, _} -> {:error, reason}
          {_, {:error, reason}} -> {:error, reason}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp sign(data) do
    :crypto.mac(:hmac, :sha256, @secret, data)
    |> Base.url_encode64(padding: false)
  end

  defp decode_header(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, json} -> Jason.decode(json)
      :error -> {:error, :invalid_base64}
    end
  end

  defp decode_payload(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, json} -> Jason.decode(json)
      :error -> {:error, :invalid_base64}
    end
  end
end
