defmodule RealtimeMarket.AI.Flow do
  @moduledoc """
  Conversational AI flow engine with purchase request system.
  """

  alias RealtimeMarket.Chat.{Message, Room}
  alias RealtimeMarket.AI.CommandParser
  alias RealtimeMarket.Shops.{Shop, Product}
  alias RealtimeMarket.Purchase.Request
  alias RealtimeMarket.Delivery.{Delivery, DeliveryPerson}
  # alias RealtimeMarket.Delivery.Geo
  alias RealtimeMarket.Mongo

  # Flow state structure
  defstruct [
    :room_id,
    :user_id,
    :current_step,
    :data,
    :command,
    :shop_id,
    :request_id
  ]

  @doc """
  Processes incoming message and returns response.
  """
  def process_message(room_id, user_id, message, state \\ nil) do
    case CommandParser.parse(message) do
      {:command, command, args} ->
        handle_command(room_id, user_id, command, args, state)

      {:product_intent, _intent, product_query} ->
        handle_product_intent(room_id, user_id, product_query, state)

      {:message, _} ->
        handle_regular_message(room_id, user_id, message, state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Handle product intent (e.g., "i want", "i need")
  defp handle_product_intent(room_id, _user_id, product_query, state) do
    # For now, just acknowledge the product query
    Message.create_ai_message(room_id,
      "I understand you're interested in: #{product_query}. Use @request to make a formal request.")
    {:ok, state}
  end

  # Handle regular message
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

  # Handle @request command
  defp handle_command(room_id, user_id, :make_request, _args, _state) do
    # Get shop from room participants
    {:ok, room} = Room.get(room_id)

    # Find shop participant (not the current user)
    shop_id = Enum.find(room["participant_ids"], fn id -> id != user_id end)

    case Shop.get(shop_id) do
      {:ok, shop} ->
        # Get shop products
        {:ok, products} = Product.get_by_shop(shop_id)

        if products == [] do
          Message.create_ai_message(room_id, "This shop has no products yet.")
          {:ok, nil}
        else
          # Format product list
          product_list = Enum.map_join(products, "\n", fn product ->
            "• #{product["name"]} - #{product["price"]} (Stock: #{product["stock_quantity"]})"
          end)

          new_state = %__MODULE__{
            room_id: room_id,
            user_id: user_id,
            shop_id: shop_id,
            current_step: :select_product,
            command: :make_request,
            data: %{products: products}
          }

          Message.create_ai_message(room_id,
            "Available products from #{shop["shop_name"]}:\n#{product_list}\n\nReply with the product name you want.")
          {:ok, new_state}
        end

      _ ->
        Message.create_ai_message(room_id, "Could not find shop information.")
        {:ok, nil}
    end
  end

  # Handle @deliveryto command
  defp handle_command(room_id, user_id, :delivery_to, _args, _state) do
    # Get shop owned by user
    {:ok, shops} = Shop.get_by_owner(user_id)

    case shops do
      [] ->
        Message.create_ai_message(room_id, "You don't own any shops.")
        {:ok, nil}

      _ ->
        # Get pending requests for user's shops
        pending_requests = Enum.flat_map(shops, fn shop ->
          {:ok, requests} = Request.get_pending_for_shop(shop["_id"])
          Enum.map(requests, fn req -> Map.put(req, "shop_name", shop["shop_name"]) end)
        end)

        if pending_requests == [] do
          Message.create_ai_message(room_id, "No pending delivery requests.")
          {:ok, nil}
        else
          # Format request list
          request_list = Enum.map_join(pending_requests, "\n", fn req ->
            "• Request ##{req["_id"]} from Shop: #{req["shop_name"]} - Total: #{req["total_price"]}"
          end)

          new_state = %__MODULE__{
            room_id: room_id,
            user_id: user_id,
            current_step: :select_request_for_delivery,
            command: :delivery_to,
            data: %{requests: pending_requests}
          }

          Message.create_ai_message(room_id,
            "Pending delivery requests:\n#{request_list}\n\nReply with the request number to assign delivery.")
          {:ok, new_state}
        end
    end
  end

  # Handle other commands (create_shop, create_product, etc.)
  defp handle_command(room_id, _user_id, :help, _args, _state) do
    commands = ["@request", "@deliveryto", "@createshop", "@createproduct", "@help"]
    Message.create_ai_message(room_id, "Available commands: #{Enum.join(commands, ", ")}")
    {:ok, nil}
  end

  defp handle_command(room_id, user_id, :create_shop, _args, _state) do
    Message.create_ai_message(room_id, "Let's create a shop! What should we name it?")

    new_state = %__MODULE__{
      room_id: room_id,
      user_id: user_id,
      current_step: :shop_name,
      command: :create_shop,
      data: %{}
    }

    {:ok, new_state}
  end

  defp handle_command(room_id, user_id, :create_product, _args, _state) do
    Message.create_ai_message(room_id, "Let's create a product! First, what's your shop name?")

    new_state = %__MODULE__{
      room_id: room_id,
      user_id: user_id,
      current_step: :select_shop,
      command: :create_product,
      data: %{}
    }

    {:ok, new_state}
  end

  # Handle default unknown command
  defp handle_command(room_id, _user_id, _command, _args, _state) do
    Message.create_ai_message(room_id, "I didn't understand that command. Type @help for available commands.")
    {:ok, nil}
  end

  # Handle product selection step
  defp continue_flow(room_id, _user_id, message, state, :select_product, :make_request) do
    # Use simple matching to find product
    selected_product = find_product_by_name(message, state.data.products)

    case selected_product do
      nil ->
        Message.create_ai_message(room_id, "Product not found. Please type the exact product name.")
        {:ok, state}

      product ->
        new_state = %{state |
          current_step: :enter_quantity,
          data: Map.put(state.data, :selected_product, product)
        }

        Message.create_ai_message(room_id,
          "Selected: #{product["name"]} - #{product["price"]}\nHow many would you like?")
        {:ok, new_state}
    end
  end

  # Handle quantity entry
  defp continue_flow(room_id, _user_id, message, state, :enter_quantity, :make_request) do
    quantity = case Integer.parse(message) do
      {num, ""} -> num
      _ -> 1
    end

    product = state.data.selected_product

    if quantity > product["stock_quantity"] do
      Message.create_ai_message(room_id,
        "Only #{product["stock_quantity"]} available. Please enter a smaller quantity.")
      {:ok, state}
    else
      total_price = Decimal.mult(product["price"], Decimal.new(quantity))

      new_state = %{state |
        current_step: :delivery_option,
        data: Map.merge(state.data, %{
          quantity: quantity,
          total_price: total_price
        })
      }

      Message.create_ai_message(room_id,
        "Total: #{total_price}\nDo you need delivery? (yes/no)")
      {:ok, new_state}
    end
  end

  # Handle delivery option
  defp continue_flow(room_id, _user_id, message, state, :delivery_option, :make_request) do
    needs_delivery = String.downcase(message) in ["yes", "y", "yeah", "sure"]

    if needs_delivery do
      new_state = %{state | current_step: :get_location}
      Message.create_ai_message(room_id,
        "Please share your delivery location (address or coordinates).\nOr type 'use_current' to use your current location.")
      {:ok, new_state}
    else
      # No delivery needed - get shop location
      {:ok, shop} = Shop.get(state.shop_id)

      # Create purchase request without delivery
      create_purchase_request(room_id, state, %{
        needs_delivery: false,
        shop_location: shop["location"]
      })
    end
  end

  # Handle location sharing
  defp continue_flow(room_id, _user_id, message, state, :get_location, :make_request) do
    # In production, use geocoding API
    location = if message == "use_current" do
      # Get user's current location from user profile
      %{latitude: 0.0, longitude: 0.0} # Placeholder
    else
      # Parse location from message
      %{address: message, coordinates: nil}
    end

    create_purchase_request(room_id, state, %{
      needs_delivery: true,
      customer_location: location
    })
  end

  # Handle request selection for delivery assignment
  defp continue_flow(room_id, _user_id, message, state, :select_request_for_delivery, :delivery_to) do
    request_id = extract_request_id(message, state.data.requests)

    case request_id do
      nil ->
        Message.create_ai_message(room_id, "Invalid request number. Please try again.")
        {:ok, state}

      req_id ->
        # Get available delivery persons
        {:ok, request} = Request.get(req_id)
        {:ok, shop} = Shop.get(request["shop_id"])

        # Find delivery persons near shop
        shop_coords = shop["location"]["coordinates"] || {0.0, 0.0}
        available_persons = DeliveryPerson.find_available_nearby(shop_coords)

        if available_persons == [] do
          Message.create_ai_message(room_id, "No delivery persons available nearby.")
          {:ok, nil}
        else
          # Format delivery person list
          persons_list = Enum.map_join(available_persons, "\n", fn person ->
            "• #{person["name"]} (#{person["vehicle_type"]}) - Phone: #{person["phone"]}"
          end)

          new_state = %{state |
            current_step: :select_delivery_person,
            request_id: req_id,
            data: Map.put(state.data, :available_persons, available_persons)
          }

          Message.create_ai_message(room_id,
            "Available delivery persons:\n#{persons_list}\n\nReply with the delivery person's name to assign.")
          {:ok, new_state}
        end
    end
  end

  # Handle delivery person selection
  defp continue_flow(room_id, _user_id, message, state, :select_delivery_person, :delivery_to) do
    delivery_person = find_delivery_person_by_name(message, state.data.available_persons)

    case delivery_person do
      nil ->
        Message.create_ai_message(room_id, "Delivery person not found. Please try again.")
        {:ok, state}

      person ->
        # Assign delivery
        {:ok, request} = Request.get(state.request_id)

        delivery_info = %{
          assigned_at: Mongo.now(),
          delivery_person_id: person["_id"],
          delivery_person_name: person["name"],
          delivery_person_phone: person["phone"]
        }

        # Create delivery record
        {:ok, _delivery, tracking_token} = Delivery.create(
          request["shop_id"],
          request["customer_id"],
          person["_id"],
          %{}
        )

        # Update request status
        Request.assign_delivery(state.request_id, person["_id"], delivery_info)
        Request.update_status(state.request_id, "out_for_delivery")

        # Send notifications (SMS/Email)
        send_delivery_notifications(request, tracking_token, person)

        Message.create_ai_message(room_id,
          "✅ Delivery assigned!\nDelivery Person: #{person["name"]}\nTracking Token: #{tracking_token}\nNotifications sent to both parties.")

        {:ok, nil}
    end
  end

  # Handle shop creation flow steps
  defp continue_flow(room_id, _user_id, message, state, :shop_name, :create_shop) do
    data = Map.put(state.data, :shop_name, message)
    new_state = %{state | current_step: :shop_location, data: data}

    Message.create_ai_message(room_id, "Great name! Where is the shop located?")
    {:ok, new_state}
  end

  defp continue_flow(room_id, _user_id, message, state, :shop_location, :create_shop) do
    data = Map.put(state.data, :location, message)
    new_state = %{state | current_step: :shop_category, data: data}

    Message.create_ai_message(room_id, "What category is this shop? (e.g., electronics, food, clothing)")
    {:ok, new_state}
  end

  defp continue_flow(room_id, user_id, message, state, :shop_category, :create_shop) do
    data = Map.put(state.data, :category, message)

    # Create the shop
    case Shop.create(user_id, %{
           shop_name: data[:shop_name],
           location: data[:location],
           category: data[:category]
         }) do
      {:ok, shop} ->
        Message.create_ai_message(room_id, "✅ Shop created successfully! ID: #{shop["_id"]}")
        {:ok, nil}

      {:error, reason} ->
        Message.create_ai_message(room_id, "❌ Failed to create shop: #{inspect(reason)}")
        {:ok, nil}
    end
  end

  # Default fallback for unrecognized steps
  defp continue_flow(room_id, _user_id, _message, _state, _step, _command) do
    Message.create_ai_message(room_id, "I didn't understand that. Type @help for available commands.")
    {:ok, nil}
  end

  # Create the purchase request
  defp create_purchase_request(room_id, state, delivery_info) do
    {:ok, shop} = Shop.get(state.shop_id)
    product = state.data.selected_product

    request_data = %{
      items: [%{
        product_id: product["_id"],
        product_name: product["name"],
        quantity: state.data.quantity,
        unit_price: product["price"],
        subtotal: state.data.total_price
      }],
      total_price: state.data.total_price,
      delivery_info: delivery_info,
      customer_location: delivery_info[:customer_location],
      shop_location: shop["location"],
      payment_method: "pay_on_delivery"
    }

    case Request.create(state.shop_id, state.user_id, request_data) do
      {:ok, request} ->
        # Update product stock
        Product.update_stock(product["_id"], -state.data.quantity)

        Message.create_ai_message(room_id,
          "✅ Purchase request created!\nRequest ID: ##{request["_id"]}\nStatus: #{request["status"]}\nTotal: #{request["total_price"]}")

        if delivery_info[:needs_delivery] do
          Message.create_ai_message(room_id,
            "Delivery will be arranged once the shop confirms your order.")
        else
          Message.create_ai_message(room_id,
            "You can pick up from: #{shop["location"]}")
        end

        {:ok, nil}

      {:error, reason} ->
        Message.create_ai_message(room_id, "❌ Failed to create request: #{inspect(reason)}")
        {:ok, nil}
    end
  end

  # Helper function to find product by name (using simple matching)
  defp find_product_by_name(query, products) do
    lowercase_query = String.downcase(query)

    Enum.find(products, fn product ->
      product_name = String.downcase(product["name"])
      String.contains?(product_name, lowercase_query) ||
      String.contains?(lowercase_query, product_name)
    end)
  end

  # Helper function to extract request ID
  defp extract_request_id(message, requests) do
    # Try to extract ID from message like "request #123" or just "123"
    case Regex.run(~r/#?(\w+)/, message) do
      [_, id_part] ->
        Enum.find(requests, fn req ->
          String.contains?(req["_id"], id_part) ||
          req["_id"] == id_part
        end)
        |> case do
          nil -> nil
          req -> req["_id"]
        end
      _ -> nil
    end
  end

  # Helper function to find delivery person by name
  defp find_delivery_person_by_name(query, persons) do
    lowercase_query = String.downcase(query)

    Enum.find(persons, fn person ->
      person_name = String.downcase(person["name"])
      String.contains?(person_name, lowercase_query) ||
      String.contains?(lowercase_query, person_name)
    end)
  end

  # Helper function to send notifications
  defp send_delivery_notifications(request, tracking_token, delivery_person) do
    # SMS notification to customer
    customer_message = """
    Your package from Shop #{request["shop_id"]} is out for delivery!
    Tracking: #{tracking_token}
    Delivery Person: #{delivery_person["name"]} (#{delivery_person["phone"]})
    """

    # SMS notification to delivery person
    delivery_person_message = """
    New delivery assigned!
    Request: ##{request["_id"]}
    Customer Location: #{inspect(request["customer_location"])}
    Tracking: #{tracking_token}
    Delivery confirmation link: https://yourapp.com/delivery/confirm/#{tracking_token}
    """

    # Email to delivery person with confirmation link
    confirmation_link = "https://yourapp.com/delivery/confirm/#{tracking_token}"

    # In production, use Twilio for SMS and Bamboo/Swoosh for email
    # Twilio.send_sms(request["customer_phone"], customer_message)
    # Twilio.send_sms(delivery_person["phone"], delivery_person_message)
    # Email.deliver_delivery_confirmation(delivery_person["email"], confirmation_link, request)

    IO.puts("SMS to Customer: #{customer_message}")
    IO.puts("SMS to Delivery Person: #{delivery_person_message}")
    IO.puts("Email sent to: #{delivery_person["email"]} with link: #{confirmation_link}")
  end
end
