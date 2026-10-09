defmodule BenchmarkElixir.Application do
  use Application

  @impl true
  def start(_type, _args) do
    database_url =
      System.fetch_env!("DATABASE_URL")

    uri = URI.parse(database_url)

    [username, password] =
      String.split(
        uri.userinfo,
        ":",
        parts: 2
      )

    database =
      String.trim_leading(
        uri.path,
        "/"
      )

    children = [
      {
        Postgrex,
        [
          hostname: uri.host,
          port: uri.port || 5432,
          username: username,
          password: password,
          database: database,
          pool_size: 50,
          name: BenchmarkElixir.DB
        ]
      },
      BenchmarkElixir.Endpoint
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: BenchmarkElixir.Supervisor
    )
  end
end
