"""Download the Olist public datasets (Kaggle, CC BY-NC-SA 4.0) from a GitHub mirror.

Usage: python scripts/download_data.py
Files land in data/raw/. Already-present files are skipped.
"""
from pathlib import Path
import urllib.request

MIRROR = "https://raw.githubusercontent.com/dujiaying/olist/master/data/"
FILES = [
    "olist_customers_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
    "olist_marketing_qualified_leads_dataset.csv",
    "olist_closed_deals_dataset.csv",
]
RAW = Path(__file__).resolve().parents[1] / "data" / "raw"


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        dest = RAW / name
        if dest.exists():
            print(f"skip  {name}")
            continue
        print(f"fetch {name}")
        urllib.request.urlretrieve(MIRROR + name, dest)


if __name__ == "__main__":
    main()
