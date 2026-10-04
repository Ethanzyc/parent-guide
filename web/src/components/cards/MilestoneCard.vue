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
    <h3>🎯 {{ pack.m }} 个月里程碑
      <span class="head-stats">
        <span class="ok"><b>{{ counts.ok }}</b> 已会</span>
        <span class="watch"><b>{{ counts.watch }}</b> 观察</span>
        <span class="todo"><b>{{ counts.todo }}</b> 尚未</span>
      </span>
    </h3>
    <div v-for="(i, idx) in (pack.data.items || [])" :key="idx" class="mrow">
      <span class="st" :class="i.status">{{ stLabel[i.status] || i.status }}</span>
      <span style="color:var(--sub);flex:none;width:5.5em">{{ i.domain }}</span>
      <span>{{ i.text }}</span>
    </div>
    <div class="src">来源:{{ pack.data.source }}<template v-if="assessed"> · 盘于 {{ assessed }}</template></div>
  </template>
  <template v-else>
    <h3>🎯 {{ pack.m }} 个月里程碑</h3>
    <div class="src">还没盘过这个月龄。回到对话说「做个发育盘点」,几分钟判定完会显示在这里。</div>
  </template>
</template>
