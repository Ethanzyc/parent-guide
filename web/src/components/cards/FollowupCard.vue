<script setup>
import { computed } from 'vue'
import { dueLabel } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
// 只显示未完成的回访(done/skipped 留档作历史);按 due 排序,最近该管的在最上
const list = computed(() =>
  (props.kid?.followups || [])
    .filter(f => (f.status || 'pending') === 'pending')
    .sort((a, b) => String(a.due).localeCompare(String(b.due))))
const dl = (due) => dueLabel(due)
// 「主题:细节」拆两级(冒号前是家长扫读用的主题词);无冒号则整体为主
function splitTopic(t) {
  const m = String(t || '').split(/[:：]/)
  return m.length > 1 ? { lead: m[0], rest: m.slice(1).join(':').trim() } : { lead: t, rest: '' }
}
</script>

<template>
  <h3><span class="card-ico ico-clay">🔔</span>待回访</h3>
  <template v-if="list.length">
    <div v-for="(f, i) in list" :key="i" class="frow">
      <span class="due-b" :class="dl(f.due).urgency || 'plain'">{{ dl(f.due).label || f.due }}</span>
      <span class="dorig">{{ f.due }}</span>
      <span class="topic"><b>{{ splitTopic(f.topic).lead }}</b><template v-if="splitTopic(f.topic).rest">:{{ splitTopic(f.topic).rest }}</template></span>
    </div>
  </template>
  <div v-else class="empty" style="margin-top:8px">
    <span class="e-ico">🎉</span>
    <span class="e-txt">暂无待回访项,在跑的计划都稳定着。</span>
  </div>
</template>

<style scoped>
.frow { align-items: flex-start; }
.dorig { flex: none; font-size: 11.5px; color: var(--sub);
  font-variant-numeric: tabular-nums; margin-top: 2px; }
.topic { flex: 1; min-width: 0; font-size: 13.5px; }
.topic b { font-weight: 600; }
</style>
