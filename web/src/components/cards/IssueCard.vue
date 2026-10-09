<script setup>
// 问题追踪入口卡:三色计数(里程碑同款大数字)+问题行。
// 骨架字段直读;next/倒计时从该问题 pending followups 机械派生
// (spec issue-tracking-v1 §2.4,不存冗余字段)。
import { computed } from 'vue'
import { daysSince, dueLabel } from '../../lib/util.js'

const props = defineProps({ block: Object, kid: Object })
const emit = defineEmits(['open-issue'])

const ST_LABEL = { active: '进行中', watching: '观察中', resolved: '已解决' }
const ST_CLASS = { active: 'watch', watching: 'plain', resolved: 'ok' }

const all = computed(() => props.kid?.issues || [])
const list = computed(() => {
  const want = props.block?.props?.status
  return all.value.filter(i => (want ? i.status === want : i.status !== 'resolved'))
})
const counts = computed(() => ({
  live: all.value.filter(i => i.status === 'active' || i.status === 'watching').length,
  care: all.value.filter(i => i.status !== 'resolved' && i.pendingCare).length,
  done: all.value.filter(i => i.status === 'resolved').length,
}))
function nextOf(i) {
  return (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending' && (f.issues || []).includes(i.id))
    .sort((a, b) => String(a.due).localeCompare(String(b.due)))[0] || null
}
const dayNo = (i) => {
  const d = daysSince(i.opened)
  return d !== null ? `第 ${d + 1} 天` : `自 ${i.opened}`
}
</script>

<template>
  <h3>问题追踪<span v-if="counts.care" class="care-n">{{ counts.care }} 件就医待办</span></h3>
  <template v-if="all.length">
    <div class="mnums num-serif">
      <span class="mn"><i style="color:var(--watch)">{{ counts.live }}</i><small>进行中</small></span>
      <span class="mn"><i style="color:var(--todo)">{{ counts.care }}</i><small>待就医</small></span>
      <span class="mn"><i style="color:var(--ok)">{{ counts.done }}</i><small>已解决</small></span>
    </div>
    <div v-for="i in list" :key="i.id" class="irow" @click="emit('open-issue', i.id)">
      <span class="st" :class="ST_CLASS[i.status] || 'plain'">{{ ST_LABEL[i.status] || i.status }}</span>
      <span class="nm">{{ i.name }}</span>
      <span class="dy">{{ dayNo(i) }}</span>
      <span class="nx">
        <span v-if="i.pendingCare" class="care">{{ i.pendingCare }}</span>
        <template v-else-if="nextOf(i)">{{ nextOf(i).due }} · {{ dueLabel(nextOf(i).due).label }}</template>
        <template v-else>{{ (i.summary || '').slice(0, 14) }}</template>
      </span>
    </div>
    <div v-if="!list.length" class="src">当前过滤下没有问题。</div>
  </template>
  <template v-else>
    <div class="src">还没有在管问题——聊到持续议题(便秘/发脾气/戒断类)时开题,记录会自动归集到这里。</div>
  </template>
</template>

<style scoped>
.mnums { display: flex; gap: 16px; margin-bottom: 10px; }
.mn { text-align: center; }
.mn i { display: block; font-style: normal; font-size: 27px; font-weight: 700; line-height: 1.15; }
.mn small { font-size: 10.5px; color: var(--sub); letter-spacing: .06em; }
.care-n { margin-left: auto; font-size: 11px; color: var(--todo); border: 1px solid var(--todo);
  border-radius: 4px; padding: 0 6px; letter-spacing: .04em; font-weight: 600; }
.irow { display: flex; gap: 8px; align-items: baseline; padding: 7px 0;
  border-bottom: 1px dashed var(--line); font-size: 13.5px; cursor: pointer; }
.irow:last-child { border-bottom: none; }
.irow .nm { font-weight: 600; }
.irow .dy { color: var(--sub); font-size: 12px; font-family: Georgia, serif; }
.irow .nx { color: var(--sub); font-size: 12.5px; margin-left: auto; text-align: right;
  min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 45%; }
.irow .nx .care { color: var(--todo); }
.st { flex: none; font-size: 10.5px; border: 1px solid; border-radius: 4px; padding: 0 6px;
  min-width: 3.2em; text-align: center; font-weight: 600; letter-spacing: .04em; }
.st.watch { background: transparent; color: var(--watch); border-color: var(--watch); }
.st.ok { background: transparent; color: var(--ok); border-color: var(--ok); }
.st.plain { background: transparent; color: var(--sub); border-color: var(--sub); }
</style>
