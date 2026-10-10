<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const title = computed(() => props.block?.props?.title || '便签')
const text = computed(() => (props.block?.props?.text || '').trim())
</script>

<template>
  <div class="cband"><h3>{{ title }}</h3></div>
  <div class="cbody">
    <p v-if="text" class="text-body">{{ text }}</p>
    <div v-else class="src">内容为空——回到对话对 AI 说「把{{ title }}的内容写成…」即可填入。</div>
  </div>
</template>

<style scoped>
.text-body { white-space: pre-wrap; font-size: 14px; color: var(--ink); margin: 0;
  line-height: 1.7; max-height: 420px; overflow-y: auto; }
</style>
