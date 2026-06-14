#!/usr/bin/env python3
"""Check that canonical SQL, Supabase migrations, and run_all.sql stay synchronized."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"
MIGRATIONS = ROOT / "supabase" / "migrations"
BASELINE = MIGRATIONS / "202606140000_init_silkroad.sql"

BASELINE_FILES = [
    "01_create_extensions.sql",
    "02_create_types.sql",
    "03_create_tables.sql",
    "04_create_indexes.sql",
    "05_create_functions.sql",
    "06_create_triggers.sql",
    "07_create_procedures.sql",
    "08_create_views.sql",
    "11_create_permissions.sql",
    "12_optimize_database.sql",
    "13_production_security.sql",
]

INCREMENTAL_PAIRS = {
    "14_auth_profile_and_business_guards.sql": "202606140001_auth_profile_and_business_guards.sql",
    "15_multichannel_concurrency.sql": "202606140002_multichannel_concurrency.sql",
    "16_cursor_low_stock_report.sql": "202606140003_cursor_low_stock_report.sql",
    "17_admin_permission_and_demo_grants.sql": "202606140004_admin_permission_and_demo_grants.sql",
    "18_seed_suppliers.sql": "202606150000_seed_suppliers.sql",
}

REQUIRED_CONTRACT = [
    "vw_product_search_catalog",
    "vw_pos_variant_stock_catalog",
    "vw_product_variant_catalog",
    "vw_stock_by_branch",
    "vw_order_summary",
    "vw_revenue_by_channel",
    "fn_create_order_app",
    "fn_create_purchase_order_app",
    "fn_create_transfer_app",
    "fn_create_adjustment_app",
    "fn_create_return_app",
    "fn_set_inventory_allocation_app",
    "fn_cursor_low_stock_report_app",
]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def expected_baseline() -> str:
    sections = []
    for filename in BASELINE_FILES:
        sections.append(f"-- ===== sql/{filename} =====\n{read(SQL / filename).rstrip()}\n")
    return "\n".join(sections)


def check_run_all(errors: list[str]) -> None:
    content = read(SQL / "run_all.sql")
    includes = re.findall(r"^\\i\s+(.+)$", content, flags=re.MULTILINE)
    if not includes:
        errors.append("sql/run_all.sql does not include any SQL files")
    for relative in includes:
        if not (ROOT / relative).is_file():
            errors.append(f"sql/run_all.sql references missing file: {relative}")
    if "sql/16_cursor_low_stock_report.sql" not in includes:
        errors.append("sql/run_all.sql does not include the cursor report")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-baseline", action="store_true")
    args = parser.parse_args()

    expected = expected_baseline()
    if args.write_baseline:
        BASELINE.write_text(expected, encoding="utf-8", newline="\n")

    errors: list[str] = []
    check_run_all(errors)

    if not BASELINE.is_file() or read(BASELINE) != expected:
        errors.append(f"{BASELINE.relative_to(ROOT)} is not synchronized with canonical SQL")

    for canonical, migration in INCREMENTAL_PAIRS.items():
        canonical_path = SQL / canonical
        migration_path = MIGRATIONS / migration
        if not migration_path.is_file():
            errors.append(f"Missing migration: {migration_path.relative_to(ROOT)}")
        elif read(canonical_path) != read(migration_path):
            errors.append(f"Migration differs from canonical SQL: {migration}")

    all_migrations = "\n".join(read(path) for path in sorted(MIGRATIONS.glob("*.sql")))
    for name in REQUIRED_CONTRACT:
        if name not in all_migrations:
            errors.append(f"Required frontend database contract is missing from migrations: {name}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("SQL canonical files, run_all.sql, and Supabase migrations are synchronized.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
