<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const title = computed(() => props.block?.props?.title || '便签')
const text = computed(() => (props.block?.props?.text || '').trim())
</script>

<template>
  <template v-if="text">
    <h3>📝 {{ title }}<span class="tag">自定义</span></h3>
    <p class="text-body">{{ text }}</p>
  </template>
  <template v-else>
    <h3>📝 {{ title }}<span class="tag">自定义</span></h3>
    <div class="src">内容为空——编辑布局时点卡片右上角「✎ 编辑」填写,或让 AI 帮你写进去。</div>
  </template>
</template>

<style scoped>
.text-body { white-space: pre-wrap; font-size: 14px; color: #5b564d; margin: 0; }
</style>
