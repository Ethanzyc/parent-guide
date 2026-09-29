<script setup>
const props = defineProps({ block: Object, kid: Object })
const days = () => (props.kid?.sleep?.days || [])
const pct = (h) => Math.min(100, Math.round(h / 13 * 100))
const dots = (w) => '●'.repeat(w || 0) || '—'
</script>

<template>
  <template v-if="days().length">
    <h3>😴 一周睡眠<span class="tag">{{ block.type }}</span></h3>
    <div v-for="d in days()" :key="d.date" class="bar-row">
      <span>{{ d.date }}</span>
      <span class="bar-track"><span class="bar-fill" :style="{ width: pct(d.totalHours) + '%' }"></span></span>
      <span>{{ (Number(d.totalHours) || 0).toFixed(1) }}h</span>
      <span style="color:var(--watch)">{{ dots(d.wakings) }}</span>
    </div>
    <div class="src">{{ kid.sleep?.note || '' }} · 第三列=总时长,第四列=夜醒次数</div>
  </template>
  <template v-else>
    <h3>📦 卡片</h3>
    <div class="src">数据缺失:近 7 天睡眠数据</div>
  </template>
</template>
