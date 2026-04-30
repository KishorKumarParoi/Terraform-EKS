from time import perf_counter

from fastapi import FastAPI, Request
from fastapi.responses import PlainTextResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from .db import count_rows, fetch_summary, init_db
from .etl import run_pipeline
from .metrics import API_REQUESTS_TOTAL, API_REQUEST_DURATION_SECONDS

app = FastAPI(title="Data Engineering Starter Kit", version="1.0.0")


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    path = request.url.path
    method = request.method
    start = perf_counter()
    response = await call_next(request)
    duration = perf_counter() - start
    API_REQUEST_DURATION_SECONDS.labels(method=method, path=path).observe(duration)
    API_REQUESTS_TOTAL.labels(
        method=method, path=path, status=str(response.status_code)
    ).inc()
    return response


@app.get("/", response_class=PlainTextResponse)
def home() -> str:
    return "Data Engineering Starter Kit is running"


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "status": "ok",
        "raw_rows": count_rows("raw_sales"),
        "summary_rows": count_rows("sales_summary"),
    }


@app.get("/summary")
def summary() -> dict[str, object]:
    rows = [
        {
            "snapshot_date": row[0].isoformat(),
            "region": row[1],
            "total_orders": row[2],
            "total_units": row[3],
            "total_revenue": float(row[4]),
            "avg_order_value": float(row[5]),
        }
        for row in fetch_summary()
    ]
    return {"count": len(rows), "rows": rows}


@app.post("/refresh")
def refresh() -> dict[str, object]:
    result = run_pipeline()
    return {"status": "refreshed", **result}


@app.get("/metrics")
def metrics() -> PlainTextResponse:
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)
