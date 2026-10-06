<script setup>
import { computed } from 'vue'
import { monthsAge, nearestMilestone } from '../../lib/util.js'

const props = defineProps({ block: Object, kid: Object })
const stLabel = { ok: '已会', watch: '观察', todo: '尚未' }

const pack = computed(() => {
  const m = props.block?.props?.months || nearestMilestone(monthsAge(props.kid?.birthdate))
  return { m, data: props.kid?.milestones?.[m] || null }
})
const counts = computed(() => {
  const items = pack.value.data?.items || []
  const c = { ok: 0, watch: 0, todo: 0 }
  for (const i of items) if (c[i.status] !== undefined) c[i.status]++
  return c
})
const assessed = computed(() => pack.value.data?.assessed || '')
</script>

<template>
  <template v-if="pack.data">
    <h3>里程碑 · {{ pack.m }} 月</h3>
    <div class="mnums num-serif">
      <span class="mn"><i style="color:var(--ok)">{{ counts.ok }}</i><small>已会</small></span>
      <span class="mn"><i style="color:var(--watch)">{{ counts.watch }}</i><small>观察</small></span>
      <span class="mn"><i style="color:var(--todo)">{{ counts.todo }}</i><small>尚未</small></span>
    </div>
    <div v-for="(i, idx) in (pack.data.items || [])" :key="idx" class="mrow">
      <span class="st" :class="i.status">{{ stLabel[i.status] || i.status }}</span>
      <span style="color:var(--sub);flex:none;width:5.5em">{{ i.domain }}</span>
      <span>{{ i.text }}</span>
    </div>
    <div class="src">来源:{{ pack.data.source }}<template v-if="assessed"> · 盘于 {{ assessed }}</template></div>
  </template>
  <template v-else>
    <h3>里程碑 · {{ pack.m }} 月</h3>
    <div class="src">还没盘过这个月龄。回到对话说「做个发育盘点」,几分钟判定完会显示在这里。</div>
  </template>
</template>

<style scoped>
.mnums { display: flex; gap: 16px; margin-bottom: 10px; }
.mn { text-align: center; }
.mn i { display: block; font-style: normal; font-size: 27px; font-weight: 700; line-height: 1.15; }
.mn small { font-size: 10.5px; color: var(--sub); letter-spacing: .06em; }
</style>
