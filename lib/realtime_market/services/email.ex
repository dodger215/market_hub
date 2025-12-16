defmodule RealtimeMarket.Services.Email do
  @moduledoc """
  Email service using Google SMTP via Swoosh.
  """

  use Swoosh.Mailer, otp_app: :realtime_market

  @from_email "noreply@realtime-market.com"

  @doc """
  Send OTP verification email.
  """
  def send_otp_email(email, otp_code) do
    email = %Swoosh.Email{
      to: email,
      from: @from_email,
      subject: "Your OTP Code",
      html_body: """
      <h2>Your OTP Code</h2>
      <p>Use this code to verify your account: <strong>#{otp_code}</strong></p>
      <p>This code will expire in 10 minutes.</p>
      """,
      text_body: "Your OTP code is: #{otp_code}. It will expire in 10 minutes."
    }

    deliver_email(email)
  end

  @doc """
  Send delivery assignment email.
  """
  def send_delivery_assignment_email(delivery_person_email, delivery_info) do
    email = %Swoosh.Email{
      to: delivery_person_email,
      from: @from_email,
      subject: "New Delivery Assignment",
      html_body: """
      <h2>New Delivery Assignment</h2>
      <p>You have been assigned a new delivery.</p>
      <ul>
        <li><strong>Delivery ID:</strong> #{delivery_info["delivery_id"]}</li>
        <li><strong>Customer:</strong> #{delivery_info["customer_name"]}</li>
        <li><strong>Pickup Location:</strong> #{delivery_info["pickup_address"]}</li>
        <li><strong>Delivery Location:</strong> #{delivery_info["delivery_address"]}</li>
      </ul>
      <p>Click <a href="#{delivery_info["tracking_link"]}">here</a> to track the delivery.</p>
      """
    }

    deliver_email(email)
  end

  @doc """
  Send order confirmation email.
  """
  def send_order_confirmation_email(customer_email, order_details) do
    email = %Swoosh.Email{
      to: customer_email,
      from: @from_email,
      subject: "Order Confirmation",
      html_body: """
      <h2>Order Confirmation</h2>
      <p>Thank you for your order!</p>
      <h3>Order Details:</h3>
      <ul>
        <li><strong>Order ID:</strong> #{order_details["order_id"]}</li>
        <li><strong>Total Amount:</strong> $#{order_details["total_amount"]}</li>
        <li><strong>Delivery Address:</strong> #{order_details["delivery_address"]}</li>
      </ul>
      <p>You can track your order <a href="#{order_details["tracking_link"]}">here</a>.</p>
      """
    }

    deliver_email(email)
  end

  @doc """
  Send password reset email.
  """
  def send_password_reset_email(email, reset_token) do
    reset_link = "https://yourapp.com/reset-password?token=#{reset_token}"

    email = %Swoosh.Email{
      to: email,
      from: @from_email,
      subject: "Password Reset Request",
      html_body: """
      <h2>Password Reset</h2>
      <p>Click the link below to reset your password:</p>
      <p><a href="#{reset_link}">Reset Password</a></p>
      <p>This link will expire in 1 hour.</p>
      """
    }

    deliver_email(email)
  end

  defp deliver_email(email) do
    # Send email using configured Swoosh adapter
    try do
      {:ok, _} = RealtimeMarket.Services.Email.deliver(email)
      {:ok, "Email sent successfully"}
    rescue
      error ->
        IO.inspect(error, label: "Email delivery failed")
        {:error, "Failed to send email"}
    end
  end
end
