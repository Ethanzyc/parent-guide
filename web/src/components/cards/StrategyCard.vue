<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() => {
  const want = props.block?.props?.status
  return (props.kid?.strategies || []).filter(s => !want || want === 'all' || s.status === want)
})
const badge = (s) => s === 'effective' ? '✓ 有效' : s === 'partial' ? '◐ 部分有效' : s
</script>

<template>
  <template v-if="list.length">
    <h3>📈 策略效果<span class="tag">{{ block.type }}</span></h3>
    <div v-for="s in list" :key="s.id" class="strate">
      <span class="badge" :class="s.status">{{ badge(s.status) }}</span>
      <div class="name">{{ s.id }} {{ s.name }}<span style="color:var(--sub);font-weight:400;font-size:12px"> 自 {{ s.started }}</span></div>
      <p>{{ s.applied }}</p>
      <div class="fu">{{ s.followup }}({{ s.evidence }})</div>
    </div>
  </template>
  <template v-else>
    <h3>📈 策略效果<span class="tag">{{ block.type }}</span></h3>
    <div class="src">还没有策略记录——回到对话说「我们想开始 XX 计划」,计划落档后显示在这里。</div>
  </template>
</template>
