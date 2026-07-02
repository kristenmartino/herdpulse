import { useMemo } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine, Cell,
  ResponsiveContainer,
} from 'recharts'
import { fmtNum } from '../lib/format'

// Per-cow productivity ranking for the latest complete year, with the
// national mean as distribution context. Statistical outliers (|z| >= 2 vs
// the national distribution — the methodology carried over from my Medicare
// project) get the accent fill.
export default function ProductivityRankingChart({ ranking }) {
  const { year, rows, mean } = useMemo(() => {
    const latestYear = Math.max(...ranking.map((r) => r.year))
    const rows = ranking
      .filter((r) => r.year === latestYear)
      .sort((a, b) => a.productivity_rank - b.productivity_rank)
    return { year: latestYear, rows, mean: rows[0]?.mean_milk_per_cow_lb }
  }, [ranking])

  return (
    <section className="panel">
      <h2>Milk per cow by state, {year}</h2>
      <p className="panel-sub">
        Annual lb/head vs the national distribution — dashed line is the national mean;
        highlighted bars are statistical outliers (|z| ≥ 2).
      </p>
      <ResponsiveContainer width="100%" height={340}>
        <BarChart data={rows} margin={{ top: 8, right: 16, bottom: 0, left: 8 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
          <XAxis dataKey="state_alpha" tick={{ fontSize: 11 }} interval={0} />
          <YAxis
            tickFormatter={fmtNum}
            tick={{ fontSize: 12 }}
            width={60}
            domain={[(min) => Math.floor((min * 0.95) / 1000) * 1000, 'auto']}
          />
          <Tooltip
            formatter={(v, name, { payload }) => [
              `${fmtNum(v)} lb (z = ${payload.per_cow_zscore.toFixed(2)}, rank ${payload.productivity_rank})`,
              'milk per cow',
            ]}
          />
          <ReferenceLine
            y={mean}
            stroke="#6b7280"
            strokeDasharray="6 4"
            label={{ value: `national mean ${fmtNum(mean)}`, position: 'insideTopRight', fontSize: 12, fill: '#6b7280' }}
          />
          <Bar dataKey="annual_milk_per_cow_lb" radius={[3, 3, 0, 0]} isAnimationActive={false}>
            {rows.map((r) => (
              <Cell key={r.state_alpha} fill={r.is_productivity_outlier ? '#d97706' : '#2f7d4f'} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </section>
  )
}
