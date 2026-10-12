import Config

config :benchmark_elixir_api, BenchmarkElixir.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  server: true,
  http: [
    ip: {0, 0, 0, 0},
    port: 8080
  ],
  secret_key_base: String.duplicate("a", 64)
