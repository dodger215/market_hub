# lib/realtime_market/otp_store.ex
defmodule RealtimeMarket.OTPStore do
  @moduledoc """
  In-memory OTP store for development/testing.
  In production, use Redis or database.
  """

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Schedule cleanup
    Process.send_after(self(), :cleanup, 60_000)
    {:ok, state}
  end

  def init do
    # For compatibility with Application.start call
    :ok
  end

  def store(phone_number, otp, ttl_seconds \\ 600) do
    GenServer.call(__MODULE__, {:store, phone_number, otp, ttl_seconds})
  end

  def get(phone_number) do
    GenServer.call(__MODULE__, {:get, phone_number})
  end

  def delete(phone_number) do
    GenServer.call(__MODULE__, {:delete, phone_number})
  end

  def handle_call({:store, phone_number, otp, ttl_seconds}, _from, state) do
    expiration = System.system_time(:second) + ttl_seconds
    new_state = Map.put(state, phone_number, {otp, expiration})
    {:reply, :ok, new_state}
  end

  def handle_call({:get, phone_number}, _from, state) do
    case Map.get(state, phone_number) do
      {otp, expiration} ->
        # Check expiration outside of guard
        if expiration > System.system_time(:second) do
          {:reply, {:ok, otp}, state}
        else
          # Auto-clean expired OTP
          new_state = Map.delete(state, phone_number)
          {:reply, {:error, :expired}, new_state}
        end

      nil ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:delete, phone_number}, _from, state) do
    new_state = Map.delete(state, phone_number)
    {:reply, :ok, new_state}
  end

  def handle_info(:cleanup, state) do
    now = System.system_time(:second)

    # Remove expired OTPs
    new_state = Enum.reduce(state, %{}, fn {phone, {otp, expiration}}, acc ->
      if expiration > now do
        Map.put(acc, phone, {otp, expiration})
      else
        acc
      end
    end)

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, 60_000)  # Every minute
    {:noreply, new_state}
  end
end
