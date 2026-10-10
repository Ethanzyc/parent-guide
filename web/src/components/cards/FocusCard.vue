<script setup>
// Focus card = the DYNAMIC half of the archive card's static profile:
// current focus + live issues (with days open) + a mechanical roll-up
// of what's running (active strategies / nearest followup). Archive card owns
// the portrait (temperament/language/preferences); this card owns "now".
import { computed } from 'vue'
import { daysSince, dueLabel } from '../../lib/util.js'

const props = defineProps({ block: Object, kid: Object })
const focus = computed(() => (props.kid?.currentFocus || []).filter(Boolean))
const liveIssues = computed(() =>
  (props.kid?.issues || [])
    .filter(i => i.status !== 'resolved')
    .map(i => ({ ...i, days: daysSince(i.opened) })))

// mechanical roll-up: running strategies + nearest pending followup
const running = computed(() =>
  (props.kid?.strategies || []).filter(s => ['active', 'effective', 'partial'].includes(s?.status)))
const nearestFu = computed(() => {
  const list = (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending')
    .sort((a, b) => String(a.due).localeCompare(String(b.due)))
  return list[0] || null
})
const hasAny = computed(() => focus.value.length || liveIssues.value.length || running.value.length)
</script>

<template>
  <div class="cband"><h3>当前重点</h3></div>
  <div class="cbody">
    <template v-if="hasAny">
      <div v-if="focus.length" style="margin-bottom:10px">
        <span v-for="f in focus" :key="f" class="chip" style="font-size:13px;margin:0 6px 6px 0">{{ f }}</span>
      </div>
      <div v-if="liveIssues.length">
        <div v-for="c in liveIssues" :key="c.id" class="crow">
          <span style="flex:1;min-width:0">{{ c.name }}</span>
          <span class="csince">{{ c.days !== null ? `第 ${c.days + 1} 天` : `自 ${c.opened || '?'}` }}</span>
        </div>
      </div>
      <div v-if="running.length || nearestFu" class="rollup">
        <template v-if="running.length">在跑 {{ running.length }} 个计划({{ running.map(s => s.id).slice(0, 3).join('/') }}{{ running.length > 3 ? '…' : '' }})</template>
        <template v-if="nearestFu">
          <span v-if="running.length"> · </span>
          最近回访 <span class="due-mini" :class="dueLabel(nearestFu.due).urgency">{{ nearestFu.due }}</span>
        </template>
      </div>
    </template>
    <div v-else class="src">还没有记录当前关注——回到对话聊聊最近头疼什么,认领后显示在这里。</div>
  </div>
</template>

<style scoped>
.crow { display: flex; gap: 8px; align-items: baseline; font-size: 13.5px;
  padding: 6px 10px; border: 1px solid var(--line); border-left: 3px solid var(--watch);
  border-radius: 8px; margin-bottom: 5px; }
.crow:last-child { margin-bottom: 0; }
.csince { flex: none; font-size: 11.5px; color: var(--sub);
  font-variant-numeric: tabular-nums; }
.rollup { margin-top: 10px; padding-top: 8px; border-top: 1px dashed var(--line);
  font-size: 12px; color: var(--sub); }
.due-mini { font-variant-numeric: tabular-nums; font-weight: 600; }
.due-mini.overdue { color: var(--todo); }
.due-mini.today { color: var(--watch); }
.due-mini.soon { color: var(--accent); }
.due-mini.later { color: var(--sub); }
</style>
