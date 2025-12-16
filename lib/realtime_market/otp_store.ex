defmodule RealtimeMarket.OTPStore do
  @table :otp_store

  def init do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        :ok
    end
  end
end
