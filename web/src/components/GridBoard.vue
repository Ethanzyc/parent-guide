<script setup>
// Dual-mode board:
//   server mode -> GridStack editor: free drag placement, corner resize,
//                  auto-compact on release (float:false), debounced write-back.
//   file mode   -> CSS grid streaming read-only (x/y/h ignored, order + w).
//
// DOM ownership rule (the v11 lesson, Vue edition): GridStack owns the live
// grid DOM once mounted. Blocks are snapshotted into a shallow ref -- geometry
// write-backs mutate the snapshot fields WITHOUT triggering a re-render, so
// Vue never re-patches nodes GridStack has moved (that fight = "cards jump
// around"). Full rebuild happens only via :key bump (JSON apply / reset).
import { onMounted, onBeforeUnmount, ref, shallowRef, watch, nextTick } from 'vue'
import { GridStack } from 'gridstack'
import { cardFor, isCustom } from './cards/index.js'
import { clampInt } from '../lib/util.js'

const props = defineProps({
  page: { type: Object, required: true },
  kid: { type: Object, default: () => ({}) },
  editing: Boolean,
  serverMode: Boolean,
})
const emit = defineEmits(['geometry', 'share-card', 'remove', 'edit-props', 'props-update'])

// Custom-card content updates (e.g. list checkboxes): patch the snapshot
// element in place (keeps geometry write-back in sync with latest props),
// then bubble up so App persists page.json. No rebuild needed.
function onPropsUpdate(b, nextProps) {
  b.props = { ...(b.props || {}), ...nextProps }
  emit('props-update', { id: b.id, props: b.props })
}

const gridEl = ref(null)
const items = shallowRef([])          // snapshot; field mutations stay silent
let gs = null
let saveTimer = null

function snapshot() {
  const L = props.page?.layout || {}
  const cols = L.cols || 12
  items.value = (props.page?.blocks || []).map(b => ({
    ...b,
    w: clampInt(b.w, 1, cols, 6), h: clampInt(b.h, 1, 20, 4),
  }))
}

onMounted(async () => {
  snapshot()
  if (!props.serverMode) return
  await nextTick()
  const L = props.page?.layout || {}
  // GridStack.init auto-registers the Vue-rendered .grid-stack-item children
  // (they already carry gs-x/y/w/h/id attributes). Do NOT makeWidget them
  // again -- double registration duplicates ids (profile -> profile_1) and
  // the two layout entries fight each other (= "cards jump around").
  gs = GridStack.init({
    column: L.cols || 12,
    cellHeight: L.rowHeight || 72,
    margin: L.margin ?? 12,
    float: false,            // release -> vertical compact (grid-layout-plus parity)
    staticGrid: !props.editing,
  }, gridEl.value)
  gs.on('change', scheduleSync)
  // saved y values can leave holes; collapse them once on load
  gs.compact()
})

onBeforeUnmount(() => {
  if (gs) { gs.destroy(); gs = null }
})

watch(() => props.editing, v => { if (gs) gs.setStatic(!v) })

function scheduleSync() {
  clearTimeout(saveTimer)
  saveTimer = setTimeout(() => {
    if (!gs) return
    const geo = new Map((gs.save(false) || []).map(i => [i.id, i]))
    // mutate snapshot fields in place: DOM stays GridStack's, files get updated
    for (const b of items.value) {
      const g = geo.get(b.id)
      if (g) { b.x = g.x; b.y = g.y; b.w = g.w; b.h = g.h }
    }
    emit('geometry', items.value.map(b => ({ ...b })))
  }, 300)  // debounce: no high-frequency writes mid-drag
}
</script>

<template>
  <!-- 服务模式:GridStack 编辑器(Geometry by GS, content by Vue) -->
  <main v-if="serverMode" id="grid" ref="gridEl">
    <div v-for="b in items" :key="b.id" class="grid-stack-item"
         :gs-x="b.x" :gs-y="b.y" :gs-w="b.w" :gs-h="b.h" :gs-id="b.id">
      <div class="grid-stack-item-content">
        <div class="card">
          <component :is="cardFor(b.type)" :block="b" :kid="kid" @update="p => onPropsUpdate(b, p)" />
          <div v-if="editing" class="card-tools">
            <button v-if="isCustom(b.type)" class="tool" title="编辑内容" @click.stop="emit('edit-props', b)">✎ 编辑</button>
            <button class="tool danger" title="删除这张卡" @click.stop="emit('remove', b)">✕</button>
          </div>
          <button v-else class="share-fab" title="生成家人分享长图" @click.stop="emit('share-card', b)">⤴ 分享</button>
        </div>
      </div>
    </div>
  </main>

  <!-- 文件模式:CSS grid 流式只读 -->
  <main v-else class="grid">
    <section v-for="b in items" :key="b.id" class="card"
             :style="{ '--w': clampInt(b.w, 1, 12, 6) }">
      <component :is="cardFor(b.type)" :block="b" :kid="kid" @update="p => onPropsUpdate(b, p)" />
      <div v-if="editing" class="card-tools">
        <button v-if="isCustom(b.type)" class="tool" title="编辑内容" @click.stop="emit('edit-props', b)">✎ 编辑</button>
        <button class="tool danger" title="删除这张卡" @click.stop="emit('remove', b)">✕</button>
      </div>
      <button v-else class="share-fab" title="生成家人分享长图" @click.stop="emit('share-card', b)">⤴ 分享</button>
    </section>
  </main>
</template>

<style scoped>
.share-fab { position: absolute; top: 8px; right: 8px; z-index: 3; opacity: 0;
  border: 1px solid #efe9e0; background: rgba(255,255,255,.95); color: #8a8478;
  border-radius: 99px; padding: 2px 10px; font-size: 12px; cursor: pointer;
  transition: opacity .15s; }
.card:hover .share-fab { opacity: 1; }
.share-fab:hover { border-color: #e8734a; color: #e8734a; }
/* 编辑布局时整卡都是拖拽把手,分享按钮退场防误触 */
:global(body.editing) .share-fab { display: none; }
/* 编辑模式的卡内工具(删除/编辑内容) */
.card-tools { position: absolute; top: 8px; right: 8px; z-index: 3; display: flex; gap: 6px; }
.tool { border: 1px solid #efe9e0; background: rgba(255,255,255,.95); color: #8a8478;
  border-radius: 99px; padding: 2px 10px; font-size: 12px; cursor: pointer; }
.tool:hover { border-color: #e8734a; color: #e8734a; }
.tool.danger:hover { border-color: #d64545; color: #d64545; background: #fdf2f2; }
</style>
