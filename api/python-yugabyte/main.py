import os
from contextlib import asynccontextmanager
from datetime import datetime

import asyncpg
from fastapi import FastAPI, HTTPException
from fastapi.responses import ORJSONResponse
from pydantic import BaseModel


DATABASE_URL = os.environ["DATABASE_URL"]


class EventRequest(BaseModel):
    id: int
    parent_id: int
    event_type: str
    payload: str


pool: asyncpg.Pool | None = None


def timestamp_value(value: datetime):
    return value.isoformat()


def parent_row(row):
    return {
        "id": row["id"],
        "account_number": row["account_number"],
        "status": row["status"],
        "created_at": timestamp_value(row["created_at"]),
        "payload": row["payload"],
    }


def child_row(row):
    return {
        "id": row["id"],
        "parent_id": row["parent_id"],
        "sequence_number": row["sequence_number"],
        "value_number": row["value_number"],
        "payload": row["payload"],
    }


def event_row(row):
    return {
        "id": row["id"],
        "parent_id": row["parent_id"],
        "event_type": row["event_type"],
        "event_time": timestamp_value(row["event_time"]),
        "payload": row["payload"],
    }


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool

    pool = await asyncpg.create_pool(
        DATABASE_URL,
        min_size=5,
        max_size=50,
        command_timeout=15,
    )

    yield

    await pool.close()


app = FastAPI(
    lifespan=lifespan,
    default_response_class=ORJSONResponse,
)


@app.get("/health")
async def health():
    try:
        async with pool.acquire() as connection:
            await connection.fetchval("SELECT 1")

        return {
            "status": "ok"
        }

    except Exception:
        raise HTTPException(
            status_code=503,
            detail="database unavailable",
        )


@app.get("/parent/{parent_id}")
async def get_parent(parent_id: int):
    async with pool.acquire() as connection:
        row = await connection.fetchrow(
            """
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = $1
            """,
            parent_id,
        )

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="parent not found",
        )

    return parent_row(row)


@app.get("/parent/{parent_id}/children")
async def get_children(parent_id: int):
    async with pool.acquire() as connection:
        rows = await connection.fetch(
            """
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
            """,
            parent_id,
        )

    return [
        child_row(row)
        for row in rows
    ]


@app.get("/parent/{parent_id}/events")
async def get_events(parent_id: int):
    async with pool.acquire() as connection:
        rows = await connection.fetch(
            """
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            """,
            parent_id,
        )

    return [
        event_row(row)
        for row in rows
    ]


@app.get("/parent/{parent_id}/bundle")
async def get_bundle(parent_id: int):
    async with pool.acquire() as connection:
        parent = await connection.fetchrow(
            """
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE id = $1
            """,
            parent_id,
        )

        if parent is None:
            raise HTTPException(
                status_code=404,
                detail="parent not found",
            )

        children = await connection.fetch(
            """
            SELECT id, parent_id, sequence_number, value_number, payload
            FROM benchmark_child
            WHERE parent_id = $1
            ORDER BY id
            """,
            parent_id,
        )

        events = await connection.fetch(
            """
            SELECT id, parent_id, event_type, event_time, payload
            FROM benchmark_event
            WHERE parent_id = $1
            ORDER BY event_time DESC, id DESC
            LIMIT 20
            """,
            parent_id,
        )

    return {
        "parent": parent_row(parent),
        "children": [
            child_row(row)
            for row in children
        ],
        "events": [
            event_row(row)
            for row in events
        ],
    }


@app.get("/account/{account_id}/parents")
async def get_account_parents(account_id: int):
    async with pool.acquire() as connection:
        rows = await connection.fetch(
            """
            SELECT id, account_number, status, created_at, payload
            FROM benchmark_parent
            WHERE account_number = $1
            ORDER BY id
            LIMIT 50
            """,
            account_id,
        )

    return [
        parent_row(row)
        for row in rows
    ]


@app.post("/event", status_code=201)
async def create_event(request: EventRequest):
    async with pool.acquire() as connection:
        await connection.execute(
            """
            INSERT INTO benchmark_event
            (id, parent_id, event_type, event_time, payload)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP, $4)
            """,
            request.id,
            request.parent_id,
            request.event_type,
            request.payload,
        )

    return {
        "created": True,
        "id": request.id,
    }
