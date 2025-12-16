defmodule RealtimeMarketWeb.ChatChannel do
  @moduledoc """
  Phoenix Channel for real-time chat.
  """

  use Phoenix.Channel

  alias RealtimeMarket.Accounts.Auth
  alias RealtimeMarket.Chat.{Room, Message}
  alias RealtimeMarket.AI.{CommandParser, Flow}

  # Topic format: "chat:room_<room_id>"
  def join("chat:" <> room_id, %{"token" => token}, socket) do
    case Auth.authenticate_socket(token) do
      {:ok, user} ->
        case Room.get(room_id) do
          {:ok, room} ->
            # Check if user is participant
            if user["_id"] in room["participant_ids"] do
              socket =
                socket
                |> assign(:room_id, room_id)
                |> assign(:user_id, user["_id"])
                |> assign(:user, user)

              send(self(), :after_join)
              {:ok, socket}
            else
              {:error, %{reason: "not_a_participant"}}
            end

          {:error, _} ->
            {:error, %{reason: "room_not_found"}}
        end

      {:error, _} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    # Send last messages
    {:ok, messages} = Message.get_room_messages(socket.assigns.room_id, 50)
    push(socket, "messages_history", %{messages: messages})

    # Notify others
    broadcast!(socket, "user_joined", %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.user["username"],
      timestamp: RealtimeMarket.Mongo.timestamp()
    })

    {:noreply, socket}
  end

  def handle_in("message", %{"content" => content}, socket) do
    room_id = socket.assigns.room_id
    user_id = socket.assigns.user_id

    # Check if message is an AI command
    if CommandParser.is_command?(content) do
      # Handle AI command flow
      handle_ai_command(room_id, user_id, content, socket)
    else
      # Regular message
      handle_regular_message(room_id, user_id, content, socket)
    end
  end

  defp handle_regular_message(room_id, user_id, content, socket) do
    case Message.create(room_id, "user", user_id, content) do
      {:ok, message} ->
        # Broadcast to all subscribers
        broadcast_message(socket, message)
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: "message_send_failed"}}, socket}
    end
  end

  defp handle_ai_command(room_id, user_id, content, socket) do
    # Get flow state from socket (you'd store this in a process or Redis in production)
    state = socket.assigns[:flow_state]

    # Process with AI flow engine
    case Flow.process_message(room_id, user_id, content, state) do
      {:ok, new_state} ->
        # Update socket with new flow state
        socket = assign(socket, :flow_state, new_state)
        {:reply, :ok, socket}

      {:error, reason} ->
        # Send error message
        Message.create_ai_message(room_id, "Sorry, I couldn't process that command.")
        {:reply, :ok, socket}
    end
  end

  defp broadcast_message(socket, message) do
    broadcast!(socket, "new_message", %{
      id: message["_id"],
      sender_type: message["sender_type"],
      sender_id: message["sender_id"],
      content: message["content"],
      created_at: message["created_at"]
    })
  end

  def handle_in("typing", %{"is_typing" => is_typing}, socket) do
    broadcast!(socket, "user_typing", %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.user["username"],
      is_typing: is_typing
    })

    {:noreply, socket}
  end

  def handle_in("mark_read", %{"message_id" => message_id}, socket) do
    # In production, store read receipts in MongoDB
    broadcast!(socket, "message_read", %{
      message_id: message_id,
      user_id: socket.assigns.user_id,
      timestamp: RealtimeMarket.Mongo.timestamp()
    })

    {:reply, :ok, socket}
  end

  def terminate(_reason, socket) do
    # Notify others when user leaves
    broadcast!(socket, "user_left", %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.user["username"],
      timestamp: RealtimeMarket.Mongo.timestamp()
    })

    :ok
  end
end
