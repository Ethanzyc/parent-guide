<script setup>
// page.json editor drawer = the channel where the user's AI edits config.
// Apply is validate-first: JSON must parse and contain a blocks array.
import { ref, watch } from 'vue'

const props = defineProps({ open: Boolean, page: Object })
const emit = defineEmits(['close', 'apply'])

const text = ref('')
const hint = ref('')

watch(() => props.open, v => {
  if (v) {
    text.value = JSON.stringify(props.page, null, 2)
    hint.value = ''
  }
})

function apply() {
  try {
    const next = JSON.parse(text.value)
    if (!next || !Array.isArray(next.blocks)) throw new Error('缺少 blocks 数组')
    emit('apply', next)
  } catch (e) {
    hint.value = '配置无效,未应用:' + e.message
  }
}
</script>

<template>
  <div class="drawer-mask" :class="{ open }" @click.self="emit('close')">
    <div class="drawer">
      <header>
        <b>page.json(积木配置)</b>
        <span style="font-size:12px;color:var(--sub)">改完点应用,卡片立即重排</span>
      </header>
      <textarea v-model="text" spellcheck="false"></textarea>
      <footer>
        <span class="hint">{{ hint }}</span>
        <button class="btn" @click="emit('close')">取消</button>
        <button class="btn primary" @click="apply">应用</button>
      </footer>
    </div>
  </div>
</template>
