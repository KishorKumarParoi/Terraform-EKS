from contextlib import contextmanager
from typing import Iterable

import psycopg2
from psycopg2.extras import execute_values

from .config import settings

RAW_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS raw_sales (
    id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL,
    region TEXT NOT NULL,
    product TEXT NOT NULL,
    units INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    revenue NUMERIC(12, 2) NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
"""

SUMMARY_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS sales_summary (
    snapshot_date DATE NOT NULL,
    region TEXT NOT NULL,
    total_orders INTEGER NOT NULL,
    total_units INTEGER NOT NULL,
    total_revenue NUMERIC(12, 2) NOT NULL,
    avg_order_value NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (snapshot_date, region)
)
"""


@contextmanager
def get_connection():
    connection = psycopg2.connect(settings.database_url)
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def init_db() -> None:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(RAW_TABLE_SQL)
            cursor.execute(SUMMARY_TABLE_SQL)


def truncate_tables() -> None:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("TRUNCATE TABLE raw_sales RESTART IDENTITY CASCADE")
            cursor.execute("TRUNCATE TABLE sales_summary RESTART IDENTITY CASCADE")


def insert_raw_sales(rows: Iterable[tuple]) -> int:
    row_list = list(rows)
    if not row_list:
        return 0

    insert_sql = """
    INSERT INTO raw_sales (order_date, region, product, units, unit_price, revenue)
    VALUES %s
    """

    with get_connection() as connection:
        with connection.cursor() as cursor:
            execute_values(cursor, insert_sql, row_list)
    return len(row_list)


def replace_summary(rows: Iterable[tuple]) -> int:
    row_list = list(rows)
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("TRUNCATE TABLE sales_summary RESTART IDENTITY CASCADE")
            if row_list:
                execute_values(
                    cursor,
                    """
                    INSERT INTO sales_summary (
                        snapshot_date, region, total_orders, total_units, total_revenue, avg_order_value
                    ) VALUES %s
                    """,
                    row_list,
                )
    return len(row_list)


def fetch_summary():
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT snapshot_date, region, total_orders, total_units, total_revenue, avg_order_value
                FROM sales_summary
                ORDER BY snapshot_date DESC, region ASC
                """)
            return cursor.fetchall()


def count_rows(table_name: str) -> int:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            return int(cursor.fetchone()[0])
