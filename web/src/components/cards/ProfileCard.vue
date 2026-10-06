<script setup>
import { computed } from 'vue'
import { monthsAge } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
const age = computed(() => props.kid?.birthdate ? monthsAge(props.kid.birthdate) : null)
// 已解决留档作历史,「活跃问题」区只显示仍在观察的
const liveConcerns = computed(() =>
  (props.kid?.activeConcerns || []).filter(c => c.status !== '已解决'))
const initial = computed(() => (props.kid?.name || '宝').slice(0, 1))

// 画像字段:模板占位原文=未填,跳过不渲染(与 check 的占位感知同口径)
const P = new Set(['语言发展一句话', '气质特点一句话', '安抚物(如有)',
  '家庭管教口径、长辈观点等背景', '绘本偏好', '活动偏好', '主要照顾人与分工'])
const clean = (v) => (v && !P.has(String(v).trim())) ? String(v).trim() : ''
const prof = computed(() => props.kid?.profile || {})
const caregivers = computed(() => clean(prof.value.caregivers))
const temperament = computed(() => clean(prof.value.temperament))
const language = computed(() => clean(prof.value.language))
const comfort = computed(() => clean(prof.value.comfortObject))
const familyNotes = computed(() => clean(prof.value.familyNotes))
const books = computed(() => clean(prof.value.preferences?.books))
const activities = computed(() => clean(prof.value.preferences?.activities))
const hasPref = computed(() => !!(books.value || activities.value || comfort.value))
</script>

<template>
  <div class="eyebrow">档 案</div>
  <div class="phead">
    <div>
      <div class="pname">{{ kid.name || '未填写' }}</div>
      <div class="big"><span class="num-serif num-hero" v-if="age !== null">{{ age }}</span><span v-if="age !== null" class="num-unit">个月</span></div>
      <div class="meta">
        <template v-if="kid.birthdate">{{ kid.birthdate }} 出生</template>
        <template v-else>生日未填写</template>
        <template v-if="caregivers"> · {{ caregivers }}</template>
      </div>
    </div>
    <span class="seal">{{ initial }}</span>
  </div>

  <div v-if="(kid.currentFocus || []).length" class="psec">
    <div class="plabel">当前关注</div>
    <div><span v-for="f in kid.currentFocus" :key="f" class="chip">{{ f }}</span></div>
  </div>

  <div v-if="liveConcerns.length" class="psec">
    <div class="plabel">观察中的问题</div>
    <div v-for="(c, i) in liveConcerns" :key="i" class="concern-row">
      <span class="ctext">{{ c.text }}</span>
      <span class="csince">自 {{ c.since || '?' }}</span>
    </div>
  </div>

  <div v-if="hasPref || temperament || language" class="psec">
    <div class="plabel">孩子画像</div>
    <div v-if="temperament" class="kv"><b>气质</b><span>{{ temperament }}</span></div>
    <div v-if="language" class="kv"><b>语言</b><span>{{ language }}</span></div>
    <div v-if="hasPref" class="kv"><b>偏好</b><span>
      <span v-if="comfort" class="chip">🧸 {{ comfort }}</span>
      <span v-if="activities" class="chip">🏃 {{ activities }}</span>
      <span v-if="books" class="chip">📖 {{ books }}</span>
    </span></div>
    <div v-if="familyNotes" class="kv"><b>家庭口径</b><span class="muted">{{ familyNotes }}</span></div>
  </div>

  <div v-if="!hasPref && !temperament && !language" class="src">
    画像(气质/语言/偏好)还没填——聊到这些话题时 AI 会顺带记录,这里会慢慢丰满。
  </div>
</template>

<style scoped>
.eyebrow { font-size: 13px; color: var(--sub); font-weight: 600; letter-spacing: .22em;
  margin-bottom: 10px; }
.phead { display: flex; align-items: flex-start; gap: 12px; padding-bottom: 12px;
  border-bottom: 1px solid var(--grid-line); }
.pname { font-size: 22px; font-weight: 700; line-height: 1.25; }
.meta { font-size: 12.5px; color: var(--sub); margin-top: 2px; }
.seal { flex: none; margin-left: auto; width: 46px; height: 46px; border-radius: 8px;
  border: 1.5px solid var(--grid-line); background: rgba(255,255,255,.8);
  display: flex; align-items: center; justify-content: center;
  font-size: 20px; font-weight: 700; color: var(--ink-blue); }
.psec { margin-top: 12px; }
.plabel { font-size: 11.5px; color: var(--sub); margin-bottom: 5px; letter-spacing: .08em; }
.concern-row { display: flex; gap: 8px; align-items: baseline; font-size: 13px;
  padding: 6px 10px; border: 1px solid var(--line); border-left: 3px solid var(--watch);
  background: rgba(255,255,255,.75); border-radius: 6px; margin-bottom: 5px; }
.concern-row:last-child { margin-bottom: 0; }
.ctext { flex: 1; min-width: 0; }
.csince { flex: none; font-size: 11.5px; color: var(--sub); }
.kv { display: flex; gap: 10px; font-size: 13px; padding: 6px 0;
  border-bottom: 1px dashed var(--grid-line); align-items: baseline; }
.kv:last-child { border-bottom: none; }
.kv b { flex: none; width: 4em; color: var(--sub); font-weight: 500; font-size: 12px; }
.kv span { flex: 1; min-width: 0; line-height: 1.55; }
.kv .muted { color: var(--sub); }
</style>
