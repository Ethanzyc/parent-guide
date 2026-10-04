<script setup>
// Checkbox toggles are local-first (instant UI, no parent re-render needed --
// GridBoard snapshots are deliberately non-reactive for GridStack compat),
// then persisted upward via 'update' -> GridBoard 'props-update' -> App.
import { computed, ref, watch } from 'vue'
const props = defineProps({ block: Object, kid: Object })
const emit = defineEmits(['update'])
const title = computed(() => props.block?.props?.title || '清单')
const items = ref([...(props.block?.props?.items || [])])

watch(() => props.block?.props?.items, v => { items.value = [...(v || [])] })

function toggle(i) {
  items.value = items.value.map((it, idx) => idx === i ? { ...it, done: !it.done } : it)
  emit('update', { items: items.value.map(it => ({ text: it.text, done: !!it.done })) })
}
const doneCount = computed(() => items.value.filter(i => i.done).length)
</script>

<template>
  <template v-if="items.length">
    <h3>✅ {{ title }}<span class="tag">自定义 · {{ doneCount }}/{{ items.length }}</span></h3>
    <label v-for="(it, i) in items" :key="i" class="li" :class="{ done: it.done }">
      <input type="checkbox" :checked="it.done" @change="toggle(i)">
      <span>{{ it.text }}</span>
    </label>
  </template>
  <template v-else>
    <h3>✅ {{ title }}<span class="tag">自定义</span></h3>
    <div class="src">清单为空——编辑布局时点卡片右上角「✎ 编辑」添加条目。</div>
  </template>
</template>

<style scoped>
.li { display: flex; gap: 8px; font-size: 14px; padding: 4px 0; cursor: pointer; align-items: baseline; }
.li input { accent-color: var(--accent); }
.li.done span { color: var(--sub); text-decoration: line-through; }
</style>
