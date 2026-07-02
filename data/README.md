# data/ — local warehouse + source-pull provenance

This folder holds the local DuckDB file (`herdpulse.duckdb`, created by `dbt build`,
gitignored). The **committed raw layer** is the four seed CSVs under `seeds/nass/`,
produced by `scripts/fetch_nass.py` from the USDA NASS Quick Stats API. This file
documents the exact queries so the pull is reproducible.

## The four pulls

All pulls share: `source_desc=SURVEY`, `sector_desc=ANIMALS & PRODUCTS`,
`year__GE=2015`, and are fetched at **both** `agg_level_desc=STATE` and
`agg_level_desc=NATIONAL` (national rows carry `state_alpha=US` and feed the
KPI strip + the sum-of-states reconciliation test).

| Seed | Query params (beyond common) | Grain |
|---|---|---|
| `nass_milk_production_monthly` | `group_desc=DAIRY` · `commodity_desc=MILK` · `statisticcat_desc=PRODUCTION` · `short_desc=MILK - PRODUCTION, MEASURED IN LB` · `freq_desc=MONTHLY` | state × month (24 states + US); other states quarterly |
| `nass_milk_per_cow_monthly` | `group_desc=DAIRY` · `commodity_desc=MILK` · `statisticcat_desc=PRODUCTION` · `short_desc=MILK - PRODUCTION, MEASURED IN LB / HEAD` · `freq_desc=MONTHLY` | state × month (24 states + US) |
| `nass_milk_cow_inventory_monthly` | `group_desc=LIVESTOCK` · `commodity_desc=CATTLE` · `class_desc=COWS, MILK` · `statisticcat_desc=INVENTORY, AVG` · `short_desc=CATTLE, COWS, MILK - INVENTORY, AVG, MEASURED IN HEAD` · `freq_desc=MONTHLY` | state × month (24 states + US); other states quarterly |
| `nass_licensed_herds_annual` | `group_desc=LIVESTOCK` · `commodity_desc=CATTLE` · `class_desc=COWS, MILK, LICENSED HERD` · `statisticcat_desc=INVENTORY, AVG` · `short_desc=CATTLE, COWS, MILK, LICENSED HERD - OPERATIONS WITH INVENTORY, AVG` · `freq_desc=ANNUAL` | state × year (+ US) |

### Discovery notes (why two pulls differ from NASS_DOWNLOAD.md's first guess)

Verified live against `get_param_values` on 2026-07-01:

- **Milk-cow inventory** is *not* the `CATTLE, COWS, MILK - INVENTORY` series —
  that one is the semi-annual Jan 1 / Jul 1 point-in-time cattle survey. The
  Milk Production report's monthly cow numbers land in Quick Stats as
  `INVENTORY, AVG` ("average number of head during month"), under group
  LIVESTOCK.
- **Licensed dairy herds** is not under `MILK ... OPERATIONS WITH AREA LICENSED`;
  the live series is `CATTLE, COWS, MILK, LICENSED HERD - OPERATIONS WITH
  INVENTORY, AVG` (annual, state + national, 2003–present). Found via a
  sector-wide `short_desc` search for `LICENSED`.

## Seed shape

Columns (trimmed from the ~39-column Quick Stats payload; the dropped columns
are constants of the query or empty at this aggregation level):

```
year, freq_desc, reference_period_desc, state_name, state_alpha, state_fips,
short_desc, unit_desc, value
```

- `value` is **verbatim** from NASS: comma-formatted integers. No `(D)`/`(NA)`
  suppression codes appear in these published aggregates (verified across all
  four seeds), but staging still parses defensively (`parse_nass_value` →
  NULL on any non-numeric).
- Monthly series carry true month rows (`JAN`..`DEC`) for the **24 major
  milk-producing states + US**, and quarterly rows (`JAN THRU MAR`, …) for the
  remaining states. Staging keeps the monthly grain and drops quarterly rows.
- Rows are sorted (year, state_alpha, period) so re-pulls diff cleanly.

## Re-running the pull

```bash
cp .env.example .env   # add your free key from https://quickstats.nass.usda.gov/api
uv run python scripts/fetch_nass.py
```
