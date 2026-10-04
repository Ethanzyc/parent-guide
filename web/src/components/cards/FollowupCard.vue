<script setup>
import { computed } from 'vue'
import { dueLabel } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
// 只显示未完成的回访(留档的历史项不上卡)
const list = computed(() => (props.kid?.followups || []).filter(f => (f.status || 'pending') === 'pending'))
const dl = (due) => dueLabel(due)
</script>

<template>
  <h3>🔔 待回访</h3>
  <template v-if="list.length">
    <div v-for="(f, i) in list" :key="i" class="frow">
      <span class="due-b" :class="dl(f.due).urgency || 'plain'">{{ dl(f.due).label || f.due }}</span>
      <span class="topic">{{ f.topic }}</span>
    </div>
  </template>
  <div v-else class="src">暂无待回访项 🎉</div>
</template>

<style scoped>
.topic { flex: 1; min-width: 0; font-size: 13.5px; }
</style>
