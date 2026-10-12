defmodule BenchmarkElixir.Endpoint do
  use Phoenix.Endpoint,
    otp_app: :benchmark_elixir_api

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug BenchmarkElixir.Router
end
