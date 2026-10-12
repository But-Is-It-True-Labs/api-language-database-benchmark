use axum::{extract::{Path,State},http::StatusCode,routing::get,Json,Router};
use mongodb::{bson::{doc,DateTime},Client,Collection};
use serde::{Deserialize,Serialize};
use std::{env,net::SocketAddr};
#[derive(Debug,Serialize,Deserialize)] struct Parent {id:i64,account_number:i64,status:String,created_at:DateTime,payload:String}
#[derive(Clone)] struct App {client:Client,parents:Collection<Parent>}
async fn health(State(s):State<App>)->Result<Json<serde_json::Value>,StatusCode>{s.client.database("admin").run_command(doc!{"ping":1}).await.map_err(|_|StatusCode::SERVICE_UNAVAILABLE)?;Ok(Json(serde_json::json!({"status":"ok"})))}
async fn parent(State(s):State<App>,Path(id):Path<i64>)->Result<Json<serde_json::Value>,StatusCode>{
 let p=s.parents.find_one(doc!{"_id":id}).await.map_err(|_|StatusCode::INTERNAL_SERVER_ERROR)?.ok_or(StatusCode::NOT_FOUND)?;
 let dt=chrono::DateTime::from_timestamp_millis(p.created_at.timestamp_millis()).ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;
 Ok(Json(serde_json::json!({"id":p.id,"account_number":p.account_number,"status":p.status,"created_at":dt.to_rfc3339_opts(chrono::SecondsFormat::Millis,true),"payload":p.payload})))
}
#[tokio::main] async fn main(){let client=Client::with_uri_str(env::var("MONGO_URL").expect("MONGO_URL missing")).await.unwrap();let s=App{parents:client.database("benchmark").collection::<Parent>("benchmark_parent"),client};let app=Router::new().route("/health",get(health)).route("/parent/{id}",get(parent)).with_state(s);let listener=tokio::net::TcpListener::bind(SocketAddr::from(([0,0,0,0],8080))).await.unwrap();axum::serve(listener,app).await.unwrap();}
