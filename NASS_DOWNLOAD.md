# NASS_DOWNLOAD.md — Getting the HerdPulse source data

> **As-built note:** two of the `short_desc` strings below drifted from what
> Quick Stats serves today (milk-cow inventory and licensed herds live under
> LIVESTOCK/CATTLE, not DAIRY/MILK). The discovery process described in the
> note below worked exactly as intended — see [`data/README.md`](./data/README.md)
> for the exact as-run queries behind the committed seeds.

USDA NASS **Quick Stats** is the source. It's public and free. Two ways in; the API is cleaner for a reproducible pull.

---

## Option A — Quick Stats API (recommended, reproducible)

1. **Get a free API key:** request one at `https://quickstats.nass.usda.gov/api` (instant, emailed). Put it in a local `.env` as `NASS_API_KEY=...` and gitignore it — do not commit it.

2. **Endpoint:** `https://quickstats.nass.usda.gov/api/api_GET/?key=YOUR_KEY&...params...&format=CSV`

3. **The four pulls** (all `sector_desc=ANIMALS & PRODUCTS`, `group_desc=DAIRY`, `agg_level_desc=STATE`, `source_desc=SURVEY`):

   **Pull 1 — Milk production, monthly by state**
   ```
   commodity_desc=MILK
   statisticcat_desc=PRODUCTION
   short_desc=MILK - PRODUCTION, MEASURED IN LB
   freq_desc=MONTHLY
   year__GE=2015
   ```

   **Pull 2 — Milk per cow, monthly by state**
   ```
   commodity_desc=MILK
   statisticcat_desc=PRODUCTION
   short_desc=MILK - PRODUCTION, MEASURED IN LB / HEAD
   freq_desc=MONTHLY
   year__GE=2015
   ```

   **Pull 3 — Milk cow inventory, monthly by state**
   ```
   commodity_desc=CATTLE
   class_desc=COWS, MILK
   statisticcat_desc=INVENTORY
   short_desc=CATTLE, COWS, MILK - INVENTORY
   freq_desc=MONTHLY
   year__GE=2015
   ```

   **Pull 4 — Licensed dairy herds, annual by state** (the consolidation story)
   ```
   commodity_desc=MILK
   statisticcat_desc=OPERATIONS
   short_desc=MILK, DAIRY - OPERATIONS WITH AREA LICENSED, MEASURED IN OPERATIONS
   freq_desc=ANNUAL
   year__GE=2015
   ```

   > Note on `short_desc`: NASS strings are exact and occasionally change. If a pull returns 0 rows, drop `short_desc` and instead browse the values — hit the param-values endpoint, e.g.
   > `https://quickstats.nass.usda.gov/api/get_param_values/?key=YOUR_KEY&param=short_desc&commodity_desc=MILK`
   > to see the exact available strings, then match. Let Claude Code do this discovery in Phase 1 rather than guessing.

4. **Rate/size limit:** the API caps a single call at 50,000 rows. State-level monthly since 2015 is well under that per pull. If you ever exceed it, split by `year`.

---

## Option B — Manual download (no key, fine as a fallback)

1. Go to `https://quickstats.nass.usda.gov/`.
2. Set the cascading dropdowns:
   - **Program:** SURVEY
   - **Sector:** ANIMALS & PRODUCTS
   - **Group:** DAIRY
   - **Commodity:** MILK (then CATTLE for the cow-inventory pull)
   - **Category / Data Item:** pick PRODUCTION → the LB and LB/HEAD items; INVENTORY for cows; OPERATIONS for licensed herds
   - **Geographic Level:** STATE
   - **Time:** set the year range (2015–current is plenty)
3. **Get Data → Spreadsheet (CSV)** for each. Save into the project's seeds/raw folder.

Also useful as a cross-check / pre-built option: **USDA ERS "Dairy Data"** (`https://www.ers.usda.gov/data-products/dairy-data`) publishes tidy Excel/CSV with milk cows, milk per cow, and production already rolled to state and region — handy if you want a clean secondary file to reconcile against.

---

## What the data looks like (so you know it's right)

- Coverage: NASS publishes monthly production, per-cow, and cow-inventory for the **24 major milk-producing states** plus a US total; quarterly for all states. Annual **licensed dairy herd** counts by state.
- Grain after staging: **state × month** for the production trio, **state × year** for herds.
- Reality check for a business rule / test: US production per cow averaged ~24,000+ lb/year recently, and national herd count has been on a long structural decline while cows-per-herd rises — that consolidation trend is exactly what `mart_herd_consolidation` should surface.
- Units: production in lb (and lb/head for per-cow); milk priced elsewhere per hundredweight (cwt) if you ever want price context — not needed for this build.
