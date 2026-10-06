<script setup>
import { computed } from 'vue'
import { dueLabel } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() =>
  (props.kid?.reminders || [])
    .filter(r => (r?.status || 'pending') === 'pending')
    .sort((a, b) => String(a.due).localeCompare(String(b.due))))
const dl = (due) => dueLabel(due)
</script>

<template>
  <template v-if="list.length">
    <h3><span class="card-ico ico-blue">⏰</span>前瞻提醒</h3>
    <div v-for="(r, i) in list" :key="i" class="frow">
      <span class="due-b" :class="dl(r.due).urgency || 'plain'">{{ dl(r.due).label || r.due }}</span>
      <span style="flex:1;min-width:0">{{ r.topic }}</span>
    </div>
  </template>
  <template v-else>
    <h3><span class="card-ico ico-blue">⏰</span>前瞻提醒</h3>
    <div class="empty" style="margin-top:8px">
      <span class="e-ico">🗓️</span>
      <span class="e-txt">暂无到期提醒——对话里说「帮我留意 XX」(疫苗/报名/季节节点)即可认领入档。</span>
    </div>
  </template>
</template>
