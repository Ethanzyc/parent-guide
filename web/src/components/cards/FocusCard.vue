<script setup>
// 今日行动卡(2026-10-11 focus 卡重定位,用户八案拍板#2):主页缺的不是
// 「当前关注」(档案卡 chips 已有)而是「今天该管什么」——就医待办+≤48h
// 到期回访+在跑计数,全部机械可算(pendingCare / followups.due / strategies),
// 不造语义;点击行=开对应病历(有 issues 挂靠时)。无行动日显示最近节点,
// 空态也是信息。
import { computed } from 'vue'
import { daysSince, dueKey, dueLabel, fullDate } from '../../lib/util.js'

const props = defineProps({ block: Object, kid: Object })
const emit = defineEmits(['open-issue'])

// 就医待办(常驻,优先级最高):在管问题里所有 pendingCare
const careRows = computed(() =>
  (props.kid?.issues || [])
    .filter(i => i.status !== 'resolved' && i.pendingCare)
    .map(i => ({ issue: i, text: i.pendingCare })))

// ≤48h 窗口内的回访(过期未做也算今天的事):due 距今天 -7..+2 天
function dueDiff(due) {
  const d = new Date(fullDate(due))
  if (isNaN(d)) return null
  const today = new Date(); today.setHours(0, 0, 0, 0)
  return Math.round((d - today) / 86400000)
}
const dueRows = computed(() =>
  (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending')
    .map(f => ({ ...f, diff: dueDiff(f.due) }))
    .filter(f => f.diff !== null && f.diff <= 2 && f.diff >= -7)
    .sort((a, b) => a.diff - b.diff))

// 汇总行:在跑计划 + 48h 外最近的一个节点(回访/前瞻提醒)
const running = computed(() =>
  (props.kid?.strategies || []).filter(s => ['active', 'effective', 'partial'].includes(s?.status)))
const nearestLater = computed(() => {
  const fus = (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending')
    .map(f => ({ due: f.due, topic: f.topic, diff: dueDiff(f.due) }))
    .filter(f => f.diff !== null && f.diff > 2)
  const rems = (props.kid?.reminders || [])
    .filter(r => (r.status || 'pending') === 'pending')
    .map(r => ({ due: r.due, topic: r.topic, diff: dueDiff(r.due) }))
    .filter(r => r.diff !== null)
  return [...fus, ...rems].sort((a, b) => a.diff - b.diff)[0] || null
})
const issueOf = (row) =>
  (row.issues || []).length
    ? (props.kid?.issues || []).find(i => i.id === row.issues[0] && i.status !== 'resolved') : null
const openRow = (row) => { const i = issueOf(row); if (i) emit('open-issue', i.id) }
</script>

<template>
  <div class="cband"><h3>今天该管什么</h3></div>
  <div class="cbody">
    <template v-if="careRows.length || dueRows.length">
      <div v-for="r in careRows" :key="r.issue.id" class="act care"
           :class="{ lnk: true }" :title="`点击查看${r.issue.name}病历`"
           @click="emit('open-issue', r.issue.id)">
        <span class="alab">就医待办</span>
        <span class="atxt">{{ r.text }}</span>
        <span class="adr">{{ r.issue.id }}</span>
      </div>
      <div v-for="f in dueRows" :key="f.due + f.topic" class="act next"
           :class="{ lnk: issueOf(f) }" :title="issueOf(f) ? '点击查看病历' : ''"
           @click="openRow(f)">
        <span class="alab">{{ f.diff < 0 ? `过期 ${-f.diff} 天` : f.diff === 0 ? '今天到期' : f.diff === 1 ? '明天' : `${f.diff} 天后` }}</span>
        <span class="atxt">{{ f.topic }}</span>
        <span class="adr">{{ issueOf(f) ? issueOf(f).id + ' · ' : '' }}{{ fullDate(f.due) }}</span>
      </div>
    </template>
    <div v-else class="calm">今天没有到期事项 ✓</div>

    <div class="rollup">
      <template v-if="running.length">在跑 {{ running.length }} 个计划({{ running.map(s => s.id).slice(0, 3).join('/') }}{{ running.length > 3 ? '…' : '' }})</template>
      <template v-if="nearestLater">
        <template v-if="running.length"> · </template>
        下一个节点 {{ nearestLater.diff <= 30 ? dueLabel(nearestLater.due).label : fullDate(nearestLater.due) }}
      </template>
      <template v-if="!running.length && !nearestLater">回对话说「记一下…」立追踪后,这里汇总今天该管的事</template>
    </div>
  </div>
</template>

<style scoped>
.act { display: flex; gap: 10px; align-items: baseline; padding: 8px 12px;
  border: 1px solid var(--line); border-radius: 6px; margin-bottom: 8px;
  font-size: 13.5px; line-height: 1.55; }
.act.lnk { cursor: pointer; }
.act.lnk:hover { border-color: var(--ink-blue); background: var(--accent-soft); }
.act.care { border-color: var(--todo); }
.act.next { border-color: var(--ink-blue); }
.act .alab { flex: none; font-size: 11px; border: 1px solid; border-radius: 4px;
  padding: 0 6px; font-weight: 600; letter-spacing: .04em; }
.act.care .alab { color: var(--todo); border-color: var(--todo); }
.act.next .alab { color: var(--ink-blue); border-color: var(--ink-blue); }
.act .atxt { min-width: 0; }
.act .adr { margin-left: auto; flex: none; font-size: 11px; color: var(--sub);
  font-family: Georgia, serif; font-variant-numeric: tabular-nums; }
.calm { font-size: 13px; color: var(--ok); padding: 6px 2px; }
.rollup { font-size: 12px; color: var(--sub); padding: 8px 2px 0;
  border-top: 1px dashed var(--line); margin-top: 2px; }
</style>
