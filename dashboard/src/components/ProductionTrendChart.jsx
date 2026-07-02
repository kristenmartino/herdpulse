import { useMemo, useState } from 'react'
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer,
} from 'recharts'
import { fmtLb, fmtMonth } from '../lib/format'

const PALETTE = ['#2f7d4f', '#4a90d9', '#d97706', '#8b5cf6', '#dc2626', '#0d9488', '#a16207', '#be185d']
const DEFAULT_STATES = ['CA', 'WI', 'ID', 'TX']

// Monthly milk production by state — selectable series over the 24 states
// NASS publishes monthly.
export default function ProductionTrendChart({ trends }) {
  const states = useMemo(
    () => [...new Set(trends.filter((r) => !r.is_us_total).map((r) => r.state_alpha))].sort(),
    [trends],
  )
  const [selected, setSelected] = useState(DEFAULT_STATES)

  const series = useMemo(() => {
    const byMonth = new Map()
    for (const row of trends) {
      if (row.is_us_total || !selected.includes(row.state_alpha)) continue
      if (!byMonth.has(row.month_date)) byMonth.set(row.month_date, { month_date: row.month_date })
      byMonth.get(row.month_date)[row.state_alpha] = row.milk_production_lb
    }
    return [...byMonth.values()].sort((a, b) => a.month_date.localeCompare(b.month_date))
  }, [trends, selected])

  function toggle(state) {
    setSelected((prev) =>
      prev.includes(state) ? prev.filter((s) => s !== state) : [...prev, state],
    )
  }

  return (
    <section className="panel">
      <h2>Milk production by state, monthly</h2>
      <p className="panel-sub">Pounds per month for the 24 major milk-producing states. Toggle states to compare.</p>
      <div className="state-picker">
        {states.map((s) => (
          <button
            key={s}
            type="button"
            className={selected.includes(s) ? 'chip chip-on' : 'chip'}
            onClick={() => toggle(s)}
          >
            {s}
          </button>
        ))}
      </div>
      <ResponsiveContainer width="100%" height={320}>
        <LineChart data={series} margin={{ top: 8, right: 16, bottom: 0, left: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="month_date" tickFormatter={fmtMonth} minTickGap={48} tick={{ fontSize: 12 }} />
          <YAxis tickFormatter={fmtLb} tick={{ fontSize: 12 }} width={70} />
          <Tooltip formatter={(v) => fmtLb(v)} labelFormatter={fmtMonth} />
          <Legend />
          {selected.map((s, i) => (
            <Line
              key={s}
              type="monotone"
              dataKey={s}
              stroke={PALETTE[i % PALETTE.length]}
              dot={false}
              strokeWidth={2}
              isAnimationActive={false}
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
    </section>
  )
}
