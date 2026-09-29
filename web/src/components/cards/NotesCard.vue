<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const list = computed(() => (props.kid?.notes || []).slice(0, props.block?.props?.limit || 5))
</script>

<template>
  <template v-if="list.length">
    <h3>✨ 成长速记<span class="tag">{{ block.type }}</span></h3>
    <div v-for="(n, i) in list" :key="i" class="note-item">
      <span class="d">{{ n.date }}</span>{{ n.text }}
    </div>
  </template>
  <template v-else>
    <h3>📦 卡片</h3>
    <div class="src">数据缺失:成长速记</div>
  </template>
</template>
