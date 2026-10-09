<script setup>
import { onMounted, ref, watch } from 'vue'
import { state, init, currentChild, applyGeometry, applyJsonPage, persistPage, resetDefault } from './lib/store.js'
import GridBoard from './components/GridBoard.vue'
import JsonDrawer from './components/JsonDrawer.vue'
import ShareModal from './components/ShareModal.vue'
import CardManager from './components/CardManager.vue'
import IssueDetail from './components/IssueDetail.vue'
import { CARD_META } from './components/cards/index.js'

onMounted(init)

const drawerOpen = ref(false)
const managerOpen = ref(false)
const shareState = ref(null)     // null | { level: 'page' | 'card' | 'issue', block, issue }
const issueOpen = ref(null)      // 打开详情覆盖层的 issue id;#issue-P1 hash 可直链
// 背景滚动锁(单一来源:任一弹窗开即锁;组件各管会互相覆盖)
watch([() => !!shareState.value, () => !!issueOpen.value], ([a, b]) => {
  document.body.style.overflow = (a || b) ? 'hidden' : ''
}, { immediate: true })
const print = () => window.print()
const openSite = () => window.open('/site/index.html', '_blank')
if (/^#issue-P\d+$/.test(window.location.hash)) issueOpen.value = window.location.hash.slice(7)

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

// -- card visibility management ------------------------------------------------
function nextId(page) {
  const nums = (page?.blocks || [])
    .map(b => String(b.id || '').match(/^b(\d+)$/)).filter(Boolean).map(m => +m[1])
  return 'b' + ((nums.length ? Math.max(...nums) : 0) + 1)
}

// switch an existing block on/off; off keeps the block (hidden:true) so the
// geometry and any custom content survive a re-enable
function onToggle({ id, on }) {
  const block = state.page?.blocks?.find(x => x.id === id)
  if (!block) return
  block.hidden = !on
  if (on) delete block.hidden
  applyJsonPage(state.page)   // rebuild: GridBoard snapshot filters hidden
}

// turn on a builtin type that has no block yet -> add one with default geometry
function onShow(type) {
  const meta = CARD_META[type]
  if (!meta) return
  const cols = state.page?.layout?.cols || 12
  const blocks = state.page?.blocks || []
  const maxY = Math.max(0, ...blocks.map(b => (b.y || 0) + (b.h || 4)))
  const block = { id: nextId(state.page), type, x: 0, y: maxY,
                  w: Math.min(meta.w || 6, cols), h: meta.h || 4 }
  applyJsonPage({ ...state.page, blocks: [...blocks, block] })
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
      <button class="btn" @click="managerOpen = true" title="显示/隐藏卡片;想加自定义卡(便签/清单)回对话跟 AI 说">☰ 卡片管理</button>
      <button v-if="state.serverMode" class="btn" title="睡眠/营养/情绪/如厕等专题与速查表(本地只读)" @click="openSite">📖 知识库</button>
      <button class="btn" :class="{ active: state.editing }" :disabled="!state.serverMode"
              @click="toggleEdit">{{ state.editing ? '完成编辑' : '编辑布局' }}</button>
      <button class="btn" @click="drawerOpen = true">编辑配置</button>
      <button class="btn" title="恢复默认功能卡;自定义卡会保留在页面末尾" @click="resetDefault()">重置默认</button>
      <button class="btn" title="生成发家人微信的长图;卡片右上角 ⤴ 可单卡分享" @click="shareState = { level: 'page', block: null }">分享长图</button>
      <button class="btn" title="数据内嵌的单 HTML 文件,可转发/迁移/存档" @click="exportReport">导出单文件报告</button>
      <button class="btn primary" @click="print">导出 PDF</button>
    </div>

    <GridBoard :key="state.version" :page="state.page" :kid="currentChild()"
               :editing="state.editing" :server-mode="state.serverMode"
               @geometry="applyGeometry" @share-card="b => shareState = { level: 'card', block: b }"
               @props-update="onPropsUpdate" @open-issue="id => issueOpen = id" />

    <footer class="page">示例数据为虚构 · 布局模型:{x, y, w, h} 网格坐标(与 grid-layout-plus 同构)</footer>

    <JsonDrawer :open="drawerOpen" :page="state.page"
                @close="drawerOpen = false" @apply="onApplyPage" />

    <CardManager :open="managerOpen" :page="state.page"
                 @close="managerOpen = false" @toggle="onToggle" @show="onShow" />

    <ShareModal :open="!!shareState" :level="shareState?.level || 'card'"
                :block="shareState?.block" :page="state.page" :kid="currentChild()"
                :issue="shareState?.issue"
                @close="shareState = null" />

    <IssueDetail :open="!!issueOpen" :kid="currentChild()" :issue-id="issueOpen"
                 @close="issueOpen = null"
                 @share-issue="i => { issueOpen = null; shareState = { level: 'issue', block: null, issue: i } }" />
  </template>
</template>
