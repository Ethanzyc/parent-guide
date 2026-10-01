<script setup>
import { computed } from 'vue'
import { monthsAge } from '../../lib/util.js'
const props = defineProps({ block: Object, kid: Object })
const age = (birthdate) => monthsAge(birthdate)
// 已解决留档作历史,「活跃问题」区只显示仍在观察的
const liveConcerns = computed(() =>
  (props.kid?.activeConcerns || []).filter(c => c.status !== '已解决'))
</script>

<template>
  <h3>👶 档案<span class="tag">{{ block.type }}</span></h3>
  <div class="kv"><b>孩子</b><span>{{ kid.name || '未填写' }}</span></div>
  <div class="kv"><b>出生</b><span>{{ kid.birthdate || '未填写' }}{{ kid.birthdate ? `(${age(kid.birthdate)} 个月)` : '' }}</span></div>
  <div class="kv" style="align-items:baseline">
    <b>当前关注</b>
    <span><span v-for="f in (kid.currentFocus || [])" :key="f" class="chip">{{ f }}</span></span>
  </div>
  <template v-if="liveConcerns.length">
    <div class="kv" style="margin-top:6px"><b>活跃问题</b></div>
    <div v-for="(c, i) in liveConcerns" :key="i" class="kv">
      <b>{{ c.since || '' }} 起</b><span>{{ c.text }}({{ c.status }})</span>
    </div>
  </template>
</template>
