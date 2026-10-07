defmodule BenchmarkElixir.Queries do
  use GenServer

  alias BenchmarkElixir.DB

  @parent_key {__MODULE__, :parent}
  @health_key {__MODULE__, :health}

  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      :ok,
      name: __MODULE__
    )
  end

  @impl true
  def init(:ok) do
    parent =
      Xandra.Cluster.prepare!(
        DB,
        """
        SELECT id, account_number, status, created_at, payload
        FROM parent_by_id
        WHERE id = ?
        """
      )

    health =
      Xandra.Cluster.prepare!(
        DB,
        """
        SELECT release_version
        FROM system.local
        WHERE key = ?
        """
      )

    :persistent_term.put(
      @parent_key,
      parent
    )

    :persistent_term.put(
      @health_key,
      health
    )

    {:ok, %{}}
  end

  def parent do
    :persistent_term.get(
      @parent_key
    )
  end

  def health do
    :persistent_term.get(
      @health_key
    )
  end
end
