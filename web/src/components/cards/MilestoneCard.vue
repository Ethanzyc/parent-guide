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
const total = computed(() => counts.value.ok + counts.value.watch + counts.value.todo || 1)
const assessed = computed(() => pack.value.data?.assessed || '')
</script>

<template>
  <template v-if="pack.data">
    <h3><span class="card-ico ico-green">🎯</span>{{ pack.m }} 个月里程碑
      <span class="mstack" :title="`已会 ${counts.ok} / 观察 ${counts.watch} / 尚未 ${counts.todo}`">
        <i class="ok" :style="{ width: (counts.ok / total * 100) + '%' }"></i>
        <i class="watch" :style="{ width: (counts.watch / total * 100) + '%' }"></i>
        <i class="todo" :style="{ width: (counts.todo / total * 100) + '%' }"></i>
      </span>
      <span class="mstack-nums"><b class="ok">{{ counts.ok }}</b>/<b class="watch">{{ counts.watch }}</b>/<b class="todo">{{ counts.todo }}</b></span>
    </h3>
    <div v-for="(i, idx) in (pack.data.items || [])" :key="idx" class="mrow">
      <span class="st" :class="i.status">{{ stLabel[i.status] || i.status }}</span>
      <span style="color:var(--sub);flex:none;width:5.5em">{{ i.domain }}</span>
      <span>{{ i.text }}</span>
    </div>
    <div class="src">来源:{{ pack.data.source }}<template v-if="assessed"> · 盘于 {{ assessed }}</template></div>
  </template>
  <template v-else>
    <h3><span class="card-ico ico-green">🎯</span>{{ pack.m }} 个月里程碑</h3>
    <div class="empty" style="margin-top:8px">
      <span class="e-ico">🌱</span>
      <span class="e-txt">还没盘过这个月龄。回到对话说「做个发育盘点」,几分钟判定完会显示在这里。</span>
    </div>
  </template>
</template>
