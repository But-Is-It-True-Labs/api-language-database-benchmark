defmodule BenchmarkElixir.Controller do
  use Phoenix.Controller
 import Plug.Conn
 defp respond(conn,code,body),do: conn |> put_resp_content_type("application/json") |> send_resp(code,Jason.encode!(body))
 def health(conn,_params) do
  case Mongo.command(BenchmarkElixir.DB,[ping: 1]) do
   {:ok,_} -> respond(conn,200,%{status: "ok"})
   _ -> respond(conn,503,%{status: "database unavailable"})
  end
 end
 def parent(conn,%{"id"=>text}) do
  case Integer.parse(text) do
   {id,""} ->
    case Mongo.find_one(BenchmarkElixir.DB,"benchmark_parent",%{"_id"=>id}) do
     nil -> respond(conn,404,%{error: "parent not found"})
     p -> respond(conn,200,%{id: p["id"],account_number: p["account_number"],status: p["status"],created_at: p["created_at"],payload: p["payload"]})
    end
   _ -> respond(conn,400,%{error: "invalid id"})
  end
 end
end
