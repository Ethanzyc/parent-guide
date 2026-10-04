<script setup>
// page.json editor drawer = the channel where the user's AI edits config.
// Apply is validate-first: JSON must parse, contain a blocks array, and carry
// unique ids (duplicates silently corrupt geometry write-back). Unknown types
// only warn -- fail-soft rendering stays, and future official types must not
// be rejected by an older validator.
import { ref, watch } from 'vue'
import { CARD_META } from './cards/index.js'

const props = defineProps({ open: Boolean, page: Object })
const emit = defineEmits(['close', 'apply'])

const text = ref('')
const hint = ref('')
const warn = ref('')

watch(() => props.open, v => {
  if (v) {
    text.value = JSON.stringify(props.page, null, 2)
    hint.value = ''
    warn.value = ''
  }
})

function apply() {
  try {
    const next = JSON.parse(text.value)
    if (!next || !Array.isArray(next.blocks)) throw new Error('缺少 blocks 数组')
    const ids = next.blocks.filter(b => b && typeof b === 'object').map(b => b.id)
    const dup = [...new Set(ids.filter((i, idx) => ids.indexOf(i) !== idx))]
    if (dup.length) throw new Error(`id 重复: ${dup.join(', ')}`)
    const unknown = [...new Set(next.blocks.filter(b => b?.type && !CARD_META[b.type]).map(b => b.type))]
    warn.value = unknown.length ? `警告:type ${unknown.join(', ')} 不在白名单,会渲染为占位卡` : ''
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
        <span class="hint">{{ hint }}<template v-if="warn && !hint"><br>{{ warn }}</template></span>
        <button class="btn" @click="emit('close')">取消</button>
        <button class="btn primary" @click="apply">应用</button>
      </footer>
    </div>
  </div>
</template>
