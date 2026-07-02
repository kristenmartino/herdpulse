import { fmtLb, fmtNum, fmtPct, fmtMonth } from '../lib/format'

// National KPI strip: trailing-12-month production and per-cow yield, the
// licensed-herd count, and the latest monthly YoY — all from the flagged
// US-total rows so nothing is recomputed client-side.
export default function KpiStrip({ trends, consolidation }) {
  const usTrend = trends
    .filter((r) => r.is_us_total && r.rolling_12m_production_lb != null)
    .sort((a, b) => a.month_date.localeCompare(b.month_date))
  const latest = usTrend[usTrend.length - 1]

  const usHerds = consolidation
    .filter((r) => r.is_us_total && r.licensed_herds != null)
    .sort((a, b) => a.year - b.year)
  const latestHerds = usHerds[usHerds.length - 1]

  if (!latest || !latestHerds) return null

  const kpis = [
    {
      label: 'U.S. production, trailing 12 mo',
      value: fmtLb(latest.rolling_12m_production_lb),
      note: `through ${fmtMonth(latest.month_date)}`,
    },
    {
      label: 'Milk per cow, trailing 12 mo',
      value: `${fmtNum(latest.rolling_12m_milk_per_cow_lb)} lb`,
      note: 'the rolling-herd-average analog',
    },
    {
      label: 'Licensed dairy herds',
      value: fmtNum(latestHerds.licensed_herds),
      note: `${latestHerds.year} · ${fmtPct(latestHerds.licensed_herds_yoy_pct)} YoY`,
    },
    {
      label: 'Production YoY',
      value: fmtPct(latest.production_yoy_pct),
      note: `${fmtMonth(latest.month_date)} vs prior year`,
    },
  ]

  return (
    <section className="kpi-strip">
      {kpis.map((kpi) => (
        <div className="kpi" key={kpi.label}>
          <span className="kpi-label">{kpi.label}</span>
          <span className="kpi-value">{kpi.value}</span>
          <span className="kpi-note">{kpi.note}</span>
        </div>
      ))}
    </section>
  )
}
