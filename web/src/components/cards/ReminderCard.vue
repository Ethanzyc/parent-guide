<script setup>
import { computed } from 'vue'
import { dueLabel, dueKey, fullDate } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() =>
  (props.kid?.reminders || [])
    .filter(r => (r?.status || 'pending') === 'pending')
    .sort((a, b) => dueKey(a.due).localeCompare(dueKey(b.due))))
// 时间节点本身是主信息(用户反馈:只看「已到期」不知道节点是哪天),相对天数作后缀
const dl = (due) => {
  const { label } = dueLabel(due)
  return label ? `${fullDate(due)} · ${label}` : fullDate(due)
}
</script>

<template>
  <div class="cband"><h3>前瞻提醒</h3></div>
  <div class="cbody">
    <template v-if="list.length">
      <div v-for="(r, i) in list" :key="i" class="frow">
        <span class="due-b" :class="dueLabel(r.due).urgency || 'plain'">{{ dl(r.due) }}</span>
        <span style="flex:1;min-width:0">{{ r.topic }}</span>
      </div>
    </template>
    <div v-else class="src">暂无到期提醒——对话里说「帮我留意 XX」(疫苗/报名/季节节点)即可认领入档。</div>
  </div>
</template>
