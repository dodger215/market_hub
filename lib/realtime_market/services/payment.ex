defmodule RealtimeMarket.Services.Payment do
  @moduledoc """
  Payment service using Paystack.
  """

  @paystack_secret_key System.get_env("PAYSTACK_SECRET_KEY")
  @paystack_public_key System.get_env("PAYSTACK_PUBLIC_KEY")
  @paystack_base_url "https://api.paystack.co"

  @doc """
  Initialize a payment transaction.
  """
  def initialize_transaction(email, amount, reference \\ nil, metadata \\ %{}) do
    reference = reference || generate_reference()

    body = %{
      email: email,
      amount: Kernel.trunc(amount * 100), # Convert to kobo
      reference: reference,
      metadata: metadata,
      callback_url: "https://yourapp.com/payment/callback"
    }

    case post_request("/transaction/initialize", body) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok, %{
          authorization_url: data["authorization_url"],
          access_code: data["access_code"],
          reference: data["reference"]
        }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  @doc """
  Verify a transaction.
  """
  def verify_transaction(reference) do
    case get_request("/transaction/verify/#{reference}") do
      {:ok, %{"status" => true, "data" => data}} ->
        # Check if transaction was successful
        case data["status"] do
          "success" ->
            {:ok, %{
              reference: data["reference"],
              amount: data["amount"] / 100,
              currency: data["currency"],
              paid_at: data["paid_at"],
              customer: data["customer"]
            }}

          "failed" ->
            {:error, "Payment failed"}

          "abandoned" ->
            {:error, "Payment abandoned"}
        end

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  @doc """
  Create a transfer recipient for payouts.
  """
  def create_transfer_recipient(name, account_number, bank_code, type \\ "nuban") do
    body = %{
      type: type,
      name: name,
      account_number: account_number,
      bank_code: bank_code,
      currency: "NGN"
    }

    case post_request("/transferrecipient", body) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok, %{
          recipient_code: data["recipient_code"],
          account_number: data["details"]["account_number"],
          bank_name: data["details"]["bank_name"]
        }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  @doc """
  Initiate a transfer to recipient.
  """
  def initiate_transfer(recipient_code, amount, reason) do
    body = %{
      source: "balance",
      amount: Kernel.trunc(amount * 100),
      recipient: recipient_code,
      reason: reason
    }

    case post_request("/transfer", body) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok, %{
          transfer_code: data["transfer_code"],
          reference: data["reference"],
          status: data["status"]
        }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  @doc """
  Create subscription plan.
  """
  def create_plan(name, amount, interval \\ "monthly") do
    body = %{
      name: name,
      amount: Kernel.trunc(amount * 100),
      interval: interval,
      currency: "NGN"
    }

    case post_request("/plan", body) do
      {:ok, %{"status" => true, "data" => data}} ->
        {:ok, %{
          plan_code: data["plan_code"],
          amount: data["amount"] / 100,
          interval: data["interval"]
        }}

      {:ok, %{"status" => false, "message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  defp post_request(endpoint, body) do
    url = @paystack_base_url <> endpoint

    headers = [
      {"Authorization", "Bearer #{@paystack_secret_key}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{response_body}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp get_request(endpoint) do
    url = @paystack_base_url <> endpoint

    headers = [
      {"Authorization", "Bearer #{@paystack_secret_key}"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %HTTPoison.Response{status_code: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{response_body}"}

      {:error, reason} ->
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  defp generate_reference do
    :crypto.strong_rand_bytes(16)
    |> Base.encode64()
    |> String.replace(~r/[+\/=]/, "")
    |> String.slice(0, 16)
  end
end
