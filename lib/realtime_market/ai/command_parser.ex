defmodule RealtimeMarket.AI.CommandParser do
  @moduledoc """
  Parses AI commands from chat messages.
  """

  @commands %{
    "createshop" => :create_shop,
    "createproduct" => :create_product,
    "setupdelivery" => :setup_delivery,
    "help" => :help,
    "status" => :status,
    "listproducts" => :list_products
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
        {:message, message}
    end
  end

  defp parse_command(message) do
    # Remove @ and split into command and arguments
    without_at = String.slice(message, 1..-1)
    [command | args] = String.split(without_at, " ")

    normalized = String.downcase(command)

    case Map.get(@commands, normalized) do
      nil ->
        {:error, :unknown_command}

      command_atom ->
        {:command, command_atom, Enum.join(args, " ")}
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
      _ -> false
    end
  end
end
