require "roda"
require "cassandra"
require "json"
require "time"


CASSANDRA_HOST =
  ENV.fetch(
    "CASSANDRA_HOST",
    "benchmark_cassandra"
  )


CLUSTER =
  Cassandra.cluster(
    hosts: [CASSANDRA_HOST],
    port: 9042,
    datacenter: "datacenter1",
    consistency: :one,
    protocol_version: 4,
    synchronize_schema: false
  )


SESSION =
  CLUSTER.connect(
    "benchmark"
  )


PARENT_QUERY =
  SESSION.prepare(
    <<~CQL
      SELECT
        id,
        account_number,
        status,
        created_at,
        payload
      FROM parent_by_id
      WHERE id = ?
    CQL
  )


HEALTH_QUERY =
  SESSION.prepare(
    <<~CQL
      SELECT release_version
      FROM system.local
      WHERE key = ?
    CQL
  )


class App < Roda
  plugin :json
  plugin :json_parser


  route do |r|

    r.on "health" do
      r.get do
        begin

          SESSION.execute(
            HEALTH_QUERY,
            arguments: ["local"],
            consistency: :one
          )

          {
            status: "ok"
          }

        rescue => error

          warn(
            "health query error: #{error.class}: #{error.message}"
          )

          response.status = 503

          {
            status: "database unavailable"
          }

        end
      end
    end


    r.on "parent", Integer do |id|

      r.is do
        r.get do
          begin

            result =
              SESSION.execute(
                PARENT_QUERY,
                arguments: [id],
                consistency: :one
              )

            row =
              result.first


            unless row
              response.status = 404

              next({
                error: "parent not found"
              })
            end


            created_at =
              row["created_at"]

            if created_at.respond_to?(:utc)
              created_at =
                created_at
                  .utc
                  .iso8601
            end


            {
              id:
                row["id"],

              account_number:
                row["account_number"],

              status:
                row["status"],

              created_at:
                created_at,

              payload:
                row["payload"]
            }

          rescue => error

            warn(
              "parent query error: #{error.class}: #{error.message}"
            )

            response.status = 500

            {
              error: "query failed"
            }

          end
        end
      end
    end
  end
end
