use std::{
    env,
    net::SocketAddr,
    sync::Arc,
};

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
    Json, Router,
};

use chrono::{DateTime, SecondsFormat, Utc};
use scylla::{
    client::{
        session::Session,
        session_builder::SessionBuilder,
    },
    statement::{
        prepared::PreparedStatement,
        Consistency,
    },
    value::CqlTimestamp,
};
use serde::Serialize;
use serde_json::json;


struct AppState {
    db: Session,
    parent_query: PreparedStatement,
    health_query: PreparedStatement,
}


#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    message: &'static str,
}

impl ApiError {
    fn new(status: StatusCode, message: &'static str) -> Self {
        Self { status, message }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, self.message).into_response()
    }
}


#[derive(Serialize)]
struct Parent {
    id: i64,
    account_number: i64,
    status: String,
    created_at: String,
    payload: String,
}


fn timestamp_string(value: CqlTimestamp) -> Result<String, ApiError> {
    let dt: DateTime<Utc> =
        DateTime::from_timestamp_millis(value.0)
            .ok_or_else(|| {
                ApiError::new(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "invalid timestamp",
                )
            })?;

    Ok(dt.to_rfc3339_opts(SecondsFormat::Secs, true))
}


async fn health(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, ApiError> {

    state
        .db
        .execute_unpaged(
            &state.health_query,
            ("local",),
        )
        .await
        .map_err(|err| {
            eprintln!("health query error: {err}");
            ApiError::new(
                StatusCode::SERVICE_UNAVAILABLE,
                "database unavailable",
            )
        })?;

    Ok(Json(json!({
        "status": "ok"
    })))
}


async fn get_parent(
    State(state): State<Arc<AppState>>,
    Path(id): Path<i64>,
) -> Result<Json<Parent>, ApiError> {

    let result = state
        .db
        .execute_unpaged(
            &state.parent_query,
            (id,),
        )
        .await
        .map_err(|err| {
            eprintln!("parent query error: {err}");
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "query failed",
            )
        })?;

    let rows = result
        .into_rows_result()
        .map_err(|err| {
            eprintln!("row result error: {err}");
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "query failed",
            )
        })?;

    let row = rows
        .maybe_first_row::<(
            i64,
            i64,
            String,
            CqlTimestamp,
            String,
        )>()
        .map_err(|err| {
            eprintln!("row decode error: {err}");
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "query failed",
            )
        })?
        .ok_or_else(|| {
            ApiError::new(
                StatusCode::NOT_FOUND,
                "parent not found",
            )
        })?;

    let (
        id,
        account_number,
        status,
        created_at,
        payload,
    ) = row;

    Ok(Json(Parent {
        id,
        account_number,
        status,
        created_at: timestamp_string(created_at)?,
        payload,
    }))
}


#[tokio::main]
async fn main() {

    let host = env::var("CASSANDRA_HOST")
        .unwrap_or_else(|_| "benchmark_cassandra".to_string());

    let address = format!("{host}:9042");

    let session = SessionBuilder::new()
        .known_node(address)
        .build()
        .await
        .expect("failed to connect to Cassandra");

    session
        .use_keyspace("benchmark", false)
        .await
        .expect("failed to use benchmark keyspace");

    let mut parent_query = session
        .prepare(
            "
            SELECT id, account_number, status, created_at, payload
            FROM parent_by_id
            WHERE id = ?
            ",
        )
        .await
        .expect("failed to prepare parent query");

    parent_query.set_consistency(Consistency::One);

    let mut health_query = session
        .prepare(
            "
            SELECT release_version
            FROM system.local
            WHERE key = ?
            ",
        )
        .await
        .expect("failed to prepare health query");

    health_query.set_consistency(Consistency::One);

    let state = Arc::new(AppState {
        db: session,
        parent_query,
        health_query,
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/parent/{id}", get(get_parent))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));

    println!(
        "Rust Cassandra benchmark API listening on {}",
        addr
    );

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind");

    axum::serve(listener, app)
        .await
        .expect("server error");
}
