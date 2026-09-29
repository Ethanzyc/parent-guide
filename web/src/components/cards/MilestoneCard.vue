<script setup>
import { computed } from 'vue'
import { monthsAge, nearestMilestone } from '../../lib/util.js'

const props = defineProps({ block: Object, kid: Object })
const stLabel = { ok: '已会', watch: '观察', todo: '尚未' }

const pack = computed(() => {
  const m = props.block?.props?.months || nearestMilestone(monthsAge(props.kid?.birthdate))
  return { m, data: props.kid?.milestones?.[m] || null }
})
</script>

<template>
  <template v-if="pack.data">
    <h3>🎯 {{ pack.m }} 个月里程碑<span class="tag">{{ block.type }}</span></h3>
    <div v-for="(i, idx) in (pack.data.items || [])" :key="idx" class="mrow">
      <span class="st" :class="i.status">{{ stLabel[i.status] || i.status }}</span>
      <span style="color:var(--sub);flex:none;width:5.5em">{{ i.domain }}</span>
      <span>{{ i.text }}</span>
    </div>
    <div class="src">来源:{{ pack.data.source }}</div>
  </template>
  <template v-else>
    <h3>📦 卡片</h3>
    <div class="src">数据缺失:月龄 {{ pack.m }} 的里程碑数据</div>
  </template>
</template>
