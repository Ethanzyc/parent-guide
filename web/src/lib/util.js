// Shared pure helpers (ported from demo render.html)

export function monthsAge(birthdate, on) {
  const b = new Date(birthdate), n = on ? new Date(on) : new Date()
  if (isNaN(b)) return 0
  return Math.max(0, (n.getFullYear() - b.getFullYear()) * 12 + n.getMonth() - b.getMonth())
}

export function nearestMilestone(m) {
  const steps = [18, 24, 30, 36, 48, 60]
  return steps.find(s => s >= m) || 60
}

export function clampInt(v, lo, hi, dflt) {
  const n = parseInt(v, 10)
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : dflt
}

// MM-DD 或 YYYY-MM-DD -> { label, urgency } for due dates (cards, today-local).
// urgency: 'overdue' | 'today' | 'soon' (<=7d) | 'later'; null date -> neutral.
export function dueLabel(due) {
  if (!due) return { label: '', urgency: '' }
  const now = new Date()
  let d = null
  if (/^\d{4}-\d{2}-\d{2}$/.test(due)) d = new Date(due)
  else if (/^\d{1,2}-\d{1,2}$/.test(due)) {
    const [m, day] = due.split('-').map(Number)
    d = new Date(now.getFullYear(), m - 1, day)
  }
  if (!d || isNaN(d)) return { label: due, urgency: '' }
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const diff = Math.round((d - today) / 86400000)
  if (diff < 0) return { label: diff === -1 ? '昨天到期' : `已到期 ${-diff} 天`, urgency: 'overdue' }
  if (diff === 0) return { label: '今天到期', urgency: 'today' }
  if (diff === 1) return { label: '明天', urgency: 'soon' }
  if (diff <= 7) return { label: `${diff} 天后`, urgency: 'soon' }
  return { label: `${diff} 天后`, urgency: 'later' }
}
