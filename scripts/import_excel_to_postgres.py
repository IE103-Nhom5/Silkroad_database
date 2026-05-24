"""
Import dữ liệu sản phẩm từ Excel vào PostgreSQL/Supabase.

Cách chạy:
    pip install -r requirements.txt
    cp .env.example .env
    python scripts/import_excel_to_postgres.py

Yêu cầu file Excel có các sheet:
    - products
    - variants
    - stock

Script này là bản khung để nhóm tùy chỉnh theo file import thực tế.
Không hard-code mật khẩu database trong file này.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import pandas as pd
import psycopg
from dotenv import load_dotenv


REQUIRED_PRODUCT_COLUMNS = {
    "category_slug",
    "product_name",
    "slug",
    "brand",
    "gender",
    "default_selling_price",
    "tags",
    "collection_name",
    "dynamic_attributes",
}

REQUIRED_VARIANT_COLUMNS = {
    "product_slug",
    "size",
    "color",
    "sku",
    "barcode",
    "cost_price",
    "selling_price",
    "weight",
}

REQUIRED_STOCK_COLUMNS = {
    "branch_name",
    "sku",
    "quantity",
    "reserved_quantity",
    "min_stock_level",
    "max_stock_level",
}


def require_columns(df: pd.DataFrame, required: set[str], sheet_name: str) -> None:
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Sheet '{sheet_name}' thiếu cột: {sorted(missing)}")


def parse_tags(value: object) -> list[str]:
    if pd.isna(value):
        return []
    return [item.strip() for item in str(value).split(",") if item.strip()]


def parse_jsonb(value: object) -> dict:
    if pd.isna(value) or value == "":
        return {}
    if isinstance(value, dict):
        return value
    return json.loads(str(value))


def import_products(conn: psycopg.Connection, products_df: pd.DataFrame) -> None:
    require_columns(products_df, REQUIRED_PRODUCT_COLUMNS, "products")

    with conn.cursor() as cur:
        for row in products_df.to_dict("records"):
            cur.execute(
                """
                INSERT INTO PRODUCT (
                    CategoryID,
                    ProductName,
                    Slug,
                    Brand,
                    Gender,
                    DefaultSellingPrice,
                    Tags,
                    CollectionName,
                    DynamicAttributes
                )
                SELECT
                    pc.CategoryID,
                    %(product_name)s,
                    %(slug)s,
                    %(brand)s,
                    %(gender)s::product_gender,
                    %(default_selling_price)s,
                    %(tags)s,
                    %(collection_name)s,
                    %(dynamic_attributes)s::jsonb
                FROM PRODUCT_CATEGORY pc
                WHERE pc.Slug = %(category_slug)s
                ON CONFLICT (Slug) DO UPDATE SET
                    ProductName = EXCLUDED.ProductName,
                    Brand = EXCLUDED.Brand,
                    Gender = EXCLUDED.Gender,
                    DefaultSellingPrice = EXCLUDED.DefaultSellingPrice,
                    Tags = EXCLUDED.Tags,
                    CollectionName = EXCLUDED.CollectionName,
                    DynamicAttributes = EXCLUDED.DynamicAttributes,
                    UpdatedAt = NOW();
                """,
                {
                    **row,
                    "tags": parse_tags(row.get("tags")),
                    "dynamic_attributes": json.dumps(parse_jsonb(row.get("dynamic_attributes")), ensure_ascii=False),
                },
            )


def import_variants(conn: psycopg.Connection, variants_df: pd.DataFrame) -> None:
    require_columns(variants_df, REQUIRED_VARIANT_COLUMNS, "variants")

    with conn.cursor() as cur:
        for row in variants_df.to_dict("records"):
            cur.execute(
                """
                INSERT INTO PRODUCT_VARIANT (
                    ProductID,
                    SizeAttributeID,
                    ColorAttributeID,
                    SKU,
                    Barcode,
                    CostPrice,
                    SellingPrice,
                    Weight
                )
                SELECT
                    p.ProductID,
                    size_attr.AttributeID,
                    color_attr.AttributeID,
                    %(sku)s,
                    %(barcode)s,
                    %(cost_price)s,
                    %(selling_price)s,
                    %(weight)s
                FROM PRODUCT p
                LEFT JOIN ATTRIBUTE size_attr
                    ON size_attr.AttributeType = 'size'
                   AND size_attr.Value = %(size)s
                LEFT JOIN ATTRIBUTE color_attr
                    ON color_attr.AttributeType = 'color'
                   AND color_attr.Value = %(color)s
                WHERE p.Slug = %(product_slug)s
                ON CONFLICT (SKU) DO UPDATE SET
                    Barcode = EXCLUDED.Barcode,
                    CostPrice = EXCLUDED.CostPrice,
                    SellingPrice = EXCLUDED.SellingPrice,
                    Weight = EXCLUDED.Weight;
                """,
                row,
            )


def import_stock(conn: psycopg.Connection, stock_df: pd.DataFrame) -> None:
    require_columns(stock_df, REQUIRED_STOCK_COLUMNS, "stock")

    with conn.cursor() as cur:
        for row in stock_df.to_dict("records"):
            cur.execute(
                """
                INSERT INTO STOCK (
                    BranchID,
                    VariantID,
                    Quantity,
                    ReservedQuantity,
                    MinStockLevel,
                    MaxStockLevel
                )
                SELECT
                    b.BranchID,
                    pv.VariantID,
                    %(quantity)s,
                    %(reserved_quantity)s,
                    %(min_stock_level)s,
                    %(max_stock_level)s
                FROM BRANCH b
                JOIN PRODUCT_VARIANT pv ON pv.SKU = %(sku)s
                WHERE b.BranchName = %(branch_name)s
                ON CONFLICT (BranchID, VariantID) DO UPDATE SET
                    Quantity = EXCLUDED.Quantity,
                    ReservedQuantity = EXCLUDED.ReservedQuantity,
                    MinStockLevel = EXCLUDED.MinStockLevel,
                    MaxStockLevel = EXCLUDED.MaxStockLevel,
                    LastUpdated = NOW();
                """,
                row,
            )


def main() -> None:
    load_dotenv()

    database_url = os.environ.get("DATABASE_URL")
    excel_path = Path(os.environ.get("IMPORT_EXCEL_PATH", "import/sample_import.xlsx"))

    if not database_url:
        raise RuntimeError("Thiếu DATABASE_URL trong file .env")

    if not excel_path.exists():
        raise FileNotFoundError(f"Không tìm thấy file Excel: {excel_path}")

    products_df = pd.read_excel(excel_path, sheet_name="products")
    variants_df = pd.read_excel(excel_path, sheet_name="variants")
    stock_df = pd.read_excel(excel_path, sheet_name="stock")

    with psycopg.connect(database_url) as conn:
        import_products(conn, products_df)
        import_variants(conn, variants_df)
        import_stock(conn, stock_df)
        conn.commit()

    print("Import dữ liệu hoàn tất.")


if __name__ == "__main__":
    main()
