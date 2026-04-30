from prometheus_client import Counter, Histogram

ETL_RUNS_TOTAL = Counter("etl_runs_total", "Total ETL runs")
ETL_ROWS_LOADED_TOTAL = Counter("etl_rows_loaded_total", "Total raw rows loaded")
ETL_SUMMARY_ROWS_TOTAL = Counter("etl_summary_rows_total", "Total summary rows written")
ETL_FAILURES_TOTAL = Counter("etl_failures_total", "Total ETL failures")
API_REQUESTS_TOTAL = Counter(
    "api_requests_total", "Total API requests", ["method", "path", "status"]
)
API_REQUEST_DURATION_SECONDS = Histogram(
    "api_request_duration_seconds",
    "API request duration in seconds",
    ["method", "path"],
)
