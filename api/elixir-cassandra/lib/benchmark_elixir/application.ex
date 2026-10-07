defmodule BenchmarkElixir.Application do
  use Application

  @impl true
  def start(_type, _args) do
    host =
      System.get_env(
        "CASSANDRA_HOST",
        "benchmark_cassandra"
      )

    children = [
      {
        Xandra.Cluster,
        [
          nodes: ["#{host}:9042"],
          keyspace: "benchmark",
          pool_size: 50,
          default_consistency: :one,
          sync_connect: 10_000,
          name: BenchmarkElixir.DB
        ]
      },
      BenchmarkElixir.Queries,
      BenchmarkElixir.Endpoint
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: BenchmarkElixir.Supervisor
    )
  end
end
