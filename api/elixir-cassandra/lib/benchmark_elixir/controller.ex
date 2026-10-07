defmodule BenchmarkElixir.Controller do
  use Phoenix.Controller,
    formats: [:json]

  alias BenchmarkElixir.DB
  alias BenchmarkElixir.Queries

  def health(conn, _params) do
    case Xandra.Cluster.execute(
           DB,
           Queries.health(),
           ["local"],
           consistency: :one
         ) do

      {:ok, _result} ->
        json(
          conn,
          %{status: "ok"}
        )

      {:error, error} ->
        IO.inspect(
          error,
          label: "health query error"
        )

        conn
        |> put_status(503)
        |> json(%{
          status: "database unavailable"
        })
    end
  end


  def parent(conn, %{"id" => id}) do
    with {parent_id, ""} <-
           Integer.parse(id),

         {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(
             DB,
             Queries.parent(),
             [parent_id],
             consistency: :one
           ),

         [row] <-
           Enum.take(page, 1) do

      json(
        conn,
        parent_row(row)
      )

    else
      [] ->
        conn
        |> put_status(404)
        |> json(%{
          error: "parent not found"
        })

      {:error, error} ->
        IO.inspect(
          error,
          label: "parent query error"
        )

        conn
        |> put_status(500)
        |> json(%{
          error: "query failed"
        })

      _ ->
        conn
        |> put_status(400)
        |> json(%{
          error: "invalid parent id"
        })
    end
  end


  defp parent_row(row) do
    %{
      id:
        row["id"],

      account_number:
        row["account_number"],

      status:
        row["status"],

      created_at:
        timestamp(
          row["created_at"]
        ),

      payload:
        row["payload"]
    }
  end


  defp timestamp(
         %DateTime{} = value
       ) do

    DateTime.to_iso8601(
      value
    )
  end


  defp timestamp(value),
    do: value
end
