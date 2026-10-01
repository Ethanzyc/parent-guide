<script setup>
import { onMounted, ref } from 'vue'
import { state, init, currentChild, applyGeometry, applyJsonPage, resetDefault } from './lib/store.js'
import GridBoard from './components/GridBoard.vue'
import JsonDrawer from './components/JsonDrawer.vue'
import ShareModal from './components/ShareModal.vue'

onMounted(init)

const drawerOpen = ref(false)
const shareState = ref(null)   // null | { level: 'page' | 'card', block }
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
      <button class="btn" :class="{ active: state.editing }" :disabled="!state.serverMode"
              @click="toggleEdit">{{ state.editing ? '完成编辑' : '编辑布局' }}</button>
      <button class="btn" @click="drawerOpen = true">编辑配置</button>
      <button class="btn" @click="resetDefault()">重置默认</button>
      <button class="btn" @click="shareState = { level: 'page', block: null }">分享长图</button>
      <button class="btn" @click="exportReport">导出单文件报告</button>
      <button class="btn primary" @click="print">导出 PDF</button>
    </div>

    <div class="banner">
      <b>本地服务模式</b>(python3 server.py --open):「编辑布局」后整卡拖拽自由定位、右下角拉角拉伸宽高,松手自动紧凑,改动 300ms 防抖写回 data/page.json;
      <b>文件模式</b>(双击打开):流式只读。<b>分享长图</b>=发家人微信(卡片右上角 ⤴ 可单卡/单条);<b>导出单文件报告</b>=迁移/存档。
    </div>

    <GridBoard :key="state.version" :page="state.page" :kid="currentChild()"
               :editing="state.editing" :server-mode="state.serverMode"
               @geometry="applyGeometry" @share-card="b => shareState = { level: 'card', block: b }" />

    <footer class="page">示例数据为虚构 · 布局模型:{x, y, w, h} 网格坐标(与 grid-layout-plus 同构)</footer>

    <JsonDrawer :open="drawerOpen" :page="state.page"
                @close="drawerOpen = false" @apply="onApplyPage" />

    <ShareModal :open="!!shareState" :level="shareState?.level || 'card'"
                :block="shareState?.block" :page="state.page" :kid="currentChild()"
                @close="shareState = null" />
  </template>
</template>
