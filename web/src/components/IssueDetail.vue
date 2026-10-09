<script setup>
// 问题病历层:左列=当前状态卡(行动格优先)+口径卡+红线,右列=时间轴(倒序,
// 最新在最上;窄屏折叠单列)。大节点只认机械事件(opened/judged/strategy.started)
// ——语义归一留读侧(spec issue-tracking-v1 §6.3)。只读:内容变更一律回对话。
import { computed } from 'vue'
import { daysSince, dueLabel } from '../lib/util.js'

const props = defineProps({
  open: Boolean,
  kid: { type: Object, default: () => ({}) },
  issueId: { type: String, default: null },
})
const emit = defineEmits(['close', 'share-issue'])

const ST_LABEL = { active: '进行中', watching: '观察中', resolved: '已解决' }
const ST_CLASS = { active: 'watch', watching: 'plain', resolved: 'ok' }

const issue = computed(() =>
  (props.kid?.issues || []).find(i => i.id === props.issueId) || null)

const dayNo = computed(() => {
  if (!issue.value) return ''
  const d = daysSince(issue.value.opened)
  return d !== null ? `第 ${d + 1} 天` : `自 ${issue.value.opened}`
})
const linked = computed(() => {
  const id = props.issueId, k = props.kid || {}
  return {
    s: (k.strategies || []).filter(x => (x.issues || []).includes(id)).length,
    n: (k.notes || []).filter(x => (x.issues || []).includes(id)).length,
    f: (k.followups || []).filter(x => (x.issues || []).includes(id)).length,
  }
})
const next = computed(() =>
  (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending'
                 && (f.issues || []).includes(props.issueId))
    .sort((a, b) => String(a.due).localeCompare(String(b.due)))[0] || null)

function normKey(d) {
  const s = String(d || ''), y = new Date().getFullYear()
  if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(s)) return s
  if (/^\d{1,2}-\d{1,2}$/.test(s)) return `${y}-${s.padStart(5, '0')}`
  return s
}
// 展示日期统一补全年份(2026-10-09 完整格式,用户拍板 2026-10-09)——
// notes 存 ISO 全日期,opened/started/due 存 MM-DD,读侧归一为同一形态。
const fullDate = (d) => {
  const s = String(d || '')
  if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(s)) return s
  if (/^\d{1,2}-\d{1,2}$/.test(s)) return `${new Date().getFullYear()}-${s.padStart(5, '0')}`
  return s
}
const dispDate = (d, precision) =>
  (precision && precision !== 'day' ? '≈' : '') + fullDate(d)
const events = computed(() => {
  const i = issue.value
  if (!i) return []
  const ev = [{ date: i.opened, dstr: fullDate(i.opened), big: '立案',
                text: `${i.name} 开题${i.status === 'watching' ? '(观察)' : ''}` }]
  if (i.judged && i.brief?.what) ev.push({ date: i.judged, dstr: fullDate(i.judged), big: '判定', text: i.brief.what })
  for (const s of props.kid?.strategies || [])
    if ((s.issues || []).includes(i.id))
      ev.push({ date: s.started, dstr: fullDate(s.started), big: '方案', text: `${s.id} ${s.name}` })
  for (const n of props.kid?.notes || [])
    if ((n.issues || []).includes(i.id))
      ev.push({ date: n.date, dstr: dispDate(n.date, n.precision), text: n.text,
                tags: (n.tags || []).filter(t => t !== i.name) })
  for (const f of props.kid?.followups || [])
    if ((f.issues || []).includes(i.id))
      ev.push({ date: f.due, dstr: fullDate(f.due), text: f.topic, fu: true, status: f.status || 'pending' })
  return ev.sort((a, b) => normKey(b.date).localeCompare(normKey(a.date)))   // 倒序:最新在最上
})
const briefSections = computed(() => {
  const b = issue.value?.brief || {}
  const out = []
  if (b.what) out.push({ key: 'what',
    title: '这是什么问题' + (issue.value?.judged ? ` · 判于 ${issue.value.judged}` : ''),
    body: [b.what] })
  if (b.why?.length) out.push({ key: 'why', title: '为什么这么做', body: b.why })
  if (b.how?.length) out.push({ key: 'how', title: '全家怎么做', body: b.how })
  return out
})
</script>

<template>
  <Teleport to="body">
    <div v-if="open && issue" class="issue-mask" @click.self="emit('close')">
      <div class="issue-sheet">
        <div class="is-head">
          <span class="t">{{ issue.name }}</span>
          <span class="st" :class="ST_CLASS[issue.status]">{{ ST_LABEL[issue.status] }}</span>
          <span class="meta">{{ dayNo }} · 立案 {{ issue.opened }}
            · 策略{{ linked.s }} 记录{{ linked.n }} 回访{{ linked.f }}</span>
          <button class="share-btn" @click="emit('share-issue', issue)">分享问题卡给家人</button>
          <button class="x" title="关闭" @click="emit('close')">✕</button>
        </div>

        <div class="is-cols">
          <div class="is-left">
            <div class="now-card">
              <div class="nc-tag">当前状态</div>
              <div v-if="issue.pendingCare" class="act care">
                <span class="alab">就医待办</span>
                <span class="atxt">{{ issue.pendingCare }}</span>
              </div>
              <div v-if="next" class="act next">
                <span class="alab">下一步</span>
                <span class="atxt">
                  <span class="due-b" :class="dueLabel(next.due).urgency || 'later'">
                    {{ fullDate(next.due) }} · {{ dueLabel(next.due).label }}</span>
                  <span class="ntopic">{{ next.topic }}</span>
                </span>
              </div>
              <div class="nc-main">{{ issue.summary }}</div>
            </div>

            <div v-for="sec in briefSections" :key="sec.key" class="brief">
              <h4>{{ sec.title }}</h4>
              <ul><li v-for="(b, i) in sec.body" :key="i">{{ b }}</li></ul>
            </div>

            <div v-if="issue.brief?.redline" class="redline">
              <h4>出现这些直接就医,不等观察</h4>
              <p>{{ issue.brief.redline }}</p>
            </div>
          </div>

          <div class="is-right">
            <div class="tl-panel">
              <h3>时间线<span class="tag">对话自动归集</span></h3>
              <div class="tl">
                <div v-for="(e, i) in events" :key="i" class="tl-item"
                     :class="{ big: e.big, future: e.fu && e.status === 'pending' }">
                  <span class="d">{{ e.dstr }}</span>
                  <span class="tt">
                    <span v-if="e.big" class="node-b">{{ e.big }}</span>
                    <span :class="{ b: e.big }">{{ e.text }}</span>
                    <span v-for="t in e.tags" :key="t" class="chip">{{ t }}</span>
                    <span v-if="e.fu && e.status === 'pending'" class="due-b"
                          :class="dueLabel(e.date).urgency || 'later'">{{ dueLabel(e.date).label }}</span>
                    <span v-else-if="e.fu" class="fu-done">{{ e.status === 'done' ? '已回访' : '已跳过' }}</span>
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div v-if="briefSections.length || issue.brief?.redline" class="is-foot">
          <span class="foot-hint">内容变更回到对话中说一声即可</span>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.issue-mask { position: fixed; inset: 0; background: rgba(30,58,82,.35); z-index: 40;
  display: flex; align-items: center; justify-content: center; padding: 24px; }
.issue-sheet { background-color: var(--card);
  background-image: linear-gradient(var(--grid) 1px, transparent 1px),
    linear-gradient(90deg, var(--grid) 1px, transparent 1px);
  background-size: 14px 14px;
  border: 1px solid var(--grid-line); border-radius: 12px;
  width: min(1000px, 100%); max-height: 92vh; overflow: auto; padding: 22px 26px; }
.is-cols { display: grid; grid-template-columns: minmax(0, 7fr) minmax(0, 5fr);
  gap: 18px; align-items: start; margin-top: 2px; }
@media (max-width: 860px) { .is-cols { grid-template-columns: 1fr; } }
.is-head { display: flex; align-items: center; gap: 10px; padding-bottom: 12px;
  border-bottom: 1px solid var(--line); margin-bottom: 14px; flex-wrap: wrap; }
.is-head .t { font-size: 19px; font-weight: 700; color: var(--ink-blue); }
.is-head .meta { margin-left: auto; font-size: 12px; color: var(--sub); }
.is-head .share-btn { flex: none; border: 1px solid var(--ink-blue); background: var(--ink-blue);
  color: #fff; border-radius: 8px; padding: 5px 14px; font-size: 12.5px; cursor: pointer; }
.is-head .x { flex: none; border: 0; background: none; color: var(--sub); font-size: 16px;
  cursor: pointer; padding: 2px 4px; }
h3 { font-size: 13px; color: var(--sub); font-weight: 600; letter-spacing: .22em; margin: 16px 0 10px; }
h3 .tag { font-size: 11px; font-weight: 400; letter-spacing: 0;
  border: 1px solid var(--line); border-radius: 5px; padding: 1px 8px; }
.now-card { border: 1.5px solid var(--ink-blue); border-radius: 10px;
  background: rgba(255,255,255,.85); padding: 14px 16px; margin-bottom: 6px; }
.now-card .nc-tag { font-size: 11px; letter-spacing: .2em; color: var(--ink-blue);
  font-weight: 600; margin-bottom: 8px; }
.act { display: flex; gap: 10px; align-items: baseline; padding: 9px 12px;
  border-radius: 8px; margin-bottom: 8px; font-size: 13.5px; line-height: 1.55; }
.act.care { background: var(--todo-bg); border-left: 3px solid var(--todo); }
.act.next { background: var(--accent-soft); border-left: 3px solid var(--ink-blue); }
.act .alab { flex: none; font-size: 11px; letter-spacing: .1em; color: var(--sub);
  font-weight: 600; }
.act .atxt { min-width: 0; }
.act .ntopic { display: inline; }
.now-card .nc-main { font-size: 14.5px; line-height: 1.6; color: var(--ink); }
.brief { border: 1px solid var(--line); border-radius: 10px; padding: 12px 16px;
  margin-top: 10px; background: rgba(255,255,255,.7); }
.brief h4 { font-size: 13px; color: var(--ink-blue); font-weight: 600;
  letter-spacing: .08em; margin-bottom: 4px; }
.brief ul { padding-left: 18px; }
.brief li { font-size: 13.5px; margin: 3px 0; }
.redline { border: 1px solid var(--todo); background: var(--todo-bg);
  border-radius: 10px; padding: 12px 16px; margin-top: 10px; }
.redline h4 { font-size: 13px; color: var(--todo); font-weight: 600; margin-bottom: 4px; }
.redline p { font-size: 13.5px; }
.tl-panel { border: 1px solid var(--line); border-radius: 10px; padding: 12px 16px 14px;
  background: rgba(255,255,255,.7); }
.tl-panel h3 { margin-top: 0; }
.tl { position: relative; padding-left: 18px; }
.tl::before { content: ''; position: absolute; left: 3px; top: 8px; bottom: 8px;
  width: 2px; background: var(--line); border-radius: 2px; }
.tl-item { position: relative; padding: 4px 0 8px; font-size: 13.5px; }
.tl-item::before { content: ''; position: absolute; left: -18px; top: 9px;
  width: 8px; height: 8px; border-radius: 99px; background: var(--ink-blue);
  box-shadow: 0 0 0 2px var(--accent-soft); }
.tl-item .d { color: var(--sub); margin-right: 8px; font-size: 12px;
  font-variant-numeric: tabular-nums; }
.tl-item .tt { display: flex; gap: 6px; align-items: baseline; flex-wrap: wrap; }
.tl-item.big { padding: 6px 0 10px; }
.tl-item.big::before { left: -21px; top: 6px; width: 12px; height: 12px;
  background: #fff; border: 3px solid var(--ink-blue); box-shadow: 0 0 0 2px var(--accent-soft); }
.tl-item.big .tt .b { font-size: 14.5px; font-weight: 600; }
.tl-item.future::before { background: #fff; border: 2px dashed var(--sub);
  box-shadow: none; width: 8px; height: 8px; }
.node-b { flex: none; font-size: 10.5px; border: 1px solid var(--ink-blue); color: var(--ink-blue);
  border-radius: 4px; padding: 0 6px; font-weight: 600; letter-spacing: .04em; }
.chip { display: inline-block; background: rgba(255,255,255,.75); color: var(--ink-blue);
  border: 1px dashed var(--grid-line); border-radius: 6px; padding: 0 8px; font-size: 11.5px; }
.fu-done { color: var(--sub); font-size: 11.5px; }
.st { flex: none; font-size: 10.5px; border: 1px solid; border-radius: 4px; padding: 0 6px;
  min-width: 3.2em; text-align: center; font-weight: 600; letter-spacing: .04em; }
.st.watch { color: var(--watch); border-color: var(--watch); }
.st.plain { color: var(--sub); border-color: var(--sub); }
.st.ok { color: var(--ok); border-color: var(--ok); }
.is-foot { margin-top: 18px; padding-top: 10px; border-top: 1px solid var(--line);
  text-align: center; }
.is-foot .foot-hint { font-size: 11.5px; color: var(--sub); }
.due-b { flex: none; display: inline-flex; align-items: center; border-radius: 5px;
  padding: 1px 8px; font-size: 12px; font-variant-numeric: tabular-nums;
  font-family: Georgia, serif; font-weight: 700; }
.due-b.overdue { background: var(--todo-bg); color: var(--todo); }
.due-b.today { background: var(--watch-bg); color: var(--watch); }
.due-b.soon { background: var(--accent-soft); color: var(--ink-blue); }
.due-b.later { background: rgba(255,255,255,.7); color: var(--ink-blue); }
</style>
