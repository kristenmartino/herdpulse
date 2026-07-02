// Shared number formatting for chart axes, tooltips, and KPIs.

export function fmtLb(value) {
  if (value == null) return '—'
  const abs = Math.abs(value)
  if (abs >= 1e12) return `${(value / 1e12).toFixed(1)}T lb`
  if (abs >= 1e9) return `${(value / 1e9).toFixed(1)}B lb`
  if (abs >= 1e6) return `${(value / 1e6).toFixed(1)}M lb`
  return `${Math.round(value).toLocaleString()} lb`
}

export function fmtNum(value) {
  if (value == null) return '—'
  return Math.round(value).toLocaleString()
}

export function fmtPct(value, digits = 1) {
  if (value == null) return '—'
  const pct = value * 100
  return `${pct > 0 ? '+' : ''}${pct.toFixed(digits)}%`
}

export function fmtMonth(isoDate) {
  if (!isoDate) return '—'
  const [y, m] = isoDate.split('-')
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return `${names[Number(m) - 1]} ${y}`
}
