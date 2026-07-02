# Common dev commands. Run from project root.
.PHONY: help install fetch debug build test docs serve export dashboard-dev publish-docs ci-local clean

DBT := uv run dbt --profiles-dir .

help:  ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install:  ## Sync the uv env (dbt-duckdb, duckdb, requests) + dbt packages
	uv sync
	cp -n profiles.yml.example profiles.yml || true
	$(DBT) deps

fetch:  ## Re-pull the four NASS seeds (needs NASS_API_KEY in .env)
	uv run python scripts/fetch_nass.py

debug:  ## dbt debug — verify the DuckDB connection
	$(DBT) debug

build:  ## dbt build — seeds + models + all tests
	$(DBT) build

test:  ## Run only the tests (no rebuild)
	$(DBT) test

docs:  ## Generate dbt docs (static single file) into target/
	$(DBT) docs generate --static

serve:  ## Serve dbt docs locally on http://localhost:8080
	$(DBT) docs serve --port 8080

export:  ## Export the marts to dashboard/public/data/*.json
	uv run python scripts/export_marts.py

dashboard-dev:  ## Run the dashboard dev server
	cd dashboard && npm install && npm run dev

publish-docs:  ## Stage the static docs site into docs/ for GitHub Pages
	$(DBT) docs generate --static
	cp target/static_index.html docs/index.html

ci-local:  ## Run what CI runs: full offline build + tests from committed seeds
	$(DBT) deps
	$(DBT) build

clean:  ## Remove build artifacts (keeps source + seeds)
	rm -rf target/ dbt_packages/ logs/ data/herdpulse.duckdb
