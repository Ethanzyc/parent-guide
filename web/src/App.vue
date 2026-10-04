<script setup>
import { onMounted, ref } from 'vue'
import { state, init, currentChild, applyGeometry, applyJsonPage, persistPage, resetDefault } from './lib/store.js'
import GridBoard from './components/GridBoard.vue'
import JsonDrawer from './components/JsonDrawer.vue'
import ShareModal from './components/ShareModal.vue'
import AddCardPanel from './components/AddCardPanel.vue'
import { CARD_META } from './components/cards/index.js'

onMounted(init)

const drawerOpen = ref(false)
const addState = ref(null)       // null | { block: null(add) | block(edit) }
const shareState = ref(null)     // null | { level: 'page' | 'card', block }
const print = () => window.print()

function onApplyPage(next) {
  applyJsonPage(next)
  drawerOpen.value = false
}

function toggleEdit() {
  if (!state.serverMode) {
    alert('布局编辑需要本地服务:在仓库根目录运行 python3 server.py --open')
    return
  }
  state.editing = !state.editing
  document.body.classList.toggle('editing', state.editing)
}

// -- add / remove / edit cards ------------------------------------------------
function nextId(page) {
  const nums = (page?.blocks || [])
    .map(b => String(b.id || '').match(/^b(\d+)$/)).filter(Boolean).map(m => +m[1])
  return 'b' + ((nums.length ? Math.max(...nums) : 0) + 1)
}

function onAdd({ type, props }) {
  const meta = CARD_META[type]
  if (!meta) return
  const cols = state.page?.layout?.cols || 12
  const blocks = state.page?.blocks || []
  const maxY = Math.max(0, ...blocks.map(b => (b.y || 0) + (b.h || 4)))
  const block = { id: nextId(state.page), type, x: 0, y: maxY,
                  w: Math.min(meta.w || 6, cols), h: meta.h || 4 }
  if (props) block.props = props
  applyJsonPage({ ...state.page, blocks: [...blocks, block] })
  addState.value = null
}

function onRemove(b) {
  const name = CARD_META[b.type]?.name || b.type
  if (!confirm(`删除「${name}」卡片?`)) return
  applyJsonPage({ ...state.page, blocks: state.page.blocks.filter(x => x.id !== b.id) })
}

// from AddCardPanel edit form: swap props wholesale + full rebuild (the
// panel edits a copy; GridBoard's snapshot only knows the old props)
function onPanelUpdate({ id, props }) {
  const block = state.page?.blocks?.find(x => x.id === id)
  if (!block) return
  block.props = props
  applyJsonPage(state.page)
  addState.value = null
}

// from GridBoard (list checkbox): snapshot already patched in place, so only
// mirror into page.json + persist -- no rebuild (keeps the flicker out)
function onPropsUpdate({ id, props }) {
  const block = state.page?.blocks?.find(x => x.id === id)
  if (block) { block.props = props; persistPage() }
}

// Export a standalone single-file report: clone the document, swap the two
// embedded-JSON tags with current page/data, drop the live app DOM (the inline
// bundle re-mounts on open and falls back to the embedded values in file mode).
function exportReport() {
  const safe = o => JSON.stringify(o, null, 2).replace(/<\//g, '<\\/')
  const doc = document.documentElement.cloneNode(true)
  const pg = doc.querySelector('#pg-embedded-page')
  const dt = doc.querySelector('#pg-embedded-data')
  if (pg) pg.textContent = safe(state.page)
  if (dt) dt.textContent = safe(state.data)
  const app = doc.querySelector('#app')
  if (app) app.innerHTML = ''
  const body = doc.querySelector('body')
  if (body) { body.classList.remove('editing'); body.classList.add('report') }
  const blob = new Blob(['<!DOCTYPE html>\n' + doc.outerHTML], { type: 'text/html' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `成长视图-${currentChild().name || 'report'}.html`
  a.click()
  URL.revokeObjectURL(a.href)
}
</script>

<template>
  <template v-if="state.ready">
    <div class="toolbar">
      <span class="brand">🧸 成长视图<small>parent-guide</small></span>
      <span class="mode-badge" :class="{ on: state.serverMode }" :title="state.serverMode
        ? '已连接本地后端(server.py):拖拽/拉伸/编辑直接写回 data/page.json'
        : '未检测到本地服务;想体验布局编辑,运行 python3 server.py --open'">
        {{ state.serverMode ? '🔌 本地服务 · 编辑即保存' : '📄 文件模式 · 只读' }}
      </span>
      <button class="btn" @click="addState = { block: null }">＋ 添加卡片</button>
      <button class="btn" :class="{ active: state.editing }" :disabled="!state.serverMode"
              @click="toggleEdit">{{ state.editing ? '完成编辑' : '编辑布局' }}</button>
      <button class="btn" @click="drawerOpen = true">编辑配置</button>
      <button class="btn" title="恢复默认功能卡;自定义卡会保留在页面末尾" @click="resetDefault()">重置默认</button>
      <button class="btn" @click="shareState = { level: 'page', block: null }">分享长图</button>
      <button class="btn" @click="exportReport">导出单文件报告</button>
      <button class="btn primary" @click="print">导出 PDF</button>
    </div>

    <div class="banner">
      <b>本地服务模式</b>(python3 server.py --open):「编辑布局」后整卡拖拽自由定位、右下角拉角拉伸宽高,松手自动紧凑,改动 300ms 防抖写回 data/page.json;
      <b>文件模式</b>(双击打开):流式只读。<b>＋ 添加卡片</b>=功能卡(读档案)与自定义卡(自己写内容);编辑布局时可删除/编辑卡内容;
      <b>分享长图</b>=发家人微信(卡片右上角 ⤴ 可单卡);<b>导出单文件报告</b>=迁移/存档。
    </div>

    <GridBoard :key="state.version" :page="state.page" :kid="currentChild()"
               :editing="state.editing" :server-mode="state.serverMode"
               @geometry="applyGeometry" @share-card="b => shareState = { level: 'card', block: b }"
               @remove="onRemove" @edit-props="b => addState = { block: b }"
               @props-update="onPropsUpdate" />

    <footer class="page">示例数据为虚构 · 布局模型:{x, y, w, h} 网格坐标(与 grid-layout-plus 同构)</footer>

    <JsonDrawer :open="drawerOpen" :page="state.page"
                @close="drawerOpen = false" @apply="onApplyPage" />

    <AddCardPanel :open="!!addState" :block="addState?.block || null"
                  @close="addState = null" @add="onAdd" @update="onPanelUpdate" />

    <ShareModal :open="!!shareState" :level="shareState?.level || 'card'"
                :block="shareState?.block" :page="state.page" :kid="currentChild()"
                @close="shareState = null" />
  </template>
</template>
