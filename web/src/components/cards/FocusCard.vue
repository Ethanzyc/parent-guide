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
    <h3>🔥 当前重点</h3>
    <div v-if="focus.length" style="margin-bottom:10px">
      <span v-for="f in focus" :key="f" class="chip" style="font-size:13px;margin:0 6px 6px 0">{{ f }}</span>
    </div>
    <div v-if="concerns.length">
      <div v-for="(c, i) in concerns" :key="i" class="crow">
        <span style="flex:1;min-width:0">{{ c.text }}</span>
        <span class="csince">自 {{ c.since || '?' }}</span>
      </div>
    </div>
  </template>
  <template v-else>
    <h3>🔥 当前重点</h3>
    <div class="src">还没有记录当前关注——回到对话聊聊最近头疼什么,认领后显示在这里。</div>
  </template>
</template>

<style scoped>
.crow { display: flex; gap: 8px; align-items: baseline; font-size: 13.5px;
  padding: 6px 10px; border: 1px solid var(--line); border-left: 3px solid var(--watch);
  border-radius: 8px; margin-bottom: 5px; }
.crow:last-child { margin-bottom: 0; }
.csince { flex: none; font-size: 11.5px; color: var(--sub);
  font-variant-numeric: tabular-nums; }
</style>
