import { useEffect, useState } from 'react'
import KpiStrip from './components/KpiStrip'
import ProductionTrendChart from './components/ProductionTrendChart'
import ProductivityRankingChart from './components/ProductivityRankingChart'
import HerdConsolidationChart from './components/HerdConsolidationChart'
import './App.css'

// Static-export dashboard over the three HerdPulse marts. The JSON under
// public/data/ is committed output of scripts/export_marts.py — no backend,
// no warehouse at runtime.
const MARTS = [
  'mart_state_production_trends',
  'mart_productivity_ranking',
  'mart_herd_consolidation',
]

function App() {
  const [data, setData] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all(
      MARTS.map((m) =>
        fetch(`${import.meta.env.BASE_URL}data/${m}.json`).then((r) => {
          if (!r.ok) throw new Error(`${m}: HTTP ${r.status}`)
          return r.json()
        }),
      ),
    )
      .then(([trends, ranking, consolidation]) => setData({ trends, ranking, consolidation }))
      .catch((e) => setError(e.message))
  }, [])

  if (error) return <main className="shell"><p className="status">Failed to load mart data: {error}</p></main>
  if (!data) return <main className="shell"><p className="status">Loading marts…</p></main>

  return (
    <main className="shell">
      <header className="masthead">
        <h1>HerdPulse 🐄</h1>
        <p>
          U.S. dairy production, per-cow productivity, and herd consolidation — USDA NASS
          Quick Stats, modeled with dbt on DuckDB. Part of the Pulse family.
        </p>
      </header>

      <KpiStrip trends={data.trends} consolidation={data.consolidation} />
      <ProductionTrendChart trends={data.trends} />
      <div className="panel-row">
        <ProductivityRankingChart ranking={data.ranking} />
        <HerdConsolidationChart consolidation={data.consolidation} />
      </div>

      <footer className="footnote">
        Source: USDA NASS Quick Stats (SURVEY). Monthly series cover the 24 major
        milk-producing states + US total; licensed herd counts are annual. All figures trace
        to the committed seed pull — see the repo README for methodology.
      </footer>
    </main>
  )
}

export default App
