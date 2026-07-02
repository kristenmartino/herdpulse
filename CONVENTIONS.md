# CONVENTIONS.md — how HerdPulse mirrors my existing work

Extracted from [`medicare-provider-outliers`](https://github.com/kristenmartino/medicare-provider-outliers) (read in full before any HerdPulse code was written). This file is the contract for the build: HerdPulse should rhyme with the Medicare project in **conventions and methodology**, while the model *logic* differs honestly — trend/consolidation analytics over clean public aggregates, not outlier detection over messy claims files.

---

## 1. dbt project structure

```
models/
├── staging/        _staging.yml        + stg_*.sql        (views)
├── intermediate/   _intermediate.yml   + int_*.sql        (tables)
└── marts/          _marts.yml          + dim_/fct_/mart_* (tables)
seeds/              _seeds.yml + *.csv
tests/              assert_*.sql        (singular business-rule tests)
macros/             _macros.yml + one file per macro concern
analyses/           _analyses.yml + ad-hoc exploratory SQL (not materialized)
```

- One schema YAML **per layer** (`_staging.yml`, `_intermediate.yml`, `_marts.yml`), listing every model, its description, columns, and tests. No per-model YAML files, no doc blocks.
- Medicare: 3 staging + 4 intermediate + 4 marts = **11 models**, 1 seed, 4 analyses. HerdPulse targets the same order of magnitude (11 models: 4 staging + 4 intermediate + 3 marts).
- Materializations set in `dbt_project.yml` per layer, never per model unless deviating:

```yaml
models:
  herdpulse:
    staging:      { +materialized: view,  +schema: staging }
    intermediate: { +materialized: table, +schema: intermediate }
    marts:        { +materialized: table, +schema: marts }
seeds:
  herdpulse:      { +schema: raw }
```

- A custom `generate_schema_name` macro uses the `+schema:` values **verbatim** (no `target_schema_` prefixing), so the warehouse reads cleanly: `staging`, `intermediate`, `marts`.

## 2. Naming

| Layer | Pattern | Medicare example | HerdPulse example |
|---|---|---|---|
| Staging | `stg_<source>__<grain>` | `stg_part_d__prescriber_drug` | `stg_nass__milk_production_monthly` |
| Intermediate | `int_<entity>__<rollup>` | `int_provider__peer_group_stats` | `int_productivity__national_benchmark` |
| Marts | `dim_<entity>` / `fct_<event>__<grain>` / `mart_<domain>` | `mart_provider_outliers` | `mart_herd_consolidation` |
| Seeds | `<source>_<content>.csv` | `nucc_taxonomy.csv` | `nass_milk_production_monthly.csv` |
| Singular tests | `assert_<business_rule>.sql` | `assert_mart_outlier_rate_within_reason.sql` | `assert_national_total_reconciles.sql` |

- Columns: `snake_case`, domain-meaningful names (`brand_cost_share`, never `pct`). Units in the name where ambiguity is possible (`milk_production_lb`, `milk_per_cow_lb`).
- Booleans: `is_*` or `*_flag` (`is_outlier_any_mad`, `part_d_prescriber_flag`).
- Peer/benchmark statistics carry `mean_` / `median_` / `stddev_` / `mad_` prefixes and `n_*` coverage counts.

## 3. SQL style

- `{{ config(materialized = '...') }}` first line (spaces around `=`), then a `/* ... */` block comment explaining what the model is, its grain, and any semantics a consumer must know (suppression handling, exclusions, methodology pointers).
- **Import CTEs first** (pure `select * from {{ ref(...) }}` / `{{ source(...) }}`), then logical CTEs with intention-revealing names (`renamed`, `parsed`, `joined`, `scored`, `flagged`), then a bare final `select`.
- Lowercase SQL keywords. Aligned `as` aliases in wide selects. Section comments inside selects (`-- Identifiers`, `-- Volume / cost`, `-- Provenance`).
- `try_cast` for anything arriving as text; suppressed/sentinel values become NULL in **staging**, never silently zero.
- Jinja constants at the top of the model that uses them: `{% set z_threshold = 2.0 %}`.
- Statistical helpers are macros, not copy-paste: `zscore(value, mean, stddev)`, `modified_zscore(value, median, mad, mad_constant=0.6745)`, `is_outlier(score, threshold)` — all null-safe (zero stddev/MAD → NULL, never a divide-by-zero).

## 4. Testing

Medicare ships **59 tests across 11 models** (53 schema + 3 singular + 3 unit) — roughly 3–5 per model, concentrated where they earn their keep:

- **Grain integrity**: `not_null` + `unique` (or `dbt_utils.unique_combination_of_columns` for composite grains) on every model's key.
- **Domain constraints**: `accepted_values` on categoricals (with `where` configs when nullable), `dbt_utils.accepted_range` on bounded metrics.
- **Referential integrity**: `relationships` from downstream layers back upstream.
- **Singular tests** (`tests/assert_*.sql`): business rules that return offending rows — e.g. a share must live in [0,1], an outlier rate must stay under a ceiling. *Reconciliation is a test, not a hope.*
- **Unit tests** (dbt `unit_tests:` in the marts YAML): mocked inputs proving the scored mart's arithmetic — the flag fires above threshold, is suppressed when MAD is zero, is suppressed below the coverage floor.
- Metrics that can be legitimately NULL (source suppression) do **not** get `not_null`; only grain keys do.

HerdPulse matches this density: not_null + unique on every (state × period) grain, accepted_values/range checks, relationships marts → intermediate → staging, 3 singular tests (per-cow yield sanity band; national-total-reconciles-to-sum-of-states within tolerance; cows-per-herd positivity), and 3 unit tests on `mart_productivity_ranking` (z-score arithmetic, rank ordering, threshold flip).

## 5. Documentation

- Verbose, multi-line `description:` blocks on every model and every load-bearing column. Voice: technical, precise, assumption-explicit; cites methodology (thresholds, references) and points to longer-form docs where they exist.
- Column descriptions say what the value *means* and when it is NULL, not just restate the name.
- `dbt docs generate` → static site committed to `docs/index.html`, served on GitHub Pages, linked from the README.

## 6. Repo hygiene

- `packages.yml`: `dbt-labs/dbt_utils` only.
- `profiles.yml.example` committed; the real `profiles.yml` gitignored — even when the engine (DuckDB) holds no credentials, the convention holds.
- `.gitignore`: `target/`, `dbt_packages/`, `logs/`, `.user.yml`, `profiles.yml`, `.venv/`, `data/`, `*.csv` with explicit `!seeds/**/*.csv` allow-back, `.env` / `.env.*` with `!.env.example`. Secrets never enter git.
- `Makefile` with self-documenting `##` help: `install`, `debug`, `build`, `test`, `docs`, `serve`, `publish-docs`, `ci-local`, `clean` (HerdPulse adds `fetch`, `export`, `dashboard-dev`).
- GitHub Actions CI validating the project without warehouse credentials. Medicare could only `dbt parse` (its CMS data can't ship); **HerdPulse's seeds are committed, so CI runs a full offline `dbt build` + `dbt test`** — an intentional strengthening of the same principle.
- README shape: one-line summary → live docs/app links → headline finding → stack table → mermaid DAG → repo layout → reproduce steps → methodology → limitations (plainly stated). No fabricated numbers anywhere; placeholders until the build produces real ones.

## 7. Methodology carryover: peer benchmarking

Medicare's core statistical move: score an entity against a **peer distribution** with both classical z-score and MAD-based modified z-score (0.6745 · (x − median) / MAD, Iglewicz & Hoaglin threshold 3.5), null-safe and coverage-gated.

HerdPulse reuses this spine in `mart_productivity_ranking`: each state's annual milk-per-cow is scored against the **national distribution of states** for that year (mean/median/stddev/MAD computed over real states only — US-total and OTHER STATES rows excluded). Same macros, same null-safety, new domain. The "peer group" is simply *all states in a year* — dairy productivity benchmarking has one national peer set rather than 9,490 taxonomy × state cells, so no coverage floor is needed (n = 24 published states, stated in the model description rather than gated).

---

## Adaptations for HerdPulse (flagged, not silent)

1. **Seeds instead of `source()` for the raw layer.** Medicare lands raw CMS files in a warehouse schema and stages via `{{ source('cms', ...) }}`. HerdPulse's raw layer *is* the committed NASS seed CSVs (per the build spec), so staging imports via `{{ ref('nass_...') }}` and the provenance documentation that would live in `_sources.yml` lives in `seeds/_seeds.yml` instead. Trade: we lose a `_sources.yml`, we gain a fully offline-reproducible repo where `git clone` + `dbt build` works with no API key.
2. **Trend metrics, not outlier flags, in two of three marts.** `mart_state_production_trends` and `mart_herd_consolidation` are YoY / rolling-window / index builds — the honest analytics for clean public aggregates. The z-score/MAD methodology carries over only where it genuinely fits (`mart_productivity_ranking`).
3. **DuckDB instead of Snowflake.** Local file warehouse (`data/herdpulse.duckdb`, gitignored) — right-sized for an evening build. Conventions that exist for credential hygiene (`profiles.yml` gitignored, `.example` committed) are kept anyway so the repo shape matches.
4. **CI upgraded from parse-only to full build** (see §6) — possible only because the data ships with the repo; flagged in the README as intentional.
5. **Rolling Herd Average nod**: `rolling_12m_avg_per_cow_lb` in the trends mart is the public-aggregate analog of RHA — the trailing benchmark a dairy manager watches — and the model description says so.
