import { useMemo } from 'react'
import {
  ComposedChart, Area, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer,
} from 'recharts'
import { fmtNum } from '../lib/format'

// The structural consolidation story: licensed dairy herds falling while
// cows-per-herd rises. National series from the flagged US-total rows.
export default function HerdConsolidationChart({ consolidation }) {
  const rows = useMemo(
    () =>
      consolidation
        .filter((r) => r.is_us_total && r.licensed_herds != null)
        .sort((a, b) => a.year - b.year),
    [consolidation],
  )

  return (
    <section className="panel">
      <h2>U.S. herd consolidation</h2>
      <p className="panel-sub">
        Licensed dairy herds (area, left) vs average cows per herd (line, right) — fewer,
        larger operations every year.
      </p>
      <ResponsiveContainer width="100%" height={320}>
        <ComposedChart data={rows} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
          <XAxis dataKey="year" tick={{ fontSize: 12 }} />
          <YAxis
            yAxisId="herds"
            tickFormatter={fmtNum}
            tick={{ fontSize: 12 }}
            width={64}
            label={{ value: 'licensed herds', angle: -90, position: 'insideLeft', fontSize: 12, fill: '#6b7280' }}
          />
          <YAxis
            yAxisId="cph"
            orientation="right"
            tickFormatter={fmtNum}
            tick={{ fontSize: 12 }}
            width={56}
            label={{ value: 'cows per herd', angle: 90, position: 'insideRight', fontSize: 12, fill: '#6b7280' }}
          />
          <Tooltip formatter={(v) => fmtNum(v)} />
          <Legend />
          <Area
            yAxisId="herds"
            dataKey="licensed_herds"
            name="licensed herds"
            fill="#2f7d4f"
            fillOpacity={0.18}
            stroke="#2f7d4f"
            strokeWidth={2}
            isAnimationActive={false}
          />
          <Line
            yAxisId="cph"
            dataKey="cows_per_herd"
            name="cows per herd"
            stroke="#d97706"
            strokeWidth={2}
            dot={{ r: 3 }}
            isAnimationActive={false}
          />
        </ComposedChart>
      </ResponsiveContainer>
    </section>
  )
}
