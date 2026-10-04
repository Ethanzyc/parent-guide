<script setup>
import { computed } from 'vue'
import { monthsAge } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
const age = computed(() => props.kid?.birthdate ? monthsAge(props.kid.birthdate) : null)
// 已解决留档作历史,「活跃问题」区只显示仍在观察的
const liveConcerns = computed(() =>
  (props.kid?.activeConcerns || []).filter(c => c.status !== '已解决'))
const initial = computed(() => (props.kid?.name || '宝').slice(0, 1))
</script>

<template>
  <div class="phead">
    <span class="avatar">{{ initial }}</span>
    <div class="pmain">
      <div class="pname">{{ kid.name || '未填写' }}</div>
      <div class="page-line">
        <template v-if="kid.birthdate">{{ kid.birthdate }} 出生</template>
        <template v-else>生日未填写</template>
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
</template>

<style scoped>
.phead { display: flex; align-items: center; gap: 12px; padding: 4px 0 10px;
  border-bottom: 1px dashed var(--line); }
.avatar { flex: none; width: 44px; height: 44px; border-radius: 99px;
  background: linear-gradient(135deg, #f0a078, var(--accent)); color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: 20px; font-weight: 700; }
.pmain { min-width: 0; }
.pname { font-size: 17px; font-weight: 700; line-height: 1.3; }
.page-line { font-size: 12px; color: var(--sub); margin-top: 1px; }
.age-badge { flex: none; margin-left: auto; background: var(--accent-soft);
  color: var(--accent); border-radius: 99px; padding: 4px 12px;
  font-size: 13px; font-weight: 600; }
.psec { margin-top: 10px; }
.plabel { font-size: 11.5px; color: var(--sub); margin-bottom: 5px; }
.concern-row { display: flex; gap: 8px; align-items: baseline; font-size: 13px;
  padding: 6px 10px; border: 1px solid var(--line); border-left: 3px solid var(--watch);
  border-radius: 8px; margin-bottom: 5px; }
.concern-row:last-child { margin-bottom: 0; }
.ctext { flex: 1; min-width: 0; }
.csince { flex: none; font-size: 11.5px; color: var(--sub);
  font-variant-numeric: tabular-nums; }
</style>
