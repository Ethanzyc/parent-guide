<script setup>
// Focus card = the DYNAMIC half of the archive card's static profile:
// current focus + live concerns (with days observed) + a mechanical roll-up
// of what's running (active strategies / nearest followup). Archive card owns
// the portrait (temperament/language/preferences); this card owns "now".
import { computed } from 'vue'
import { daysSince, dueLabel } from '../../lib/util.js'

const props = defineProps({ block: Object, kid: Object })
const focus = computed(() => (props.kid?.currentFocus || []).filter(Boolean))
const concerns = computed(() => {
  const live = (props.kid?.activeConcerns || []).filter(c => (c?.status || '观察中') !== '已解决')
  return live.map(c => ({ ...c, days: daysSince(c.since) }))
})

// mechanical roll-up: running strategies + nearest pending followup
const running = computed(() =>
  (props.kid?.strategies || []).filter(s => ['active', 'effective', 'partial'].includes(s?.status)))
const nearestFu = computed(() => {
  const list = (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending')
    .sort((a, b) => String(a.due).localeCompare(String(b.due)))
  return list[0] || null
})
const hasAny = computed(() => focus.value.length || concerns.value.length || running.value.length)
</script>

<template>
  <template v-if="hasAny">
    <h3><span class="card-ico ico-amber">🔥</span>当前重点</h3>
    <div v-if="focus.length" style="margin-bottom:10px">
      <span v-for="f in focus" :key="f" class="chip" style="font-size:13px;margin:0 6px 6px 0">{{ f }}</span>
    </div>
    <div v-if="concerns.length">
      <div v-for="(c, i) in concerns" :key="i" class="crow">
        <span style="flex:1;min-width:0">{{ c.text }}</span>
        <span class="csince">{{ c.days !== null ? `已观察 ${c.days} 天` : `自 ${c.since || '?'}` }}</span>
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
  <template v-else>
    <h3><span class="card-ico ico-amber">🔥</span>当前重点</h3>
    <div class="empty" style="margin-top:8px">
      <span class="e-ico">💬</span>
      <span class="e-txt">还没有记录当前关注——回到对话聊聊最近头疼什么,认领后显示在这里。</span>
    </div>
  </template>
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
