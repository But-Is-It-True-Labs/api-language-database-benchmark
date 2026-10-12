package main
import (
 "context"; "encoding/json"; "log"; "net/http"; "os"; "strconv"; "strings"; "time"
 "go.mongodb.org/mongo-driver/bson"; "go.mongodb.org/mongo-driver/mongo"; "go.mongodb.org/mongo-driver/mongo/options"
)
var db *mongo.Database
func main(){ uri:=os.Getenv("MONGO_URL");if uri==""{log.Fatal("MONGO_URL missing")};c,e:=mongo.Connect(context.Background(),options.Client().ApplyURI(uri).SetMaxPoolSize(50));if e!=nil{log.Fatal(e)};db=c.Database("benchmark");m:=http.NewServeMux();m.HandleFunc("/health",health);m.HandleFunc("/parent/",parent);log.Fatal(http.ListenAndServe(":8080",m)) }
func respond(w http.ResponseWriter,s int,v any){w.Header().Set("Content-Type","application/json");w.WriteHeader(s);_ = json.NewEncoder(w).Encode(v)}
func health(w http.ResponseWriter,r *http.Request){ctx,cancel:=context.WithTimeout(r.Context(),3*time.Second);defer cancel();if e:=db.Client().Ping(ctx,nil);e!=nil{respond(w,503,map[string]string{"status":"database unavailable"});return};respond(w,200,map[string]string{"status":"ok"})}
func parent(w http.ResponseWriter,r *http.Request){id,e:=strconv.ParseInt(strings.TrimPrefix(r.URL.Path,"/parent/"),10,64);if e!=nil{http.Error(w,"invalid id",400);return};var x struct{ID int64 `bson:"id" json:"id"`;Account int64 `bson:"account_number" json:"account_number"`;Status string `bson:"status" json:"status"`;Created time.Time `bson:"created_at" json:"created_at"`;Payload string `bson:"payload" json:"payload"`};e=db.Collection("benchmark_parent").FindOne(r.Context(),bson.M{"_id":id}).Decode(&x);if e==mongo.ErrNoDocuments{respond(w,404,map[string]string{"error":"parent not found"});return};if e!=nil{log.Println(e);respond(w,500,map[string]string{"error":"query failed"});return};respond(w,200,x)}
