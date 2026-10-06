<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() => {
  const want = props.block?.props?.status
  return (props.kid?.strategies || []).filter(s => !want || want === 'all' || s.status === want)
})
const badge = (s) => s === 'effective' ? '✓ 有效' : s === 'partial' ? '◐ 部分有效'
  : s === 'ineffective' ? '✕ 效果不佳' : s === 'absorbed' ? '✓ 已成日常'
  : s === 'suspended' ? '⏸ 已暂停' : s === 'active' ? '● 试行中' : s
</script>

<template>
  <template v-if="list.length">
    <h3>策略效果</h3>
    <div v-for="s in list" :key="s.id" class="strate">
      <div class="srow">
        <div class="name">{{ s.id }} {{ s.name }}<span class="since">自 {{ s.started }}</span></div>
        <span class="badge" :class="s.status">{{ badge(s.status) }}</span>
      </div>
      <p>{{ s.applied }}</p>
      <div v-if="s.followup || s.evidence" class="fu" :class="s.status">
        {{ s.followup }}{{ s.followup && s.evidence ? '(' : '' }}{{ s.evidence }}{{ s.followup && s.evidence ? ')' : '' }}
      </div>
    </div>
  </template>
  <template v-else>
    <h3>策略效果</h3>
    <div class="src">还没有策略记录——回到对话说「我们想开始 XX 计划」,计划落档后显示在这里。</div>
  </template>
</template>

<style scoped>
.srow { display: flex; align-items: baseline; gap: 8px; }
.srow .name { font-weight: 600; font-size: 14px; min-width: 0; }
.since { color: var(--sub); font-weight: 400; font-size: 12px; margin-left: 6px; }
.badge { flex: none; margin-left: auto; font-size: 12px; border-radius: 5px; padding: 1px 8px; }
.badge.effective, .badge.absorbed { background: var(--ok-bg); color: var(--ok); }
.badge.partial, .badge.active { background: var(--watch-bg); color: var(--watch); }
.badge.ineffective { background: var(--todo-bg); color: var(--todo); }
.badge.suspended { background: var(--accent-soft); color: var(--sub); }
.strate p { font-size: 13px; color: var(--ink); margin-top: 4px; }
.fu { font-size: 13px; margin-top: 4px; }
.fu.effective, .fu.absorbed { color: var(--ok); }
.fu.partial, .fu.active { color: var(--watch); }
.fu.ineffective, .fu.suspended { color: var(--sub); }
</style>
