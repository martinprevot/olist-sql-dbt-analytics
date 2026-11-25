"""Load the raw CSV files into PostgreSQL, schema `raw`, as-is.

Every column is loaded as TEXT on purpose: the raw layer is an untouched
copy of the source. Typing, cleaning and deduplication happen in the dbt
staging models, where they are versioned and tested.

The loader still normalises the transport layer (UTF-8 BOM, Windows line
endings) so that PostgreSQL's COPY can read every file the same way.
"""
from __future__ import annotations

import csv
import io
import os
import sys
from pathlib import Path

import psycopg2

RAW = Path(__file__).resolve().parents[1] / "data" / "raw"
TABLES = {
    "customers": "olist_customers_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
    "marketing_qualified_leads": "olist_marketing_qualified_leads_dataset.csv",
    "closed_deals": "olist_closed_deals_dataset.csv",
}


def connect():
    # Port 5433 = the Docker container (see docker-compose.yml).
    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5433"),
        user=os.getenv("PGUSER", "olist"),
        password=os.getenv("PGPASSWORD", "olist"),
        dbname=os.getenv("PGDATABASE", "olist"),
    )
    conn.set_client_encoding("UTF8")   # reviews contain accented Portuguese text
    return conn


def load_table(cur, table: str, path: Path) -> int:
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    header, body = rows[0], rows[1:]
    cols = ", ".join(f'"{c.strip()}" text' for c in header)
    cur.execute(f"drop table if exists raw.{table} cascade")
    cur.execute(f"create table raw.{table} ({cols})")
    buf = io.StringIO()
    csv.writer(buf, lineterminator="\n").writerows(body)
    buf.seek(0)
    # Empty fields become NULL (CSV default), quoted empty strings stay ''.
    cur.copy_expert(f"copy raw.{table} from stdin with (format csv)", buf)
    return len(body)


def main():
    missing = [f for f in TABLES.values() if not (RAW / f).exists()]
    if missing:
        sys.exit(f"Missing files: {missing}. Run `python scripts/download_data.py` first.")
    with connect() as conn, conn.cursor() as cur:
        cur.execute("create schema if not exists raw")
        for table, file in TABLES.items():
            n = load_table(cur, table, RAW / file)
            print(f"raw.{table:<26} {n:>9,} rows")
    print("Raw layer loaded.")


if __name__ == "__main__":
    main()
