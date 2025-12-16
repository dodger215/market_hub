defmodule RealtimeMarket.Services.SMS do
  @moduledoc """
  SMS service using Arkesel API.
  """

  @arkesel_api_key System.get_env("ARKESEL_API_KEY")
  @arkesel_base_url "https://sms.arkesel.com/api/v2"

  @doc """
  Send OTP SMS.
  """
  def send_otp_sms(phone_number, otp_code) do
    message = "Your OTP code is: #{otp_code}. Valid for 10 minutes."

    send_sms(phone_number, message, "Realtime Market")
  end

  @doc """
  Send delivery notification SMS.
  """
  def send_delivery_notification_sms(phone_number, delivery_info) do
    message = """
    Your package is out for delivery!
    Tracking: #{delivery_info["tracking_token"]}
    Driver: #{delivery_info["driver_name"]} (#{delivery_info["driver_phone"]})
    """

    send_sms(phone_number, message, "Realtime Delivery")
  end

  @doc """
  Send order confirmation SMS.
  """
  def send_order_confirmation_sms(phone_number, order_id) do
    message = "Your order ##{order_id} has been confirmed. Thank you for shopping with us!"

    send_sms(phone_number, message, "Realtime Market")
  end

  @doc """
  Send generic SMS.
  """
  def send_sms(phone_number, message, sender_id \\ "Realtime") do
    # Clean phone number (remove + and spaces)
    clean_phone = phone_number
    |> String.replace("+", "")
    |> String.replace(" ", "")

    headers = [
      {"api-key", @arkesel_api_key},
      {"Content-Type", "application/json"}
    ]

    body = %{
      sender: sender_id,
      message: message,
      recipients: [clean_phone]
    }

    case HTTPoison.post("#{@arkesel_base_url}/sms/send", Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"code" => "1000"}} -> {:ok, "SMS sent successfully"}
          {:ok, error_data} -> {:error, error_data["message"]}
          _ -> {:error, "Failed to parse response"}
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end
end
