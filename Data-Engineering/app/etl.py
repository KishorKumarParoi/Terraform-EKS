from __future__ import annotations

import csv
from collections import defaultdict
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from pathlib import Path

from .db import init_db, insert_raw_sales, replace_summary, truncate_tables
from .metrics import (
    ETL_FAILURES_TOTAL,
    ETL_ROWS_LOADED_TOTAL,
    ETL_RUNS_TOTAL,
    ETL_SUMMARY_ROWS_TOTAL,
)

DATA_FILE = Path(__file__).resolve().parent.parent / "data" / "raw" / "sales.csv"


@dataclass(frozen=True)
class SalesRow:
    order_date: date
    region: str
    product: str
    units: int
    unit_price: Decimal

    @property
    def revenue(self) -> Decimal:
        return (self.unit_price * self.units).quantize(Decimal("0.01"))


def load_sales_rows() -> list[SalesRow]:
    rows: list[SalesRow] = []
    with DATA_FILE.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for record in reader:
            rows.append(
                SalesRow(
                    order_date=date.fromisoformat(record["order_date"]),
                    region=record["region"].strip(),
                    product=record["product"].strip(),
                    units=int(record["units"]),
                    unit_price=Decimal(record["unit_price"]),
                )
            )
    return rows


def build_summary(rows: list[SalesRow]) -> list[tuple]:
    grouped: dict[tuple[date, str], dict[str, Decimal | int]] = defaultdict(
        lambda: {"orders": 0, "units": 0, "revenue": Decimal("0.00")}
    )
    for row in rows:
        key = (row.order_date, row.region)
        grouped[key]["orders"] += 1
        grouped[key]["units"] += row.units
        grouped[key]["revenue"] += row.revenue

    summary_rows: list[tuple] = []
    for (snapshot_date, region), aggregate in sorted(grouped.items()):
        orders = int(aggregate["orders"])
        revenue = Decimal(aggregate["revenue"]).quantize(Decimal("0.01"))
        avg_order_value = (
            (revenue / orders).quantize(Decimal("0.01")) if orders else Decimal("0.00")
        )
        summary_rows.append(
            (
                snapshot_date,
                region,
                orders,
                int(aggregate["units"]),
                revenue,
                avg_order_value,
            )
        )
    return summary_rows


def run_pipeline() -> dict[str, int]:
    try:
        init_db()
        rows = load_sales_rows()
        truncate_tables()
        raw_count = insert_raw_sales(
            (
                row.order_date,
                row.region,
                row.product,
                row.units,
                row.unit_price,
                row.revenue,
            )
            for row in rows
        )
        summary_rows = build_summary(rows)
        summary_count = replace_summary(summary_rows)
        ETL_RUNS_TOTAL.inc()
        ETL_ROWS_LOADED_TOTAL.inc(raw_count)
        ETL_SUMMARY_ROWS_TOTAL.inc(summary_count)
        return {"raw_rows": raw_count, "summary_rows": summary_count}
    except Exception:
        ETL_FAILURES_TOTAL.inc()
        raise


def main() -> None:
    result = run_pipeline()
    print(
        f"ETL complete: raw_rows={result['raw_rows']} summary_rows={result['summary_rows']}"
    )


if __name__ == "__main__":
    main()
