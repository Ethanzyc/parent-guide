<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const days = computed(() => (props.kid?.sleep?.days || []))
const pct = (h) => Math.min(100, Math.round(h / 13 * 100))
const dots = (w) => '●'.repeat(w || 0) || '—'
const avgHours = computed(() => {
  const ds = days.value
  if (!ds.length) return null
  return (ds.reduce((s, d) => s + (Number(d.totalHours) || 0), 0) / ds.length).toFixed(1)
})
const avgWakings = computed(() => {
  const ds = days.value
  if (!ds.length) return null
  return (ds.reduce((s, d) => s + (Number(d.wakings) || 0), 0) / ds.length).toFixed(1)
})
</script>

<template>
  <template v-if="days.length">
    <h3>😴 一周睡眠
      <span class="head-stats">
        <span>日均 <b>{{ avgHours }}h</b></span>
        <span class="watch">夜醒均 <b>{{ avgWakings }}</b> 次</span>
      </span>
    </h3>
    <div v-for="d in days" :key="d.date" class="bar-row">
      <span>{{ d.date }}</span>
      <span class="bar-track"><span class="bar-fill" :style="{ width: pct(d.totalHours) + '%' }"></span></span>
      <span style="text-align:right">{{ (Number(d.totalHours) || 0).toFixed(1) }}h</span>
      <span :title="`${d.wakings} 次夜醒`" style="color:var(--watch)">🌙{{ dots(d.wakings) }}</span>
    </div>
    <div v-if="kid.sleep?.note" class="src">{{ kid.sleep.note }}</div>
  </template>
  <template v-else>
    <h3>😴 一周睡眠</h3>
    <div class="src">逐日睡眠默认不记(策略回访以对话与事件记录为准);这张卡可在「卡片管理」里关闭。</div>
  </template>
</template>
