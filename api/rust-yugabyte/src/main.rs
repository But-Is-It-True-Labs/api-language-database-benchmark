use std::{env, net::SocketAddr};

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};

use chrono::{NaiveDateTime, SecondsFormat};
use deadpool_postgres::{Manager, Pool};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tokio_postgres::{NoTls, Row};


#[derive(Clone)]
struct AppState {
    db: Pool,
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


#[derive(Serialize)]
struct Child {
    id: i64,
    parent_id: i64,
    sequence_number: i32,
    value_number: i32,
    payload: String,
}


#[derive(Serialize)]
struct Event {
    id: i64,
    parent_id: i64,
    event_type: String,
    event_time: String,
    payload: String,
}


#[derive(Serialize)]
struct Bundle {
    parent: Parent,
    children: Vec<Child>,
    events: Vec<Event>,
}


#[derive(Deserialize)]
struct EventRequest {
    id: i64,
    parent_id: i64,
    event_type: String,
    payload: String,
}


#[derive(Serialize)]
struct EventCreated {
    created: bool,
    id: i64,
}


fn timestamp_string(value: NaiveDateTime) -> String {
    value
        .and_utc()
        .to_rfc3339_opts(SecondsFormat::Secs, true)
}


fn parent_from_row(row: &Row) -> Parent {
    let created_at: NaiveDateTime = row.get("created_at");

    Parent {
        id: row.get("id"),
        account_number: row.get("account_number"),
        status: row.get("status"),
        created_at: timestamp_string(created_at),
        payload: row.get("payload"),
    }
}


fn child_from_row(row: &Row) -> Child {
    Child {
        id: row.get("id"),
        parent_id: row.get("parent_id"),
        sequence_number: row.get("sequence_number"),
        value_number: row.get("value_number"),
        payload: row.get("payload"),
    }
}


fn event_from_row(row: &Row) -> Event {
    let event_time: NaiveDateTime = row.get("event_time");

    Event {
        id: row.get("id"),
        parent_id: row.get("parent_id"),
        event_type: row.get("event_type"),
        event_time: timestamp_string(event_time),
        payload: row.get("payload"),
    }
}


async fn health(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::SERVICE_UNAVAILABLE,
                "database unavailable",
            )
        })?;

    client
        .query_one("SELECT 1", &[])
        .await
        .map_err(|_| {
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
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<Parent>, ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database pool unavailable",
            )
        })?;

    let row = client
        .query_opt(
            "
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = $1
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
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

    Ok(Json(parent_from_row(&row)))
}


async fn get_children(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<Vec<Child>>, ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database pool unavailable",
            )
        })?;

    let rows = client
        .query(
            "
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "query failed",
            )
        })?;

    let children = rows
        .iter()
        .map(child_from_row)
        .collect();

    Ok(Json(children))
}


async fn get_events(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<Vec<Event>>, ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database pool unavailable",
            )
        })?;

    let rows = client
        .query(
            "
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "query failed",
            )
        })?;

    let events = rows
        .iter()
        .map(event_from_row)
        .collect();

    Ok(Json(events))
}


async fn get_bundle(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<Bundle>, ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database pool unavailable",
            )
        })?;

    let parent_row = client
        .query_opt(
            "
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = $1
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "parent query failed",
            )
        })?
        .ok_or_else(|| {
            ApiError::new(
                StatusCode::NOT_FOUND,
                "parent not found",
            )
        })?;

    let child_rows = client
        .query(
            "
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "child query failed",
            )
        })?;

    let event_rows = client
        .query(
            "
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "event query failed",
            )
        })?;

    let result = Bundle {
        parent: parent_from_row(&parent_row),

        children: child_rows
            .iter()
            .map(child_from_row)
            .collect(),

        events: event_rows
            .iter()
            .map(event_from_row)
            .collect(),
    };

    Ok(Json(result))
}


async fn get_account_parents(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<Vec<Parent>>, ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database pool unavailable",
            )
        })?;

    let rows = client
        .query(
            "
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE account_number = $1
            ORDER BY id
            LIMIT 50
            ",
            &[&id],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "query failed",
            )
        })?;

    let parents = rows
        .iter()
        .map(parent_from_row)
        .collect();

    Ok(Json(parents))
}


async fn create_event(
    State(state): State<AppState>,
    Json(request): Json<EventRequest>,
) -> Result<(StatusCode, Json<EventCreated>), ApiError> {
    let client = state
        .db
        .get()
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "database pool unavailable",
            )
        })?;

    client
        .execute(
            "
            INSERT INTO benchmark_event
            (id, parent_id, event_type, event_time, payload)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4)
            ",
            &[
                &request.id,
                &request.parent_id,
                &request.event_type,
                &request.payload,
            ],
        )
        .await
        .map_err(|_| {
            ApiError::new(
                StatusCode::INTERNAL_SERVER_ERROR,
                "insert failed",
            )
        })?;

    Ok((
        StatusCode::CREATED,
        Json(EventCreated {
            created: true,
            id: request.id,
        }),
    ))
}


#[tokio::main]
async fn main() {
    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL is required");

    let pg_config: tokio_postgres::Config = database_url
        .parse()
        .expect("invalid DATABASE_URL");

    let manager = Manager::new(
        pg_config,
        NoTls,
    );

    let pool = Pool::builder(manager)
        .max_size(50)
        .build()
        .expect("failed to create PostgreSQL pool");

    let state = AppState {
        db: pool,
    };

    let app = Router::new()
        .route(
            "/health",
            get(health),
        )
        .route(
            "/parent/{id}",
            get(get_parent),
        )
        .route(
            "/parent/{id}/children",
            get(get_children),
        )
        .route(
            "/parent/{id}/events",
            get(get_events),
        )
        .route(
            "/parent/{id}/bundle",
            get(get_bundle),
        )
        .route(
            "/account/{id}/parents",
            get(get_account_parents),
        )
        .route(
            "/event",
            post(create_event),
        )
        .with_state(state);

    let address = SocketAddr::from((
        [0, 0, 0, 0],
        8080,
    ));

    let listener = tokio::net::TcpListener::bind(address)
        .await
        .expect("failed to bind port 8080");

    println!(
        "Rust benchmark API listening on :8080"
    );

    axum::serve(listener, app)
        .await
        .expect("server failed");
}
