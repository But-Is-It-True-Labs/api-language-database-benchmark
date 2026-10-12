defmodule BenchmarkElixir.Controller do
  use Phoenix.Controller,
    formats: [:json]

  alias BenchmarkElixir.DB

  def health(conn, _params) do
    case Postgrex.query(DB, "SELECT 1", []) do
      {:ok, _} ->
        json(conn, %{status: "ok"})

      {:error, _} ->
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
         {:ok, result} <-
           Postgrex.query(
             DB,
             """
             SELECT id, account_number, status, created_at, payload
             FROM benchmark_parent
             WHERE id = $1
             """,
             [parent_id]
           ),
         [row] <- result.rows do

      json(
        conn,
        parent_row(row)
      )
    else
      [] ->
        conn
        |> put_status(404)
        |> json(%{error: "parent not found"})

      _ ->
        conn
        |> put_status(500)
        |> json(%{error: "query failed"})
    end
  end

  def children(conn, %{"id" => id}) do
    parent_id =
      String.to_integer(id)

    {:ok, result} =
      Postgrex.query(
        DB,
        """
        SELECT id, parent_id, sequence_number, value_number, payload
        FROM benchmark_child
        WHERE parent_id = $1
        ORDER BY id
        """,
        [parent_id]
      )

    json(
      conn,
      Enum.map(
        result.rows,
        &child_row/1
      )
    )
  end

  def events(conn, %{"id" => id}) do
    parent_id =
      String.to_integer(id)

    {:ok, result} =
      Postgrex.query(
        DB,
        """
        SELECT id, parent_id, event_type, event_time, payload
        FROM benchmark_event
        WHERE parent_id = $1
        ORDER BY event_time DESC, id DESC
        LIMIT 20
        """,
        [parent_id]
      )

    json(
      conn,
      Enum.map(
        result.rows,
        &event_row/1
      )
    )
  end

  def account_parents(
        conn,
        %{"id" => id}
      ) do

    account_id =
      String.to_integer(id)

    {:ok, result} =
      Postgrex.query(
        DB,
        """
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE account_number = $1
        ORDER BY id
        LIMIT 50
        """,
        [account_id]
      )

    json(
      conn,
      Enum.map(
        result.rows,
        &parent_row/1
      )
    )
  end

  def bundle(conn, %{"id" => id}) do
    parent_id =
      String.to_integer(id)

    {:ok, parents} =
      Postgrex.query(
        DB,
        """
        SELECT id, account_number, status, created_at, payload
        FROM benchmark_parent
        WHERE id = $1
        """,
        [parent_id]
      )

    case parents.rows do
      [] ->
        conn
        |> put_status(404)
        |> json(%{
          error: "parent not found"
        })

      [parent] ->

        {:ok, children} =
          Postgrex.query(
            DB,
            """
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
            """,
            [parent_id]
          )

        {:ok, events} =
          Postgrex.query(
            DB,
            """
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            """,
            [parent_id]
          )

        json(
          conn,
          %{
            parent:
              parent_row(parent),

            children:
              Enum.map(
                children.rows,
                &child_row/1
              ),

            events:
              Enum.map(
                events.rows,
                &event_row/1
              )
          }
        )
    end
  end

  def create_event(conn, params) do
    id = params["id"]
    parent_id = params["parent_id"]
    event_type = params["event_type"]
    payload = params["payload"]

    case Postgrex.query(
           DB,
           """
           INSERT INTO benchmark_event
           (id, parent_id, event_type, event_time, payload)
           VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4)
           """,
           [
             id,
             parent_id,
             event_type,
             payload
           ]
         ) do

      {:ok, _} ->
        conn
        |> put_status(201)
        |> json(%{
          created: true,
          id: id
        })

      {:error, _} ->
        conn
        |> put_status(500)
        |> json(%{
          error: "insert failed"
        })
    end
  end


  defp parent_row(
         [
           id,
           account_number,
           status,
           created_at,
           payload
         ]
       ) do

    %{
      id: id,
      account_number: account_number,
      status: status,
      created_at:
        timestamp(created_at),
      payload: payload
    }
  end


  defp child_row(
         [
           id,
           parent_id,
           sequence_number,
           value_number,
           payload
         ]
       ) do

    %{
      id: id,
      parent_id: parent_id,
      sequence_number:
        sequence_number,
      value_number:
        value_number,
      payload: payload
    }
  end


  defp event_row(
         [
           id,
           parent_id,
           event_type,
           event_time,
           payload
         ]
       ) do

    %{
      id: id,
      parent_id: parent_id,
      event_type: event_type,
      event_time:
        timestamp(event_time),
      payload: payload
    }
  end


  defp timestamp(
         %NaiveDateTime{} = value
       ) do

    NaiveDateTime.to_iso8601(
      value
    )
  end

  defp timestamp(value),
    do: to_string(value)
end
