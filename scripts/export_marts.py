"""
Export the three marts from the local DuckDB warehouse to static JSON for
the dashboard. The JSON is committed (small, derived from committed seeds),
so the dashboard runs from a fresh clone with no warehouse — same pattern as
the bundled extracts in my other Pulse dashboards.

Run:  uv run python scripts/export_marts.py   (after `dbt build`)
"""

from __future__ import annotations

import datetime
import json
from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parents[1]
DB_PATH = REPO_ROOT / "data" / "herdpulse.duckdb"
OUT_DIR = REPO_ROOT / "dashboard" / "public" / "data"

MARTS = [
    "mart_state_production_trends",
    "mart_productivity_ranking",
    "mart_herd_consolidation",
]


def jsonable(value):
    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.isoformat()
    return value


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"{DB_PATH} not found — run `make build` first.")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH), read_only=True)

    for mart in MARTS:
        rel = con.sql(f"select * from marts.{mart}")
        cols = rel.columns
        rows = [
            {col: jsonable(val) for col, val in zip(cols, record)}
            for record in rel.fetchall()
        ]
        out_path = OUT_DIR / f"{mart}.json"
        out_path.write_text(json.dumps(rows, separators=(",", ":")))
        print(f"  {out_path.relative_to(REPO_ROOT)}: {len(rows)} rows, {out_path.stat().st_size // 1024} KB")

    con.close()
    print("Done.")


if __name__ == "__main__":
    main()
