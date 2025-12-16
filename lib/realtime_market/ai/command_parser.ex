defmodule RealtimeMarket.AI.CommandParser do
  @moduledoc """
  Parses AI commands from chat messages.
  """

  @commands %{
    "createshop" => :create_shop,
    "createproduct" => :create_product,
    "setupdelivery" => :setup_delivery,
    "request" => :make_request,
    "listproducts" => :list_products,
    "myrequests" => :my_requests,
    "deliveryto" => :delivery_to,
    "track" => :track_delivery,
    "pay" => :make_payment,
    "help" => :help,
    "status" => :status,
    "followshop" => :follow_shop,
    "unfollowshop" => :unfollow_shop,
    "myshops" => :my_shops,
    "shopinfo" => :shop_info
  }

  @doc """
  Parses message and returns command or regular message.
  """
  def parse(message) do
    trimmed = String.trim(message)

    case String.starts_with?(trimmed, "@") do
      true ->
        parse_command(trimmed)

      false ->
        # Try to detect product requests without @
        detect_product_request(trimmed)
    end
  end

  defp parse_command(message) do
    # Remove @ and split into command and arguments
    without_at = String.slice(message, 1..-1)
    parts = String.split(without_at, " ")

    case parts do
      [] -> {:error, :empty_command}
      [command] -> handle_single_command(command, "")
      [command | args] -> handle_single_command(command, Enum.join(args, " "))
    end
  end

  defp handle_single_command(command, args) do
    normalized = String.downcase(command)

    case Map.get(@commands, normalized) do
      nil ->
        {:error, :unknown_command}

      command_atom ->
        {:command, command_atom, args}
    end
  end

  defp detect_product_request(message) do
    # Use simple pattern matching for product requests
    patterns = [
      {"i want", :want_product},
      {"i need", :need_product},
      {"can i get", :get_product},
      {"looking for", :find_product},
      {"price of", :price_check},
      {"buy", :buy_product}
    ]

    lowercase = String.downcase(message)

    Enum.find(patterns, {:message, message}, fn {pattern, _} ->
      String.contains?(lowercase, pattern)
    end)
    |> case do
      {:message, _} -> {:message, message}
      {pattern, intent} -> {:product_intent, intent, String.replace(lowercase, pattern, "") |> String.trim()}
    end
  end

  @doc """
  Gets available commands for help message.
  """
  def available_commands do
    @commands
    |> Map.keys()
    |> Enum.map(&"@#{&1}")
    |> Enum.join(", ")
  end

  @doc """
  Validates if a string is a command.
  """
  def is_command?(message) do
    case parse(message) do
      {:command, _, _} -> true
      {:product_intent, _, _} -> true
      _ -> false
    end
  end
end
