defmodule RealtimeMarket.AI.Flow do
  @moduledoc """
  Conversational AI flow engine.
  """

  alias RealtimeMarket.Chat.Message
  alias RealtimeMarket.AI.CommandParser
  alias RealtimeMarket.Shops.Shop
  alias RealtimeMarket.Shops.Product

  # Flow state structure
  defstruct [
    :room_id,
    :user_id,
    :current_step,
    :data,
    :command
  ]

  @doc """
  Processes incoming message and returns response.
  """
  def process_message(room_id, user_id, message, state \\ nil) do
    case CommandParser.parse(message) do
      {:command, command, args} ->
        handle_command(room_id, user_id, command, args, state)

      {:message, _} ->
        handle_regular_message(room_id, user_id, message, state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_command(room_id, user_id, command, args, state) do
    case command do
      :create_shop ->
        # Start shop creation flow
        new_state = %__MODULE__{
          room_id: room_id,
          user_id: user_id,
          current_step: :shop_name,
          command: :create_shop,
          data: %{}
        }

        Message.create_ai_message(room_id, "Let's create a shop! What should we name it?")
        {:ok, new_state}

      :create_product ->
        # Start product creation flow
        new_state = %__MODULE__{
          room_id: room_id,
          user_id: user_id,
          current_step: :select_shop,
          command: :create_product,
          data: %{}
        }

        Message.create_ai_message(room_id, "Let's create a product! First, what's your shop ID?")
        {:ok, new_state}

      :help ->
        commands = CommandParser.available_commands()
        Message.create_ai_message(room_id, "Available commands: #{commands}")
        {:ok, nil}

      :list_products ->
        # List products for user's shops
        {:ok, shops} = Shop.get_by_owner(user_id)

        response =
          if shops == [] do
            "You don't have any shops yet. Create one with @createshop"
          else
            Enum.map_join(shops, "\n", fn shop ->
              {:ok, products} = Product.get_by_shop(shop["_id"])
              count = length(products)
              "#{shop["shop_name"]}: #{count} products"
            end)
          end

        Message.create_ai_message(room_id, response)
        {:ok, nil}

      _ ->
        Message.create_ai_message(room_id, "Command received. Processing...")
        {:ok, nil}
    end
  end

  defp handle_regular_message(room_id, user_id, message, state) do
    case state do
      nil ->
        # No active flow, just acknowledge
        Message.create_ai_message(room_id, "I received: #{String.slice(message, 0..100)}")
        {:ok, nil}

      %__MODULE__{current_step: step, command: command} ->
        # Continue existing flow
        continue_flow(room_id, user_id, message, state, step, command)
    end
  end

  defp continue_flow(room_id, user_id, message, state, :shop_name, :create_shop) do
    data = Map.put(state.data, :shop_name, message)
    new_state = %{state | current_step: :shop_location, data: data}

    Message.create_ai_message(room_id, "Great name! Where is the shop located?")
    {:ok, new_state}
  end

  defp continue_flow(room_id, user_id, message, state, :shop_location, :create_shop) do
    data = Map.put(state.data, :location, message)
    new_state = %{state | current_step: :shop_category, data: data}

    Message.create_ai_message(room_id, "What category is your shop? (e.g., food, clothing, electronics)")
    {:ok, new_state}
  end

  defp continue_flow(room_id, user_id, message, state, :shop_category, :create_shop) do
    data = Map.put(state.data, :category, message)

    # Create the shop
    case Shop.create(user_id, %{
           shop_name: data.shop_name,
           location: data.location,
           category: data.category
         }) do
      {:ok, shop} ->
        Message.create_ai_message(room_id, "✅ Shop created successfully! ID: #{shop["_id"]}")
        {:ok, nil}

      {:error, reason} ->
        Message.create_ai_message(room_id, "❌ Failed to create shop: #{inspect(reason)}")
        {:ok, nil}
    end
  end

  # Add more flow steps for other commands...

  defp continue_flow(room_id, _user_id, _message, state, _step, _command) do
    # Default fallback
    Message.create_ai_message(room_id, "I didn't understand that. Type @help for available commands.")
    {:ok, nil}
  end
end
