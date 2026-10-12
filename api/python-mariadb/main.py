import os
from contextlib import asynccontextmanager
from datetime import datetime
from urllib.parse import urlparse, unquote

import asyncmy
from asyncmy.cursors import DictCursor
from fastapi import FastAPI, HTTPException
from fastapi.responses import ORJSONResponse
from pydantic import BaseModel

DATABASE_URL = os.environ["DATABASE_URL"]

class EventRequest(BaseModel):
    id: int
    parent_id: int
    event_type: str
    payload: str

pool = None

def timestamp_value(value):
    if isinstance(value, datetime):
        return value.isoformat()
    return value

def parent_row(row):
    return {"id": int(row["id"]), "account_number": int(row["account_number"]), "status": row["status"], "created_at": timestamp_value(row["created_at"]), "payload": row["payload"]}

def child_row(row):
    return {"id": int(row["id"]), "parent_id": int(row["parent_id"]), "sequence_number": int(row["sequence_number"]), "value_number": int(row["value_number"]), "payload": row["payload"]}

def event_row(row):
    return {"id": int(row["id"]), "parent_id": int(row["parent_id"]), "event_type": row["event_type"], "event_time": timestamp_value(row["event_time"]), "payload": row["payload"]}

@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    u = urlparse(DATABASE_URL)
    pool = await asyncmy.create_pool(
        host=u.hostname,
        port=u.port or 3306,
        user=unquote(u.username or ""),
        password=unquote(u.password or ""),
        db=(u.path or "/").lstrip("/"),
        minsize=5,
        maxsize=50,
        autocommit=True,
    )
    yield
    pool.close()
    await pool.wait_closed()

app = FastAPI(lifespan=lifespan, default_response_class=ORJSONResponse)

async def fetchone(sql, params=()):
    async with pool.acquire() as conn:
        async with conn.cursor(DictCursor) as cur:
            await cur.execute(sql, params)
            return await cur.fetchone()

async def fetchall(sql, params=()):
    async with pool.acquire() as conn:
        async with conn.cursor(DictCursor) as cur:
            await cur.execute(sql, params)
            return await cur.fetchall()

@app.get("/health")
async def health():
    try:
        row = await fetchone("SELECT 1 AS ok")
        return {"status": "ok"} if row else (_ for _ in ()).throw(Exception())
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")

@app.get("/parent/{parent_id}")
async def get_parent(parent_id: int):
    row = await fetchone("SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = %s", (parent_id,))
    if row is None: raise HTTPException(status_code=404, detail="parent not found")
    return parent_row(row)

@app.get("/parent/{parent_id}/children")
async def get_children(parent_id: int):
    rows = await fetchall("SELECT id, parent_id, sequence_number, value_number, payload FROM benchmark_child WHERE parent_id = %s ORDER BY id", (parent_id,))
    return [child_row(row) for row in rows]

@app.get("/parent/{parent_id}/events")
async def get_events(parent_id: int):
    rows = await fetchall("SELECT id, parent_id, event_type, event_time, payload FROM benchmark_event WHERE parent_id = %s ORDER BY event_time DESC, id DESC LIMIT 20", (parent_id,))
    return [event_row(row) for row in rows]

@app.get("/parent/{parent_id}/bundle")
async def get_bundle(parent_id: int):
    async with pool.acquire() as conn:
        async with conn.cursor(DictCursor) as cur:
            await cur.execute("SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE id = %s", (parent_id,))
            parent = await cur.fetchone()
            if parent is None: raise HTTPException(status_code=404, detail="parent not found")
            await cur.execute("SELECT id, parent_id, sequence_number, value_number, payload FROM benchmark_child WHERE parent_id = %s ORDER BY id", (parent_id,))
            children = await cur.fetchall()
            await cur.execute("SELECT id, parent_id, event_type, event_time, payload FROM benchmark_event WHERE parent_id = %s ORDER BY event_time DESC, id DESC LIMIT 20", (parent_id,))
            events = await cur.fetchall()
    return {"parent": parent_row(parent), "children": [child_row(r) for r in children], "events": [event_row(r) for r in events]}

@app.get("/account/{account_id}/parents")
async def get_account_parents(account_id: int):
    rows = await fetchall("SELECT id, account_number, status, created_at, payload FROM benchmark_parent WHERE account_number = %s ORDER BY id LIMIT 50", (account_id,))
    return [parent_row(row) for row in rows]

@app.post("/event", status_code=201)
async def create_event(request: EventRequest):
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO benchmark_event (id, parent_id, event_type, event_time, payload) VALUES (%s, %s, %s, CURRENT_TIMESTAMP, %s)",
                (request.id, request.parent_id, request.event_type, request.payload),
            )
    return {"created": True, "id": request.id}
