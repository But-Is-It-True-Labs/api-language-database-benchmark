require "roda"
require "mysql2"
require "uri"
require "json"
require "time"

DATABASE_URL = ENV.fetch("DATABASE_URL")


class App < Roda
  plugin :json
  plugin :json_parser

  def self.connection
    Thread.current[:mysql_connection] ||= begin
      uri = URI.parse(DATABASE_URL)
      Mysql2::Client.new(
        host: uri.host,
        port: uri.port || 3306,
        username: URI.decode_www_form_component(uri.user || ""),
        password: URI.decode_www_form_component(uri.password || ""),
        database: uri.path.sub(%r{^/}, ""),
        reconnect: true,
        cast: true
      )
    end
  end

  def self.parent_statement
    Thread.current[:mysql_parent_statement] ||= connection.prepare(
      "SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = ?"
    )
  end

  route do |r|
    r.on "health" do
      r.get do
        self.class.connection.query("SELECT 1")
        { status: "ok" }
      rescue
        response.status = 503
        { status: "database unavailable" }
      end
    end

    r.on "parent", Integer do |id|
      r.is do
        r.get do
          result = self.class.parent_statement.execute(id)

          if result.count == 0
            response.status = 404
            next({ error: "parent not found" })
          end

          row = result.first

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
        result = self.class.connection.prepare(
          <<~SQL
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = ?
            ORDER BY id
          SQL
          ).execute(id)

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
        result = self.class.connection.prepare(
          <<~SQL
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = ?
            ORDER BY event_time DESC, id DESC
            LIMIT 20
          SQL
          ).execute(id)

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
        parent_result = self.class.connection.prepare(
          <<~SQL
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = ?
          SQL
          ).execute(id)

        if parent_result.count == 0
          response.status = 404
          next({ error: "parent not found" })
        end

        child_result = self.class.connection.prepare(
          <<~SQL
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = ?
            ORDER BY id
          SQL
          ).execute(id)

        event_result = self.class.connection.prepare(
          <<~SQL
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = ?
            ORDER BY event_time DESC, id DESC
            LIMIT 20
          SQL
          ).execute(id)

        p = parent_result.first

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
        result = self.class.connection.prepare(
          <<~SQL
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE account_number = ?
            ORDER BY id
            LIMIT 50
          SQL
          ).execute(account_id)

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

        self.class.connection.prepare(
          <<~SQL
            INSERT INTO benchmark_event
            (id, parent_id, event_type, event_time, payload)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?)
          SQL
        ).execute(
          body["id"].to_i,
          body["parent_id"].to_i,
          body["event_type"],
          body["payload"]
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
