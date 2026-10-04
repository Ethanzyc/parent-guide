<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const focus = computed(() => (props.kid?.currentFocus || []).filter(Boolean))
const concerns = computed(() =>
  (props.kid?.activeConcerns || []).filter(c => (c?.status || '观察中') !== '已解决'))
const hasAny = computed(() => focus.value.length || concerns.value.length)
</script>

<template>
  <template v-if="hasAny">
    <h3>🔥 当前重点<span class="tag">{{ block.type }}</span></h3>
    <div v-if="focus.length" style="margin-bottom:10px">
      <span v-for="f in focus" :key="f" class="chip" style="font-size:13px;margin:0 6px 6px 0">{{ f }}</span>
    </div>
    <div v-if="concerns.length">
      <div v-for="(c, i) in concerns" :key="i" class="frow">
        <span class="d">👀</span>
        <span style="flex:1">{{ c.text }}</span>
        <span style="color:var(--sub);font-size:12px">自 {{ c.since }}</span>
      </div>
    </div>
  </template>
  <template v-else>
    <h3>🔥 当前重点<span class="tag">{{ block.type }}</span></h3>
    <div class="src">还没有记录当前关注——回到对话聊聊最近头疼什么,认领后显示在这里。</div>
  </template>
</template>
