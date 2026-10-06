<script setup>
import { computed } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const title = computed(() => props.block?.props?.title || '便签')
const text = computed(() => (props.block?.props?.text || '').trim())
</script>

<template>
  <template v-if="text">
    <h3><span class="card-ico ico-amber">📝</span>{{ title }}</h3>
    <p class="text-body">{{ text }}</p>
  </template>
  <template v-else>
    <h3><span class="card-ico ico-amber">📝</span>{{ title }}</h3>
    <div class="empty" style="margin-top:8px">
      <span class="e-ico">✏️</span>
      <span class="e-txt">内容为空——回到对话对 AI 说「把{{ title }}的内容写成…」即可填入。</span>
    </div>
  </template>
</template>

<style scoped>
.text-body { white-space: pre-wrap; font-size: 14px; color: #5b564d; margin: 0;
  line-height: 1.7; max-height: 420px; overflow-y: auto; }
</style>
