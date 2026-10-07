import asyncio
import os
from contextlib import asynccontextmanager
from datetime import timezone

from cassandra import ConsistencyLevel
from cassandra.cluster import Cluster
from cassandra.query import SimpleStatement
from fastapi import FastAPI, HTTPException
from fastapi.responses import ORJSONResponse


CASSANDRA_HOST = os.environ.get(
    "CASSANDRA_HOST",
    "benchmark_cassandra",
)

cluster = None
session = None
parent_statement = None
health_statement = None


def timestamp_value(value):
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)

    return (
        value
        .astimezone(timezone.utc)
        .isoformat()
        .replace("+00:00", "Z")
    )


def parent_row(row):
    return {
        "id": row.id,
        "account_number": row.account_number,
        "status": row.status,
        "created_at": timestamp_value(row.created_at),
        "payload": row.payload,
    }


async def execute_cassandra(statement, parameters=None):
    loop = asyncio.get_running_loop()
    future = loop.create_future()

    response = session.execute_async(
        statement,
        parameters,
    )

    def success(result):
        def complete():
            if not future.done():
                future.set_result(result)

        loop.call_soon_threadsafe(complete)

    def failure(error):
        def complete():
            if not future.done():
                future.set_exception(error)

        loop.call_soon_threadsafe(complete)

    response.add_callbacks(
        callback=success,
        errback=failure,
    )

    return await future


@asynccontextmanager
async def lifespan(app: FastAPI):
    global cluster
    global session
    global parent_statement
    global health_statement

    cluster = Cluster([
        CASSANDRA_HOST
    ])

    session = cluster.connect("benchmark")

    parent_statement = session.prepare(
        """
        SELECT id, account_number, status, created_at, payload
        FROM parent_by_id
        WHERE id = ?
        """
    )

    parent_statement.consistency_level = (
        ConsistencyLevel.ONE
    )

    health_statement = SimpleStatement(
        """
        SELECT release_version
        FROM system.local
        WHERE key = 'local'
        """,
        consistency_level=ConsistencyLevel.ONE,
    )

    yield

    cluster.shutdown()


app = FastAPI(
    lifespan=lifespan,
    default_response_class=ORJSONResponse,
)


@app.get("/health")
async def health():
    try:
        await execute_cassandra(
            health_statement
        )

        return {
            "status": "ok"
        }

    except Exception as error:
        print(
            f"health query error: {error}",
            flush=True,
        )

        raise HTTPException(
            status_code=503,
            detail="database unavailable",
        )


@app.get("/parent/{parent_id}")
async def get_parent(parent_id: int):
    try:
        result = await execute_cassandra(
            parent_statement,
            (parent_id,),
        )

    except Exception as error:
        print(
            f"parent query error: {error}",
            flush=True,
        )

        raise HTTPException(
            status_code=500,
            detail="query failed",
        )

    row = result[0] if result else None

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="parent not found",
        )

    return parent_row(row)
