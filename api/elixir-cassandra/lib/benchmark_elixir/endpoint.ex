defmodule BenchmarkElixir.Endpoint do
  use Phoenix.Endpoint,
    otp_app: :benchmark_elixir_api

  plug Plug.RequestId

  plug BenchmarkElixir.Router
end
