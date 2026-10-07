defmodule BenchmarkElixir.Router do
  use Phoenix.Router

  get "/health",
      BenchmarkElixir.Controller,
      :health

  get "/parent/:id",
      BenchmarkElixir.Controller,
      :parent
end
