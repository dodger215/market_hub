defmodule RealtimeMarketWeb.AuthPlug do
  @moduledoc """
  Authentication plug for verifying JWT tokens.
  """

  import Plug.Conn
  alias RealtimeMarket.Accounts.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_auth_token(conn) do
      {:ok, token} ->
        case Auth.verify_jwt(token) do
          {:ok, user_id} ->
            assign(conn, :current_user_id, user_id)

          {:error, _reason} ->
            send_unauthorized(conn, "Invalid token")
        end

      :error ->
        send_unauthorized(conn, "Missing authentication token")
    end
  end

  defp get_auth_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end

  defp send_unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: message}))
    |> halt()
  end
end
