"""
Fetch the four HerdPulse source pulls from the USDA NASS Quick Stats API
and land them as dbt seed CSVs under seeds/nass/.

The pulls (all SURVEY / ANIMALS & PRODUCTS / DAIRY / STATE level, 2015+)
are documented in NASS_DOWNLOAD.md and data/README.md:

    1. Milk production, monthly by state (lb)
    2. Milk per cow, monthly by state (lb/head)
    3. Milk cow inventory, by state
    4. Licensed dairy herds, annual by state

Design notes:
  * The API key comes from NASS_API_KEY in a gitignored .env — never committed,
    never printed.
  * Each pull is pre-checked with get_counts (the API caps a call at 50,000
    rows; every pull here is a few thousand at most).
  * NASS short_desc strings are exact and occasionally drift. On a zero-count
    or 400 response, the script drops short_desc, asks get_param_values for
    the currently valid strings, and retries with the closest match — logged,
    so the seed provenance stays explicit.
  * Rows are written with a trimmed, stable column set (the full Quick Stats
    payload has ~39 columns; the dropped ones are constants of the query or
    empty at this aggregation level). The `value` column is left VERBATIM —
    commas and suppression codes like (D)/(NA)/(Z) intact — parsing belongs
    to dbt staging, so the seed stays a faithful snapshot of the pull.
  * Output is sorted (year, state_alpha, period) so re-pulls diff cleanly.

Run:  uv run python scripts/fetch_nass.py
"""

from __future__ import annotations

import csv
import difflib
import io
import os
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv

API_BASE = "https://quickstats.nass.usda.gov/api"
REPO_ROOT = Path(__file__).resolve().parents[1]
SEED_DIR = REPO_ROOT / "seeds" / "nass"

# Columns kept in the seeds, in order. Quick Stats names the state FIPS
# column `state_fips_code` and the measurement column `Value`; both are
# normalized here.
SEED_COLUMNS = [
    "year",
    "freq_desc",
    "reference_period_desc",
    "state_name",
    "state_alpha",
    "state_fips",
    "short_desc",
    "unit_desc",
    "value",
]

SOURCE_COLUMN_ALIASES = {
    "state_fips": ("state_fips_code", "state_fips"),
    "value": ("Value", "value", "VALUE"),
}

# Both grains are pulled for every series: STATE rows feed the state marts,
# NATIONAL rows (state_alpha = 'US') feed the KPI strip and the
# sum-of-states-reconciles-to-national singular test.
AGG_LEVELS = ("STATE", "NATIONAL")

COMMON_PARAMS = {
    "source_desc": "SURVEY",
    "sector_desc": "ANIMALS & PRODUCTS",
    "year__GE": "2015",
}

# Note: milk-cow inventory lives under group LIVESTOCK / commodity CATTLE in
# Quick Stats (not DAIRY), even though it is published in the Milk Production
# report — hence the per-pull group_desc.
PULLS = [
    {
        "seed": "nass_milk_production_monthly",
        "label": "Milk production, monthly by state (lb)",
        "params": {
            "group_desc": "DAIRY",
            "commodity_desc": "MILK",
            "statisticcat_desc": "PRODUCTION",
            "short_desc": "MILK - PRODUCTION, MEASURED IN LB",
            "freq_desc": "MONTHLY",
        },
    },
    {
        "seed": "nass_milk_per_cow_monthly",
        "label": "Milk per cow, monthly by state (lb/head)",
        "params": {
            "group_desc": "DAIRY",
            "commodity_desc": "MILK",
            "statisticcat_desc": "PRODUCTION",
            "short_desc": "MILK - PRODUCTION, MEASURED IN LB / HEAD",
            "freq_desc": "MONTHLY",
        },
    },
    {
        # The Milk Production report's monthly cow numbers land in Quick Stats
        # as INVENTORY, AVG ("average number of head during month") — the plain
        # INVENTORY statisticcat is the semi-annual Jan 1 / Jul 1 point-in-time
        # cattle survey, which is NOT this series.
        "seed": "nass_milk_cow_inventory_monthly",
        "label": "Milk cow inventory (monthly avg head, by state)",
        "params": {
            "group_desc": "LIVESTOCK",
            "commodity_desc": "CATTLE",
            "class_desc": "COWS, MILK",
            "statisticcat_desc": "INVENTORY, AVG",
            "short_desc": "CATTLE, COWS, MILK - INVENTORY, AVG, MEASURED IN HEAD",
            "freq_desc": "MONTHLY",
        },
    },
    {
        # Licensed dairy herds live under LIVESTOCK/CATTLE with a dedicated
        # class, not under DAIRY/MILK as NASS_DOWNLOAD.md guessed — found via
        # a sector-wide short_desc search for 'LICENSED'. Annual, state +
        # national, 2003–present.
        "seed": "nass_licensed_herds_annual",
        "label": "Licensed dairy herds, annual by state (operations)",
        "params": {
            "group_desc": "LIVESTOCK",
            "commodity_desc": "CATTLE",
            "class_desc": "COWS, MILK, LICENSED HERD",
            "statisticcat_desc": "INVENTORY, AVG",
            "short_desc": "CATTLE, COWS, MILK, LICENSED HERD - OPERATIONS WITH INVENTORY, AVG",
            "freq_desc": "ANNUAL",
        },
    },
]


def api_get(endpoint: str, key: str, params: dict) -> requests.Response:
    resp = requests.get(
        f"{API_BASE}/{endpoint}/",
        params={"key": key, **params},
        timeout=120,
    )
    return resp


def get_count(key: str, params: dict) -> int | None:
    resp = api_get("get_counts", key, params)
    if resp.status_code != 200:
        return None
    return int(resp.json().get("count", 0))


def discover_short_desc(key: str, params: dict) -> str | None:
    """short_desc drifted — ask the API which strings currently exist for
    this commodity/category and take the closest match to what we asked for."""
    wanted = params["short_desc"]
    filters = {
        k: v
        for k, v in {**COMMON_PARAMS, **params}.items()
        if k in ("commodity_desc", "class_desc", "statisticcat_desc", "sector_desc", "group_desc")
    }
    resp = api_get("get_param_values", key, {"param": "short_desc", **filters})
    resp.raise_for_status()
    candidates = resp.json().get("short_desc", [])
    if not candidates:
        return None
    match = difflib.get_close_matches(wanted, candidates, n=1, cutoff=0.4)
    print(f"    short_desc '{wanted}' not found; API offers {len(candidates)} strings")
    for c in candidates[:10]:
        print(f"      - {c}")
    return match[0] if match else None


def fetch_pull(key: str, pull: dict) -> list[dict]:
    rows: list[dict] = []
    for agg_level in AGG_LEVELS:
        params = {
            **COMMON_PARAMS,
            **pull["params"],
            "agg_level_desc": agg_level,
            "format": "CSV",
        }

        count = get_count(key, {k: v for k, v in params.items() if k != "format"})
        if count == 0:
            replacement = discover_short_desc(key, pull["params"])
            if replacement is None:
                raise RuntimeError(f"{pull['seed']}: no rows and no short_desc candidates")
            print(f"    retrying with short_desc = '{replacement}'")
            params["short_desc"] = replacement
            pull["params"]["short_desc"] = replacement
        elif count is not None and count > 50_000:
            raise RuntimeError(f"{pull['seed']}: {count} rows exceeds the 50k API cap — split by year")

        resp = api_get("api_GET", key, params)
        if resp.status_code == 400:
            raise RuntimeError(f"{pull['seed']} ({agg_level}): HTTP 400 — {resp.text[:200]}")
        resp.raise_for_status()

        rows.extend(csv.DictReader(io.StringIO(resp.text)))

    if not rows:
        raise RuntimeError(f"{pull['seed']}: pull returned no rows")
    return rows


def resolve(row: dict, column: str) -> str:
    for alias in SOURCE_COLUMN_ALIASES.get(column, (column,)):
        if alias in row:
            return row[alias]
    return ""


def write_seed(seed_name: str, rows: list[dict]) -> Path:
    SEED_DIR.mkdir(parents=True, exist_ok=True)
    path = SEED_DIR / f"{seed_name}.csv"
    trimmed = [{col: resolve(r, col) for col in SEED_COLUMNS} for r in rows]
    trimmed.sort(key=lambda r: (r["year"], r["state_alpha"], r["reference_period_desc"]))
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=SEED_COLUMNS)
        writer.writeheader()
        writer.writerows(trimmed)
    return path


def summarize(seed_name: str, label: str, rows: list[dict]) -> None:
    years = sorted({r["year"] for r in rows})
    states = sorted({resolve(r, "state_alpha") for r in rows})
    periods = sorted({r["reference_period_desc"] for r in rows})
    short_descs = sorted({r["short_desc"] for r in rows})
    print(f"\n  {label}")
    print(f"    seed:       seeds/nass/{seed_name}.csv")
    print(f"    rows:       {len(rows)}")
    print(f"    years:      {years[0]}–{years[-1]} ({len(years)} years)")
    print(f"    states:     {len(states)} → {', '.join(states)}")
    print(f"    periods:    {', '.join(periods)}")
    print(f"    short_desc: {'; '.join(short_descs)}")


def main() -> None:
    load_dotenv(REPO_ROOT / ".env")
    key = os.environ.get("NASS_API_KEY")
    if not key:
        sys.exit("NASS_API_KEY missing — copy .env.example to .env and fill it in.")

    print("Fetching HerdPulse source data from USDA NASS Quick Stats")
    for pull in PULLS:
        rows = fetch_pull(key, pull)
        write_seed(pull["seed"], rows)
        summarize(pull["seed"], pull["label"], rows)

    print("\nDone. Seeds written under seeds/nass/ — column schema:")
    print(f"  {', '.join(SEED_COLUMNS)}")


if __name__ == "__main__":
    main()
