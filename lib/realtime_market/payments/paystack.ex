defmodule RealtimeMarket.Payments.Paystack do
  @moduledoc """
  Paystack payment integration.
  """

  @paystack_secret_key System.get_env("PAYSTACK_SECRET_KEY")
  # @paystack_public_key System.get_env("PAYSTACK_PUBLIC_KEY")  # REMOVE OR USE
  # @paystack_base_url "https://api.paystack.co"

  @doc """
  Initialize Paystack transaction.
  """
  def initialize_transaction(email, amount, reference \\ nil) do
    reference = reference || generate_reference()

    body = %{
      email: email,
      amount: Kernel.trunc(amount * 100), # Convert to kobo
      reference: reference,
      callback_url: "https://yourapp.com/payment/callback"
    }

    case HTTPoison.post(
      "https://api.paystack.co/transaction/initialize",
      Jason.encode!(body),
      headers()
    ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      error ->
        {:error, error}
    end
  end

  @doc """
  Verify Paystack transaction.
  """
  def verify_transaction(reference) do
    case HTTPoison.get(
      "https://api.paystack.co/transaction/verify/#{reference}",
      headers()
    ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        data = Jason.decode!(body)
        {:ok, data}
      error ->
        {:error, error}
    end
  end

  @doc """
  Authorize payment after delivery confirmation.
  """
  def authorize_payment(request_id, amount, customer_email) do
    # Send notification to chat room for payment authorization
    {:ok, response} = initialize_transaction(customer_email, amount, "REQ_#{request_id}")

    # Return payment authorization URL
    %{
      authorization_url: response["data"]["authorization_url"],
      reference: response["data"]["reference"],
      access_code: response["data"]["access_code"]
    }
  end

  defp headers do
    [
      {"Authorization", "Bearer #{@paystack_secret_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp generate_reference do
    :crypto.strong_rand_bytes(12)
    |> Base.encode64()
    |> String.replace(~r/[+\/=]/, "")
    |> String.slice(0, 16)
  end
end
