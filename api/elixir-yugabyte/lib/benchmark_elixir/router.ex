defmodule BenchmarkElixir.Router do
  use Phoenix.Router

  get "/health",
      BenchmarkElixir.Controller,
      :health

  get "/parent/:id",
      BenchmarkElixir.Controller,
      :parent

  get "/parent/:id/children",
      BenchmarkElixir.Controller,
      :children

  get "/parent/:id/events",
      BenchmarkElixir.Controller,
      :events

  get "/parent/:id/bundle",
      BenchmarkElixir.Controller,
      :bundle

  get "/account/:id/parents",
      BenchmarkElixir.Controller,
      :account_parents

  post "/event",
       BenchmarkElixir.Controller,
       :create_event
end
