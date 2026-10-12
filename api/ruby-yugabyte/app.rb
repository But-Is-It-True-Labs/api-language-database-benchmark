require "roda"
require "pg"
require "json"
require "time"

DATABASE_URL = ENV.fetch("DATABASE_URL")


class App < Roda
  plugin :json
  plugin :json_parser

  def self.connection
    Thread.current[:pg_connection] ||= PG.connect(DATABASE_URL)
  end

  route do |r|
    r.on "health" do
      r.get do
        self.class.connection.exec("SELECT 1")
        { status: "ok" }
      rescue
        response.status = 503
        { status: "database unavailable" }
      end
    end

    r.on "parent", Integer do |id|
      r.is do
        r.get do
          result = self.class.connection.exec_params(
            <<~SQL,
              SELECT id, account_number, status, created_at, payload
              FROM benchmark_parent
              WHERE id = $1
            SQL
            [id]
          )

          if result.ntuples == 0
            response.status = 404
            next({ error: "parent not found" })
          end

          row = result[0]

          {
            id: row["id"].to_i,
            account_number: row["account_number"].to_i,
            status: row["status"],
            created_at: row["created_at"],
            payload: row["payload"]
          }
        end
      end

      r.get "children" do
        result = self.class.connection.exec_params(
          <<~SQL,
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
          SQL
          [id]
        )

        result.map do |row|
          {
            id: row["id"].to_i,
            parent_id: row["parent_id"].to_i,
            sequence_number: row["sequence_number"].to_i,
            value_number: row["value_number"].to_i,
            payload: row["payload"]
          }
        end
      end

      r.get "events" do
        result = self.class.connection.exec_params(
          <<~SQL,
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
          SQL
          [id]
        )

        result.map do |row|
          {
            id: row["id"].to_i,
            parent_id: row["parent_id"].to_i,
            event_type: row["event_type"],
            event_time: row["event_time"],
            payload: row["payload"]
          }
        end
      end

      r.get "bundle" do
        parent_result = self.class.connection.exec_params(
          <<~SQL,
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = $1
          SQL
          [id]
        )

        if parent_result.ntuples == 0
          response.status = 404
          next({ error: "parent not found" })
        end

        child_result = self.class.connection.exec_params(
          <<~SQL,
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
          SQL
          [id]
        )

        event_result = self.class.connection.exec_params(
          <<~SQL,
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
          SQL
          [id]
        )

        p = parent_result[0]

        {
          parent: {
            id: p["id"].to_i,
            account_number: p["account_number"].to_i,
            status: p["status"],
            created_at: p["created_at"],
            payload: p["payload"]
          },

          children: child_result.map do |row|
            {
              id: row["id"].to_i,
              parent_id: row["parent_id"].to_i,
              sequence_number: row["sequence_number"].to_i,
              value_number: row["value_number"].to_i,
              payload: row["payload"]
            }
          end,

          events: event_result.map do |row|
            {
              id: row["id"].to_i,
              parent_id: row["parent_id"].to_i,
              event_type: row["event_type"],
              event_time: row["event_time"],
              payload: row["payload"]
            }
          end
        }
      end
    end

    r.on "account", Integer, "parents" do |account_id|
      r.get do
        result = self.class.connection.exec_params(
          <<~SQL,
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE account_number = $1
            ORDER BY id
            LIMIT 50
          SQL
          [account_id]
        )

        result.map do |row|
          {
            id: row["id"].to_i,
            account_number: row["account_number"].to_i,
            status: row["status"],
            created_at: row["created_at"],
            payload: row["payload"]
          }
        end
      end
    end

    r.on "event" do
      r.post do
        body = r.params

        self.class.connection.exec_params(
          <<~SQL,
            INSERT INTO benchmark_event
            (id, parent_id, event_type, event_time, payload)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4)
          SQL
          [
            body["id"].to_i,
            body["parent_id"].to_i,
            body["event_type"],
            body["payload"]
          ]
        )

        response.status = 201

        {
          created: true,
          id: body["id"].to_i
        }
      end
    end

    response.status = 404
    { error: "not found" }
  end
end
