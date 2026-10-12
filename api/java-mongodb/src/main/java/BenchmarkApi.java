import com.mongodb.client.*;
import org.bson.Document;
import static com.mongodb.client.model.Filters.eq;
import io.vertx.core.Vertx;
import io.vertx.ext.web.Router;
import java.time.Instant;
import java.util.Map;
public class BenchmarkApi {
 public static void main(String[] args) {
  var mongo=MongoClients.create(System.getenv("MONGO_URL"));
  var collection=mongo.getDatabase("benchmark").getCollection("benchmark_parent");
  var vertx=Vertx.vertx();var router=Router.router(vertx);
  router.get("/health").handler(ctx-> vertx.executeBlocking(p->{try{mongo.getDatabase("admin").runCommand(new Document("ping",1));p.complete();}catch(Exception e){p.fail(e);}},res->{ctx.response().putHeader("Content-Type","application/json").setStatusCode(res.succeeded()?200:503).end(res.succeeded()?"{\"status\":\"ok\"}":"{\"status\":\"database unavailable\"}");}));
  router.get("/parent/:id").handler(ctx->{long id;try{id=Long.parseLong(ctx.pathParam("id"));}catch(Exception e){ctx.response().setStatusCode(400).end("invalid id");return;}
    vertx.<Document>executeBlocking(p->{try{p.complete(collection.find(eq("_id",id)).first());}catch(Exception e){p.fail(e);}},result->{
       if(result.failed()){ctx.response().setStatusCode(500).end("query failed");return;}
       var doc=result.result();if(doc==null){ctx.response().setStatusCode(404).end("parent not found");return;}
       var json=new io.vertx.core.json.JsonObject().put("id",doc.getLong("id")).put("account_number",doc.getLong("account_number")).put("status",doc.getString("status")).put("created_at",doc.getDate("created_at").toInstant().toString()).put("payload",doc.getString("payload"));
       ctx.response().putHeader("Content-Type","application/json").end(json.encode());
    });
  });
  vertx.createHttpServer().requestHandler(router).listen(8080,"0.0.0.0");
 }
}
