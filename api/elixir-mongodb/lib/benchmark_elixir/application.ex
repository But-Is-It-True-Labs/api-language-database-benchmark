defmodule BenchmarkElixir.Application do
 use Application
 @impl true
 def start(_type,_args) do
  children=[{Mongo,[url: System.fetch_env!("MONGO_URL"),name: BenchmarkElixir.DB,pool_size: 50]},BenchmarkElixir.Endpoint]
  Supervisor.start_link(children,strategy: :one_for_one,name: BenchmarkElixir.Supervisor)
 end
end
