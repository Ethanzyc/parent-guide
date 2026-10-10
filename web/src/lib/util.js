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

// Whole days since a MM-DD (treated as this year) or YYYY-MM-DD date.
// Negative (cross-year artifacts) clamps to null -> caller hides the badge.
export function daysSince(d) {
  if (!d) return null
  const now = new Date()
  let b = null
  const full = String(d).match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)
  const short = String(d).match(/^(\d{1,2})-(\d{1,2})$/)
  if (full) b = new Date(+full[1], +full[2] - 1, +full[3])
  else if (short) b = new Date(now.getFullYear(), +short[1] - 1, +short[2])
  if (!b || isNaN(b)) return null
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const diff = Math.round((today - b) / 86400000)
  return diff >= 0 ? diff : null
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

// 完整日期显示(YYYY-MM-DD,用户拍板 2026-10-09 全局统一):MM-DD 补当年,
// ISO 原样;其他原样返回。与 IssueDetail/卡片/分享卡共用。逐段补零
// ("6-7"→"06-07",整串 padStart 会补出 "006-7")。
export function fullDate(d) {
  const s2 = String(d || '')
  let m = s2.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/)
  if (m) return `${m[1]}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}`
  m = s2.match(/^(\d{1,2})-(\d{1,2})$/)
  if (m) return `${new Date().getFullYear()}-${m[1].padStart(2, '0')}-${m[2].padStart(2, '0')}`
  return s2
}

// 排序键:due 字段现在 MM-DD(近程)与 YYYY-MM-DD(跨年节点,如 2027 入园)混存,
// 字符串 localeCompare 会排错;统一归一成可比较的完整日期串。
export function dueKey(d) {
  return fullDate(d)
}

// 中文语境标点归一(读侧机械转换,档案原文不动——中文文案排版指北口径):
// 中文句子用全角 ；，（）;嵌入的数字语境保持半角(14:30 / 1,000 / https://)。
export function zhPunct(s) {
  return String(s || '')
    .replace(/;/g, '；')
    .replace(/,/g, (m, off, str) =>
      /\d/.test(str[off - 1] || '') && /\d/.test(str[off + 1] || '') ? ',' : '，')
    .replace(/:/g, (m, off, str) => {
      if (str.substr(off + 1, 2) === '//') return ':'          // URL 协议符
      return /\d/.test(str[off - 1] || '') && /\d/.test(str[off + 1] || '') ? ':' : '：'
    })
    .replace(/\(/g, '（').replace(/\)/g, '）')
}

// 详情正文分段:标点归一后按中文分号切段(NN Group 分段/列点证据);
// 段首「标签：」(<=8 字)由渲染层加粗——纯机械,不做语义判断。
export function bodyParas(text) {
  return zhPunct(text).split('；').map(t => t.trim()).filter(Boolean)
}
export function segLabel(seg) {
  const m = zhPunct(seg).match(/^([^：]{1,8})：/)
  return m ? m[1] + '：' : ''
}
