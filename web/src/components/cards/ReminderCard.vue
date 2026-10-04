<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() =>
  (props.kid?.reminders || [])
    .filter(r => (r?.status || 'pending') === 'pending')
    .sort((a, b) => String(a.due).localeCompare(String(b.due))))
</script>

<template>
  <template v-if="list.length">
    <h3>⏰ 前瞻提醒<span class="tag">{{ block.type }}</span></h3>
    <div v-for="(r, i) in list" :key="i" class="frow">
      <span class="d">{{ r.due }}</span>
      <span style="flex:1">{{ r.topic }}</span>
      <span style="color:var(--sub);font-size:12px">{{ r.source || '' }}</span>
    </div>
  </template>
  <template v-else>
    <h3>⏰ 前瞻提醒<span class="tag">{{ block.type }}</span></h3>
    <div class="src">暂无到期提醒——对话里说「帮我留意 XX」(疫苗/报名/季节节点)即可认领入档。</div>
  </template>
</template>
