<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() => (props.kid?.notes || []).slice(0, props.block?.props?.limit || 5))
</script>

<template>
  <template v-if="list.length">
    <h3>✨ 成长速记<span class="tag">{{ block.type }}</span></h3>
    <div v-for="(n, i) in list" :key="i" class="note-item">
      <span class="d">{{ n.precision && n.precision !== 'day' ? '≈' : '' }}{{ n.date }}</span>
      <span v-if="(n.tags || []).length" class="note-tags">
        <span v-for="t in n.tags" :key="t" class="ntag">{{ t }}</span>
      </span>
      {{ n.text }}
    </div>
  </template>
  <template v-else>
    <h3>📦 卡片</h3>
    <div class="src">数据缺失:成长速记</div>
  </template>
</template>

<style scoped>
.note-tags { margin-right: 6px; }
.ntag { display: inline-block; background: var(--accent-soft); color: var(--accent);
  border-radius: 6px; padding: 0 6px; font-size: 11px; margin-right: 3px; }
</style>
