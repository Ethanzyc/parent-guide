<script setup>
// Card manager drawer: visibility switches, not creation forms.
//   - Every existing block (builtin or custom) gets an on/off switch
//     (off -> hidden:true, geometry preserved; on -> restored in place).
//   - Builtin types not yet on the page can be turned on (default geometry).
//   - Custom cards are created ONLY through the chat (AI reads blocks-spec);
//     the panel just points there.
import { computed } from 'vue'
import { CARD_META } from './cards/index.js'

const props = defineProps({ open: Boolean, page: Object })
const emit = defineEmits(['close', 'toggle', 'show'])

const blocks = computed(() => (props.page?.blocks || []))
const shown = computed(() => blocks.value.filter(b => !b.hidden))
const hiddenBlocks = computed(() => blocks.value.filter(b => b.hidden))

function labelOf(b) {
  const meta = CARD_META[b.type]
  if (b.type === 'text' || b.type === 'list') return b.props?.title || meta?.name || b.type
  const extra = b.props?.tag ? `· ${b.props.tag}` : b.props?.months ? `· ${b.props.months}月` : ''
  return (meta?.name || b.type) + (extra ? ` ${extra}` : '')
}

// builtin types with no block on the page (shown or hidden) -> can be turned on
const absentTypes = computed(() =>
  Object.entries(CARD_META).filter(([type, m]) =>
    m.group === 'builtin' && !blocks.value.some(b => b.type === type)))
</script>

<template>
  <div class="drawer-mask" :class="{ open }" @click.self="emit('close')">
    <div class="drawer add-panel">
      <header>
        <b>☰ 卡片管理</b>
        <span style="font-size:12px;color:var(--sub)">开关只控制显示;内容与布局另有去处</span>
      </header>

      <div class="grp">页面上的卡片</div>
      <label v-for="b in shown" :key="b.id" class="row">
        <span class="nm">{{ labelOf(b) }}</span>
        <span class="tag">{{ CARD_META[b.type]?.group === 'custom' ? '自定义' : '功能' }}</span>
        <input type="checkbox" checked @change="emit('toggle', { id: b.id, on: false })">
      </label>

      <template v-if="hiddenBlocks.length">
        <div class="grp">已隐藏(关闭后保留原位置)</div>
        <label v-for="b in hiddenBlocks" :key="b.id" class="row dim">
          <span class="nm">{{ labelOf(b) }}</span>
          <input type="checkbox" @change="emit('toggle', { id: b.id, on: true })">
        </label>
      </template>

      <template v-if="absentTypes.length">
        <div class="grp">还没上页的功能卡</div>
        <div class="absent">
          <button v-for="[type, m] in absentTypes" :key="type" class="pick" @click="emit('show', type)">
            <b>{{ m.name }}</b><span>{{ m.desc }}</span>
          </button>
        </div>
      </template>

      <div class="hint-box">
        想加<b>自定义卡</b>(便签/清单)或改卡片内容?<b>回到对话跟 AI 说</b>,比如
        「帮我加一张出门清单卡」「把奶奶须知卡的内容改成…」——AI 会按页面规范直接改配置。
      </div>

      <footer>
        <span class="hint"></span>
        <button class="btn" @click="emit('close')">关闭</button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.grp { font-size: 12px; color: var(--sub); margin: 12px 0 6px; }
.row { display: flex; align-items: center; gap: 10px; padding: 8px 10px;
  border: 1px solid var(--line); border-radius: 10px; margin-bottom: 6px;
  font-size: 14px; cursor: pointer; }
.row.dim { background: #faf8f4; }
.row .nm { flex: 1; }
.row .tag { font-size: 11px; color: var(--sub); border: 1px solid var(--line);
  border-radius: 99px; padding: 1px 8px; }
.row input { accent-color: var(--accent); width: 16px; height: 16px; }
.absent { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.pick { border: 1px solid var(--line); background: #fff; border-radius: 10px;
  padding: 8px 10px; text-align: left; cursor: pointer; font: inherit; }
.pick:hover { border-color: var(--accent); }
.pick b { display: block; font-size: 13px; margin-bottom: 2px; }
.pick span { font-size: 11.5px; color: var(--sub); }
.hint-box { background: var(--accent-soft); border-radius: 10px; padding: 10px 12px;
  font-size: 12.5px; color: #9c5535; margin-top: 12px; line-height: 1.6; }
@media (max-width: 640px) { .absent { grid-template-columns: 1fr; } }
</style>
