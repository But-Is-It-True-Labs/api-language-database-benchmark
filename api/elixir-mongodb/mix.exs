defmodule BenchmarkElixir.MixProject do
 use Mix.Project
 def project,do: [app: :benchmark_elixir_api,version: "0.1.0",elixir: "~> 1.18",start_permanent: Mix.env()==:prod,deps: deps()]
 def application,do: [extra_applications: [:logger],mod: {BenchmarkElixir.Application,[]}]
 defp deps,do: [{:phoenix,"~> 1.8"},{:bandit,"~> 1.8"},{:mongodb_driver, "~> 1.6.4"},{:jason,"~> 1.4"}]
end
