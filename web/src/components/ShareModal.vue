<script setup>
// 家人分享长图:预览即所发。
// 家人版 ≠ 档案版(调研 docs/sharing-research-2026-10-01.md §3):
//   大字号/去内部黑话(id、英文状态)/必带截至日期/familyNotes 永不出现在此。
// 条目级分享 = 卡片分享时按条勾选(主场景:给长辈的「一条口径」)。
// 整页分享 = 页面级导出,按卡勾选(用户拍板 2026-10-01)。
import { ref, computed, watch } from 'vue'
import { domToPng } from 'modern-screenshot'
import { monthsAge, nearestMilestone } from '../lib/util.js'

const props = defineProps({
  open: Boolean,
  level: { type: String, default: 'card' },   // 'page' | 'card'
  block: { type: Object, default: null },     // card 级的目标卡
  page: { type: Object, default: null },      // page 级的整页配置
  kid: { type: Object, default: () => ({}) },
})
const emit = defineEmits(['close'])

const anonymized = ref(false)
const branded = ref(true)
const exporting = ref(false)
const selected = ref([])       // card 级:条目勾选
const blocksOn = ref([])       // page 级:卡片勾选
const nodeEl = ref(null)

// 状态转人话(家人版不出现 S1/effective 这类内部口径)
const ST = { active: '试行中', effective: '有效', partial: '部分有效',
  ineffective: '效果不佳', suspended: '已暂停', absorbed: '已成日常' }
const MS = { ok: '已会', watch: '观察中', todo: '还没会' }
const TITLES = { 'profile': '孩子档案', 'milestone': '里程碑', 'sleep-week': '一周睡眠',
  'strategy-effect': '策略口径', 'followup': '待回访', 'note': '成长速记' }

// 「第 N 天」:MM-DD 视为当年;算不出/太久远就退回「自 x-x」
function dayNo(started) {
  if (!started) return ''
  const now = new Date()
  let s = null
  if (/^\d{4}-\d{2}-\d{2}$/.test(started)) s = new Date(started)
  else if (/^\d{1,2}-\d{1,2}$/.test(started)) {
    const [m, d] = started.split('-').map(Number)
    s = new Date(now.getFullYear(), m - 1, d)
  }
  if (!s || isNaN(s)) return ''
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const n = Math.round((today - s) / 86400000) + 1
  return (n >= 1 && n <= 999) ? `第 ${n} 天` : `自 ${started}`
}

const dots = (w) => '●'.repeat(Number(w) || 0) || '—'
const todayStr = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// 每种卡 → 通用行模型(kind 决定渲染分支);一律返回 { rows, ...附加信息 }
function rowsFor(b) {
  const kid = props.kid || {}
  const t = b?.type
  if (t === 'strategy-effect') {
    const want = b?.props?.status
    const rows = (kid.strategies || [])
      .filter(s => !want || want === 'all' || s.status === want)
      .map(s => {
        const d = dayNo(s.started)
        const sinceLine = !s.started ? '' : d.startsWith('第') ? `自 ${s.started} · ${d}` : `自 ${s.started}`
        const fu = s.followup && s.evidence ? `${s.followup}(${s.evidence})` : (s.followup || s.evidence || '')
        return { kind: 'strategy', label: s.name, name: s.name,
          st: ST[s.status] || s.status, stRaw: s.status, sinceLine, applied: s.applied, fu }
      })
    return { rows }
  }
  if (t === 'milestone') {
    const m = b?.props?.months || nearestMilestone(monthsAge(kid.birthdate))
    const data = kid.milestones?.[m]
    const rows = (data?.items || [])
      .map(i => ({ kind: 'milestone', label: i.domain, st: MS[i.status] || i.status,
        stRaw: i.status, domain: i.domain, text: i.text }))
    return { m, source: data?.source, rows }
  }
  if (t === 'sleep-week') {
    const rows = (kid.sleep?.days || [])
      .map(d => ({ kind: 'sleep', label: d.date, date: d.date,
        dots: dots(d.wakings), hours: (Number(d.totalHours) || 0).toFixed(1) }))
    return { note: kid.sleep?.note, rows }
  }
  if (t === 'followup') {
    const rows = (kid.followups || [])
      .map(f => ({ kind: 'followup', label: `${f.due} ${f.topic}`.slice(0, 14), due: f.due, topic: f.topic }))
    return { rows }
  }
  if (t === 'note') {
    const rows = (kid.notes || []).slice(0, b?.props?.limit || 5)
      .map(n => ({ kind: 'note', label: (n.precision && n.precision !== 'day' ? '≈' : '') + n.date,
        approx: n.precision && n.precision !== 'day', date: n.date, tags: n.tags || [], text: n.text }))
    return { rows }
  }
  if (t === 'profile') return { rows: [{ kind: 'profile', label: '档案' }] }
  return { rows: [] }
}

const sections = computed(() => {
  if (!props.open) return []
  if (props.level === 'page') {
    const bs = (props.page?.blocks || []).filter((b, i) => (blocksOn.value[i] ?? true) !== false)
    return bs.map(b => {
      const r = rowsFor(b)
      return { id: b.id, type: b.type, title: TITLES[b.type] || b.type, rows: r.rows, extra: r }
    })
  }
  if (!props.block) return []
  const r = rowsFor(props.block)
  const rows = r.rows.filter((_, i) => selected.value[i] !== false)
  return [{ id: props.block.id, type: props.block.type, title: TITLES[props.block.type] || props.block.type, rows, extra: r }]
})

const chips = computed(() => {   // card 级的条目勾选标签
  if (props.level !== 'card' || !props.block) return []
  return rowsFor(props.block).rows.map((row, i) => ({ i, on: selected.value[i] !== false, label: row.label }))
})

const age = computed(() => {
  const m = monthsAge(props.kid?.birthdate)
  return m > 0 ? `${m} 个月` : ''
})
const dispName = computed(() => anonymized.value ? '宝宝' : (props.kid?.name || '宝宝'))
const headTitle = computed(() => props.level === 'page' ? `${dispName.value}的成长视图` : (TITLES[props.block?.type] || '成长卡片'))
const headSub = computed(() =>
  [props.level === 'card' ? dispName.value : '', age.value, `截至 ${todayStr()}`].filter(Boolean).join(' · '))

watch(() => [props.open, props.level, props.block?.id], () => {
  selected.value = []
  blocksOn.value = (props.page?.blocks || []).map(() => true)
})

function toggleRow(i) { selected.value[i] = selected.value[i] === false ? true : false }
function toggleBlock(i) { blocksOn.value[i] = blocksOn.value[i] === false ? true : false }

const fileTitle = () => props.level === 'page' ? '成长视图' : (TITLES[props.block?.type] || '卡片')
async function save() {
  if (!nodeEl.value || exporting.value) return
  exporting.value = true
  try {
    const url = await domToPng(nodeEl.value, { scale: 2, backgroundColor: '#ffffff' })
    const blob = await (await fetch(url)).blob()
    const name = `成长分享-${dispName.value}-${fileTitle()}-${todayStr()}.png`
    const file = new File([blob], name, { type: 'image/png' })
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      try { await navigator.share({ files: [file], title: name }); return }
      catch (e) { if (e?.name === 'AbortError') return }
    }
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = name
    a.click()
    URL.revokeObjectURL(a.href)
  } finally { exporting.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="share-mask" @click.self="emit('close')">
      <div class="share-dialog">
        <div class="share-head">
          <b>分享给家人</b><span class="hint">预览即所发 · 长图发微信</span>
          <button class="x" @click="emit('close')">✕</button>
        </div>

        <div class="share-controls">
          <label><input type="checkbox" v-model="anonymized"> 隐去小名</label>
          <label><input type="checkbox" v-model="branded"> 署名页脚</label>
          <button class="btn primary" :disabled="exporting" @click="save">{{ exporting ? '生成中…' : '保存长图' }}</button>
        </div>

        <div v-if="chips.length" class="share-chips">
          <span class="chip" :class="{ off: !c.on }" v-for="c in chips" :key="c.i"
                @click="toggleRow(c.i)">{{ c.on ? '✓ ' : '' }}{{ c.label }}</span>
        </div>
        <div v-else-if="level === 'page'" class="share-chips">
          <span class="chip" :class="{ off: blocksOn[i] === false }" v-for="(b, i) in (page?.blocks || [])" :key="b.id"
                @click="toggleBlock(i)">{{ blocksOn[i] === false ? '' : '✓ ' }}{{ TITLES[b.type] || b.type }}</span>
        </div>

        <div class="share-scroll">
          <div class="share-card" ref="nodeEl">
            <div class="sc-head">
              <div class="sc-title">{{ headTitle }}</div>
              <div class="sc-sub">{{ headSub }}</div>
            </div>

            <div v-for="sec in sections" :key="sec.id" class="sc-sec">
              <template v-if="level === 'page'"><div class="sc-sec-title">{{ sec.title }}</div></template>

              <template v-for="(row, i) in sec.rows" :key="i">
                <div v-if="row.kind === 'strategy'" class="sc-row strategy">
                  <div class="r1"><b>{{ row.name }}</b><span class="pill" :class="row.stRaw">{{ row.st }}</span></div>
                  <div v-if="row.sinceLine" class="since">{{ row.sinceLine }}</div>
                  <div class="main">{{ row.applied }}</div>
                  <div v-if="row.fu" class="fu">{{ row.fu }}</div>
                </div>
                <div v-else-if="row.kind === 'milestone'" class="sc-row milestone">
                  <span class="pill" :class="row.stRaw">{{ row.st }}</span>
                  <span class="domain">{{ row.domain }}</span>
                  <span class="main">{{ row.text }}</span>
                </div>
                <div v-else-if="row.kind === 'sleep'" class="sc-row sleep">
                  <span class="date">{{ row.date }}</span>
                  <span class="dots">{{ row.dots }}</span>
                  <span class="hrs">{{ row.hours }}h</span>
                </div>
                <div v-else-if="row.kind === 'followup'" class="sc-row followup">
                  <span class="due">{{ row.due }}</span><span class="main">{{ row.topic }}</span>
                </div>
                <div v-else-if="row.kind === 'note'" class="sc-row note">
                  <span class="date">{{ row.approx ? '≈' : '' }}{{ row.date }}</span>
                  <span v-for="t in row.tags" :key="t" class="ntag">{{ t }}</span>
                  <span class="main">{{ row.text }}</span>
                </div>
                <div v-else-if="row.kind === 'profile'" class="sc-row profile">
                  <div class="kv"><b>孩子</b><span>{{ dispName }}{{ age ? `(${age})` : '' }}</span></div>
                  <div class="kv" v-if="(kid.currentFocus || []).length"><b>当前关注</b>
                    <span class="focus">{{ kid.currentFocus.join('、') }}</span></div>
                </div>
              </template>

              <div v-if="!sec.rows.length" class="sc-empty">暂无内容</div>
              <div v-if="sec.extra?.source" class="sc-src">来源:{{ sec.extra.source }}</div>
              <div v-if="sec.extra?.note" class="sc-src">{{ sec.extra.note }}</div>
            </div>

            <div class="sc-foot">{{ branded ? '由 parent-guide 生成' : '\u00a0' }}</div>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.share-mask { position: fixed; inset: 0; background: rgba(61,58,52,.45); z-index: 50;
  display: flex; align-items: center; justify-content: center; padding: 20px; }
.share-dialog { background: #faf7f2; border-radius: 16px; width: min(460px, 100%);
  max-height: 92vh; display: flex; flex-direction: column; overflow: hidden;
  box-shadow: 0 12px 40px rgba(0,0,0,.25); }
.share-head { display: flex; align-items: center; gap: 10px; padding: 12px 16px;
  background: #fff; border-bottom: 1px solid #efe9e0; }
.share-head b { font-size: 15px; }
.share-head .hint { font-size: 12px; color: #8a8478; }
.share-head .x { margin-left: auto; border: 0; background: none; font-size: 15px;
  cursor: pointer; color: #8a8478; padding: 4px 8px; }
.share-controls { display: flex; align-items: center; gap: 16px; padding: 10px 16px;
  background: #fff; border-bottom: 1px solid #efe9e0; font-size: 13px; }
.share-controls label { color: #3d3a34; display: flex; gap: 5px; align-items: center; cursor: pointer; }
.share-controls .btn { margin-left: auto; border: 0; background: #e8734a; color: #fff;
  border-radius: 8px; padding: 7px 16px; font-size: 13px; cursor: pointer; }
.share-controls .btn:disabled { opacity: .5; }
.share-chips { display: flex; flex-wrap: wrap; gap: 6px; padding: 10px 16px;
  border-bottom: 1px solid #efe9e0; background: #fff; }
.share-chips .chip { background: #fdeee7; color: #e8734a; border-radius: 99px;
  padding: 2px 10px; font-size: 12px; cursor: pointer; user-select: none; max-width: 100%;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.share-chips .chip.off { background: #f2efe9; color: #b5afa4; text-decoration: line-through; }
.share-scroll { overflow: auto; padding: 16px; }

/* ↓ 导出节点:自包含、375px 手机宽、大字号(家人版) */
.share-card { width: 375px; background: #ffffff; border-radius: 16px;
  padding: 20px 22px 14px; color: #3d3a34; font-size: 15.5px; line-height: 1.65;
  font-family: -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif; }
.sc-head { border-bottom: 2px solid #fdeee7; padding-bottom: 10px; margin-bottom: 12px; }
.sc-title { font-size: 19px; font-weight: 700; }
.sc-sub { font-size: 12.5px; color: #8a8478; margin-top: 2px; }
.sc-sec { padding: 4px 0; }
.sc-sec-title { font-size: 15px; font-weight: 600; color: #e8734a; margin: 10px 0 2px; }
.sc-row { padding: 9px 0; border-bottom: 1px dashed #efe9e0; }
.sc-row:last-child { border-bottom: none; }
.sc-row .r1 { display: flex; align-items: center; gap: 8px; }
.sc-row .r1 b { font-size: 16.5px; }
.pill { flex: none; font-size: 12px; border-radius: 6px; padding: 1px 9px; }
.pill.active { background: #fbf3e3; color: #c98a2d; }
.pill.effective { background: #eaf5ef; color: #3a9a6e; }
.pill.partial { background: #fbf3e3; color: #c98a2d; }
.pill.ineffective, .pill.suspended, .pill.absorbed { background: #f2efe9; color: #8a8478; }
.pill.ok { background: #eaf5ef; color: #3a9a6e; }
.pill.watch { background: #fbf3e3; color: #c98a2d; }
.pill.todo { background: #f9ece9; color: #b0685c; }
.since { font-size: 12.5px; color: #8a8478; margin: 1px 0 3px; }
.main { display: block; }
.fu { font-size: 13px; color: #8a8478; margin-top: 3px; }
.milestone { display: flex; gap: 8px; align-items: baseline; font-size: 15px; }
.milestone .pill { min-width: 3.4em; text-align: center; }
.milestone .domain { flex: none; width: 5em; color: #8a8478; font-size: 13.5px; }
.sleep { display: flex; gap: 10px; align-items: baseline; font-size: 14.5px; }
.sleep .date { flex: none; color: #8a8478; }
.sleep .dots { color: #c98a2d; letter-spacing: 2px; }
.sleep .hrs { margin-left: auto; font-weight: 600; }
.followup { display: flex; gap: 10px; align-items: baseline; }
.followup .due { flex: none; background: #fdeee7; color: #e8734a; border-radius: 6px;
  padding: 1px 8px; font-size: 12.5px; }
.note .date { flex: none; color: #8a8478; margin-right: 6px; font-size: 13.5px; }
.note .ntag { display: inline-block; background: #fdeee7; color: #e8734a;
  border-radius: 6px; padding: 0 6px; font-size: 11.5px; margin-right: 4px; }
.profile .kv { display: flex; gap: 10px; padding: 3px 0; font-size: 15px; }
.profile .kv b { flex: none; color: #8a8478; font-weight: 500; min-width: 4.5em; }
.sc-empty { color: #8a8478; font-size: 13.5px; padding: 8px 0; }
.sc-src { font-size: 11.5px; color: #8a8478; margin-top: 6px; }
.sc-foot { text-align: center; color: #b5afa4; font-size: 11.5px; margin-top: 14px; }
</style>
