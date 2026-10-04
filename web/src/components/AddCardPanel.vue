<script setup>
// Add/edit card drawer. Two groups from CARD_META: builtin (one click to add,
// data-bound) and custom (small form: text card / list card).
// Edit mode reuses the same custom-card form for existing text/list blocks.
import { computed, ref, watch } from 'vue'
import { CARD_META, isCustom } from './cards/index.js'

const props = defineProps({ open: Boolean, block: { type: Object, default: null } })
const emit = defineEmits(['close', 'add', 'update'])

const mode = computed(() => (props.block ? 'edit' : 'add'))
const editingCustom = computed(() => props.block && isCustom(props.block.type))

// form state for custom cards (separate refs per form so the two add-mode
// forms don't share a title by accident)
const fTitle = ref('')
const fText = ref('')
const fItems = ref('')          // one item per line; "[x] " prefix = done
const fListTitle = ref('')
const hint = ref('')

const builtinList = computed(() => Object.entries(CARD_META).filter(([, m]) => m.group === 'builtin'))
const customList = computed(() => Object.entries(CARD_META).filter(([, m]) => m.group === 'custom'))

watch(() => props.open, v => {
  if (!v) return
  hint.value = ''
  const p = props.block?.props || {}
  fTitle.value = p.title || ''
  fText.value = p.text || ''
  fItems.value = (p.items || []).map(i => (i.done ? '[x] ' : '') + i.text).join('\n')
  fListTitle.value = fTitle.value
})

function addBuiltin(type) {
  emit('add', { type })
}

function submitCustom(type) {
  if (mode.value === 'edit') {
    emit('update', { id: props.block.id, props: readForm(type) })
    return
  }
  emit('add', { type, props: readForm(type) })
}

function readForm(type) {
  if (type === 'text') {
    if (!fText.value.trim()) { hint.value = '先写点内容(空卡片没有意义)'; return null }
    return { title: fTitle.value.trim() || '便签', text: fText.value.trim() }
  }
  const items = fItems.value.split('\n').map(s => s.trim()).filter(Boolean)
    .map(s => s.startsWith('[x] ') || s.startsWith('[x]')
      ? { text: s.replace(/^\[x\]\s*/, ''), done: true }
      : { text: s, done: false })
  if (!items.length) { hint.value = '至少写一条清单项(每行一条)'; return null }
  return { title: fListTitle.value.trim() || '清单', items }
}
</script>

<template>
  <div class="drawer-mask" :class="{ open }" @click.self="emit('close')">
    <div class="drawer add-panel">
      <header>
        <b>{{ mode === 'edit' ? '✎ 编辑卡片' : '＋ 添加卡片' }}</b>
        <span style="font-size:12px;color:var(--sub)">功能卡自动读孩子档案;自定义卡内容存在本页配置</span>
      </header>

      <!-- edit mode: only custom cards are editable here -->
      <template v-if="mode === 'edit'">
        <p v-if="!editingCustom" class="src" style="padding:8px 0">
          这张是功能卡,内容由对话自动更新——想改布局请在编辑布局里拖拽。
        </p>
        <template v-else-if="block.type === 'text'">
          <label class="f">标题<input v-model="fTitle" placeholder="如:奶奶须知"></label>
          <label class="f">内容<textarea v-model="fText" rows="8" placeholder="自由文本"></textarea></label>
        </template>
        <template v-else-if="block.type === 'list'">
          <label class="f">标题<input v-model="fTitle" placeholder="如:出门清单"></label>
          <label class="f">条目(每行一条,开头 [x] = 已完成)<textarea v-model="fItems" rows="8" placeholder="水杯&#10;[x] 尿裤&#10;安抚玩偶"></textarea></label>
        </template>
      </template>

      <!-- add mode: pick from the two groups -->
      <template v-else>
        <div class="grp">功能卡(读孩子档案,空了会引导回对话)</div>
        <div class="pick-grid">
          <button v-for="[type, m] in builtinList" :key="type" class="pick" @click="addBuiltin(type)">
            <b>{{ m.name }}</b><span>{{ m.desc }}</span>
          </button>
        </div>
        <div class="grp">自定义卡(内容自己写,存在本页)</div>
        <div class="pick-grid">
          <div class="pick form">
            <b>📝 文本卡</b>
            <input v-model="fTitle" placeholder="标题(如:奶奶须知)">
            <textarea v-model="fText" rows="4" placeholder="自由文本,如用药说明/辅食黑名单"></textarea>
            <button class="btn" @click="submitCustom('text')">添加文本卡</button>
          </div>
          <div class="pick form">
            <b>✅ 清单卡</b>
            <input v-model="fListTitle" placeholder="标题(如:出门清单)">
            <textarea v-model="fItems" rows="4" placeholder="每行一条,[x] 开头=已完成&#10;水杯&#10;[x] 尿裤"></textarea>
            <button class="btn" @click="submitCustom('list')">添加清单卡</button>
          </div>
        </div>
      </template>

      <footer>
        <span class="hint">{{ hint }}</span>
        <button class="btn" @click="emit('close')">关闭</button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.grp { font-size: 12px; color: var(--sub); margin: 12px 0 6px; }
.pick-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.pick { border: 1px solid var(--line); background: #fff; border-radius: 10px;
  padding: 10px 12px; text-align: left; cursor: pointer; font: inherit; }
.pick:hover { border-color: var(--accent); }
.pick b { display: block; font-size: 13.5px; margin-bottom: 3px; }
.pick span { font-size: 12px; color: var(--sub); }
.pick.form { cursor: default; display: flex; flex-direction: column; gap: 6px; }
.pick.form input, .pick.form textarea { font: inherit; font-size: 13px; padding: 6px 8px;
  border: 1px solid var(--line); border-radius: 8px; }
.f { display: flex; flex-direction: column; gap: 4px; font-size: 12.5px;
  color: var(--sub); margin: 8px 0; }
.f input, .f textarea { font: inherit; font-size: 13.5px; padding: 7px 9px;
  border: 1px solid var(--line); border-radius: 8px; }
@media (max-width: 640px) { .pick-grid { grid-template-columns: 1fr; } }
</style>
