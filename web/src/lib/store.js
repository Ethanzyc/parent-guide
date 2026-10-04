// App state: dual-mode load waterfall + persistence.
//   server mode: GET/POST /api/page + /api/data (local server.py)
//   file mode:   localStorage memory + embedded defaults from index.html
import { reactive } from 'vue'
import { CARD_META } from '../components/cards/index.js'

export const state = reactive({
  page: null, data: null,
  serverMode: false, editing: false, ready: false,
  version: 0, // bump to force GridBoard full rebuild (JSON apply / reset)
})

async function tryFetch(url) {
  try {
    const r = await fetch(url)
    if (!r.ok) throw new Error(r.status)
    return await r.json()
  } catch { return null }
}

function readEmbedded(id) {
  const el = document.getElementById(id)
  try { return JSON.parse(el ? el.textContent : 'null') } catch { return null }
}

function stripBootstrapped(obj) {
  if (obj && typeof obj === 'object') delete obj.bootstrapped
  return obj
}

export async function init() {
  const apiPage = await tryFetch('/api/page')   // file:// fails here -> file mode
  if (apiPage && Array.isArray(apiPage.blocks)) {
    const apiData = await tryFetch('/api/data')
    if (apiData) {
      state.serverMode = true
      state.page = stripBootstrapped(apiPage)
      state.data = stripBootstrapped(apiData)
    }
  }
  if (!state.serverMode) {
    let stored = null
    try { stored = JSON.parse(localStorage.getItem('pg-page') || 'null') } catch {}
    state.page = (stored && Array.isArray(stored.blocks) && stored) ||
                 readEmbedded('pg-embedded-page')
    state.data = readEmbedded('pg-embedded-data')
  }
  document.title = state.page?.title || '成长视图'
  state.ready = true
}

export function currentChild() {
  const d = state.data || {}
  const key = state.page?.child && d[state.page.child] ? state.page.child
    : Object.keys(d).find(k => !k.startsWith('_'))
  return (key && d[key]) || {}
}

export function persistPage() {
  if (state.serverMode) {
    fetch('/api/page', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(state.page) }).catch(() => {})
    return
  }
  try { localStorage.setItem('pg-page', JSON.stringify(state.page)) } catch {}
}

// GridStack geometry -> page.blocks (called debounced from GridBoard)
export function applyGeometry(blocks) {
  if (!state.page) return
  state.page.blocks = blocks
  persistPage()
}

export function applyJsonPage(next) {
  state.page = next
  persistPage()
  state.version++   // full board rebuild
}

export function resetDefault() {
  const defaults = readEmbedded('pg-embedded-page')
  // Reset restores the builtin default set, but custom cards carry user
  // content (checklists etc.) -- keep them, stacked after the defaults.
  const customs = (state.page?.blocks || []).filter(b => CARD_META[b.type]?.group === 'custom')
  if (defaults && customs.length) {
    const maxY = Math.max(0, ...defaults.blocks.map(b => (b.y || 0) + (b.h || 4)))
    let y = maxY
    defaults.blocks = [...defaults.blocks, ...customs.map(b => ({ ...b, x: 0, y: (y += b.h || 4) - (b.h || 4) }))]
  }
  state.page = defaults
  state.data = readEmbedded('pg-embedded-data')
  try { localStorage.removeItem('pg-page') } catch {}
  if (state.serverMode) persistPage()
  if (state.editing) state.editing = false
  state.version++
}
