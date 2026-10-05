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
  <div class="phead">
    <span class="avatar">{{ initial }}</span>
    <div class="pmain">
      <div class="pname">{{ kid.name || '未填写' }}</div>
      <div class="page-line">
        <template v-if="kid.birthdate">{{ kid.birthdate }} 出生</template>
        <template v-else>生日未填写</template>
        <template v-if="caregivers"> · {{ caregivers }}</template>
      </div>
    </div>
    <span v-if="age !== null" class="age-badge">{{ age }} 个月</span>
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
    <div v-if="temperament" class="prow"><span class="pl">气质</span><span class="pt">{{ temperament }}</span></div>
    <div v-if="language" class="prow"><span class="pl">语言</span><span class="pt">{{ language }}</span></div>
    <div v-if="hasPref" class="prow">
      <span class="pl">偏好</span>
      <span class="pt">
        <span v-if="comfort" class="chip">🧸 {{ comfort }}</span>
        <span v-if="activities" class="chip">🏃 {{ activities }}</span>
        <span v-if="books" class="chip">📖 {{ books }}</span>
      </span>
    </div>
    <div v-if="familyNotes" class="prow"><span class="pl">家庭口径</span><span class="pt muted">{{ familyNotes }}</span></div>
  </div>

  <div v-if="!hasPref && !temperament && !language" class="src">
    画像(气质/语言/偏好)还没填——聊到这些话题时 AI 会顺带记录,这里会慢慢丰满。
  </div>
</template>

<style scoped>
.phead { display: flex; align-items: center; gap: 12px; padding: 4px 0 12px;
  border-bottom: 1px dashed var(--line); }
.avatar { flex: none; width: 48px; height: 48px; border-radius: 99px;
  background: linear-gradient(135deg, #f0a078, var(--accent)); color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: 22px; font-weight: 700; }
.pmain { min-width: 0; }
.pname { font-size: 18px; font-weight: 700; line-height: 1.3; }
.page-line { font-size: 12px; color: var(--sub); margin-top: 2px; }
.age-badge { flex: none; margin-left: auto; background: var(--accent-soft);
  color: var(--accent); border-radius: 99px; padding: 4px 12px;
  font-size: 13px; font-weight: 600; }
.psec { margin-top: 12px; }
.plabel { font-size: 11.5px; color: var(--sub); margin-bottom: 5px; }
.concern-row { display: flex; gap: 8px; align-items: baseline; font-size: 13px;
  padding: 6px 10px; border: 1px solid var(--line); border-left: 3px solid var(--watch);
  border-radius: 8px; margin-bottom: 5px; }
.concern-row:last-child { margin-bottom: 0; }
.ctext { flex: 1; min-width: 0; }
.csince { flex: none; font-size: 11.5px; color: var(--sub);
  font-variant-numeric: tabular-nums; }
.prow { display: flex; gap: 10px; padding: 5px 0; font-size: 13px;
  border-bottom: 1px dashed var(--line); align-items: baseline; }
.prow:last-child { border-bottom: none; }
.pl { flex: none; color: var(--sub); min-width: 4em; font-size: 12px; }
.pt { flex: 1; min-width: 0; line-height: 1.55; }
.pt.muted { color: #5b564d; }
.pt .chip { margin: 2px 6px 2px 0; }
</style>
