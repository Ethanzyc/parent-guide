<script setup>
// 应用内知识库:官方库(公开,点击进 /site/ 同源子站)+ 我的自建(仅本机,
// knowledge/user/ 由 skill 蒸馏/调研沉淀写入,server 端渲染后在此阅读)。
// 自建层永不发布:此面板是它唯一的浏览界面,数据只来自本地 /api/knowledge。
import { ref, watch } from 'vue'
import { linkifyHtml } from '../lib/util.js'

const props = defineProps({ open: Boolean })
const emit = defineEmits(['close'])

const loading = ref(true)
const error = ref('')
const official = ref([])
const user = ref([])
const reading = ref(null) // null | { title, meta, html };进入单篇自建文档阅读

async function load() {
  loading.value = true
  error.value = ''
  reading.value = null
  try {
    const r = await fetch('/api/knowledge')
    if (!r.ok) throw new Error(`HTTP ${r.status}`)
    const d = await r.json()
    official.value = d.official || []
    user.value = d.user || []
  } catch (e) {
    error.value = `知识库加载失败(${e.message})——确认本地服务已在运行`
  } finally {
    loading.value = false
  }
}
watch(() => props.open, (v) => { if (v) load() })

async function openDoc(file) {
  error.value = ''
  try {
    const r = await fetch(`/api/knowledge/read?file=${encodeURIComponent(file)}`)
    const d = await r.json()
    if (!r.ok) throw new Error(d.error || `HTTP ${r.status}`)
    // server 出的是转义后的 HTML,这里只补知识引用转链(同白名单,不自建死链)
    reading.value = { ...d, html: linkifyHtml(d.html) }
  } catch (e) {
    error.value = `打开「${file}」失败:${e.message}`
  }
}
const openOfficial = (slug) => window.open(`/site/${slug}.html`, '_blank')
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="kb-mask" @click.self="emit('close')">
      <div class="kb-sheet">
        <div class="is-head">
          <span class="t">知识库</span>
          <span class="meta">官方库=公开循证知识 · 我的自建=只存在本机</span>
          <button class="x" title="关闭" @click="emit('close')">✕</button>
        </div>

        <div v-if="loading" class="kb-state">加载中…</div>
        <div v-else-if="error" class="kb-state err">{{ error }}</div>

        <template v-else>
          <div v-if="reading" class="kb-reading">
            <button class="kb-back" @click="reading = null">← 返回列表</button>
            <h2 class="doc-title">{{ reading.title }}</h2>
            <div class="doc-meta">
              <span v-if="reading.meta?.date">{{ reading.meta.date }}</span>
              <span v-if="reading.meta?.type" class="kb-badge">{{ reading.meta.type }}</span>
              <span v-if="reading.meta?.check" class="kb-badge">核对={{ reading.meta.check }}</span>
              <span v-if="reading.meta?.source" class="doc-src">来源:{{ reading.meta.source }}</span>
              <span class="kb-badge local">家庭自建 · 仅本地</span>
            </div>
            <!-- eslint-disable-next-line vue/no-v-html —— server 渲染的白名单 markdown -->
            <div class="kb-doc" v-html="reading.html"></div>
          </div>

          <template v-else>
            <h3>官方库 <span class="tag">公开循证知识 · 点击进知识子站</span></h3>
            <div class="kb-grid">
              <button v-for="t in official" :key="t.slug" class="kb-card" @click="openOfficial(t.slug)">
                <b>{{ t.title }}</b>
                <span class="hook">{{ t.hook }}</span>
                <span class="src">{{ t.src }}</span>
              </button>
            </div>

            <h3>我的自建 <span class="tag">仅本机 · 永不随仓库/子站发布</span></h3>
            <div v-if="!user.length" class="kb-empty">
              还没有自建知识。对话里调研沉淀或蒸馏出的专题会写进 knowledge/user/,出现在这里——
              只保存在你自己的电脑上,公开分享的只有上方官方库。
            </div>
            <div v-else class="kb-list">
              <button v-for="u in user" :key="u.file" class="kb-row" @click="openDoc(u.file)">
                <b>{{ u.title }}</b>
                <span class="meta">
                  <span v-if="u.meta?.date">{{ u.meta.date }}</span>
                  <span v-if="u.meta?.type" class="kb-badge">{{ u.meta.type }}</span>
                  <span v-if="u.meta?.check" class="kb-badge">核对={{ u.meta.check }}</span>
                </span>
              </button>
            </div>
          </template>
        </template>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.kb-mask { position: fixed; inset: 0; background: rgba(30,58,82,.58); z-index: 40;
  display: flex; align-items: center; justify-content: center; padding: 24px; }
.kb-sheet { background-color: var(--card);
  background-image: linear-gradient(var(--grid) 1px, transparent 1px),
    linear-gradient(90deg, var(--grid) 1px, transparent 1px);
  background-size: 14px 14px;
  border: 1px solid var(--grid-line); border-radius: 12px;
  width: min(920px, 100%); max-height: 92vh; overflow: auto; padding: 22px 26px; }
.is-head { display: flex; align-items: center; gap: 10px; padding-bottom: 12px;
  border-bottom: 1px solid var(--line); margin-bottom: 14px; flex-wrap: wrap; }
.is-head .t { font-size: 19px; font-weight: 700; color: var(--ink-blue); }
.is-head .meta { flex: 1; min-width: 200px; font-size: 12px; color: var(--sub); }
.is-head .x { flex: none; border: 0; background: none; color: var(--sub); font-size: 16px;
  cursor: pointer; padding: 2px 4px; }
.kb-sheet h3 { font-size: 13px; color: var(--sub); font-weight: 600; letter-spacing: .22em;
  margin: 18px 0 10px; }
.kb-sheet h3 .tag { font-size: 11px; font-weight: 400; letter-spacing: 0;
  border: 1px solid var(--line); border-radius: 5px; padding: 1px 8px; margin-left: 6px; }
.kb-state { padding: 40px 0; text-align: center; color: var(--sub); font-size: 14px; }
.kb-state.err { color: #8a5a2a; }

/* 官方库卡片网格(与知识子站 index 卡同构) */
.kb-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 10px; }
.kb-card { display: flex; flex-direction: column; align-items: flex-start; gap: 5px;
  text-align: left; font: inherit; color: inherit; cursor: pointer;
  background: #fff; border: 1px solid var(--grid-line); border-radius: 10px; padding: 12px 14px; }
.kb-card:hover { border-color: var(--ink-blue); }
.kb-card b { font-size: 15px; color: var(--ink-blue); }
.kb-card .hook { font-size: 12.5px; color: var(--ink); line-height: 1.5; }
.kb-card .src { font-size: 11.5px; color: var(--sub); line-height: 1.45; }

/* 我的自建列表 */
.kb-empty { border: 1px dashed var(--grid-line); border-radius: 10px; background: #fff;
  padding: 16px 18px; font-size: 13px; color: var(--sub); line-height: 1.7; }
.kb-list { display: flex; flex-direction: column; gap: 8px; }
.kb-row { display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  text-align: left; font: inherit; color: inherit; cursor: pointer;
  background: #fff; border: 1px solid var(--grid-line); border-radius: 10px; padding: 11px 14px; }
.kb-row:hover { border-color: var(--ink-blue); }
.kb-row b { font-size: 14px; color: var(--ink-blue); }
.kb-row .meta { display: flex; gap: 6px; align-items: center; margin-left: auto;
  font-size: 12px; color: var(--sub); flex-wrap: wrap; }
.kb-badge { border: 1px solid var(--line); border-radius: 5px; padding: 1px 8px;
  font-size: 11px; color: var(--sub); background: var(--accent-soft, #eef3f7); }
.kb-badge.local { color: #8a5a2a; border-color: #e3d5c0; background: #faf5ec; }

/* 自建文档阅读视图 */
.kb-back { border: 1px solid var(--line); background: #fff; color: var(--ink-blue);
  border-radius: 8px; padding: 4px 12px; font-size: 12.5px; cursor: pointer; margin-bottom: 12px; }
.doc-title { font-size: 21px; color: var(--ink-blue); margin: 2px 0 8px; }
.doc-meta { display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
  font-size: 12px; color: var(--sub); padding-bottom: 12px; border-bottom: 1px solid var(--line);
  margin-bottom: 6px; }
</style>
