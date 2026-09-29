// Shared pure helpers (ported from demo render.html)

export function monthsAge(birthdate) {
  const b = new Date(birthdate), n = new Date()
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
