<script setup>
import { computed } from 'vue'
import { dateShort } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
const tag = computed(() => props.block?.props?.tag || '')
const limit = computed(() => props.block?.props?.limit || 5)
const list = computed(() => {
  const notes = props.kid?.notes || []
  const picked = tag.value ? notes.filter(n => (n.tags || []).includes(tag.value)) : notes
  return picked.slice(-limit.value).reverse()   // newest first
})
const tagName = computed(() => tag.value ? `· ${tag.value}` : '')
</script>

<template>
  <template v-if="list.length">
    <h3>🌟 事件时间线{{ tagName }}</h3>
    <div class="tl">
      <div v-for="(n, i) in list" :key="i" class="tl-item">
        <span class="d">{{ n.precision && n.precision !== 'day' ? '≈' : '' }}{{ dateShort(n.date) }}</span>
        <span v-if="!tag && (n.tags || []).length" class="note-tags">
          <span v-for="t in n.tags" :key="t" class="ntag">{{ t }}</span>
        </span>
        {{ n.text }}
      </div>
    </div>
  </template>
  <template v-else>
    <h3>🌟 事件时间线{{ tagName }}</h3>
    <div class="src">
      {{ tag ? `还没有带「${tag}」标签的事件` : '还没有记录过事件' }}——值得记的瞬间回到对话随手说一句,会积累在这里。
    </div>
  </template>
</template>

<style scoped>
.note-tags { margin-right: 6px; }
.ntag { display: inline-block; background: var(--accent-soft); color: var(--accent);
  border-radius: 6px; padding: 0 6px; font-size: 11px; margin-right: 3px; }
</style>
