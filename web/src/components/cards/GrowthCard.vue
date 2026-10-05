<script setup>
// Growth chart card: records vs WS/T 423-2022 P3-P97 reference bands.
// Data: knowledge/growth.md (human) == lib/growth-ref.js (machine) -- keep in sync.
// Honest-display rules: no gender -> no band (points only); screening not
// diagnosis (T2 wording on out-of-band, guide to 儿保, never "abnormal").
import { computed } from 'vue'
import { monthsAge } from '../../lib/util.js'
import { GROWTH_REF, refAt } from '../../lib/growth-ref.js'

const props = defineProps({ block: Object, kid: Object })

const records = computed(() => {
  const recs = (props.kid?.growth?.records || []).slice()
  // months come from add-growth; compute defensively for hand-added rows
  for (const r of recs) {
    if (r.months == null && props.kid?.birthdate) {
      r.months = monthsAge(props.kid.birthdate, r.date)
    }
  }
  return recs.sort((a, b) => String(a.date).localeCompare(String(b.date)))
})
const latest = computed(() => records.value[records.value.length - 1] || null)

const genderKey = computed(() => {
  const g = String(props.kid?.profile?.gender || '')
  if (g.includes('男')) return 'boys'
  if (g.includes('女')) return 'girls'
  return null
})

// band position of the latest measurement, per metric
function position(metric, v, months) {
  if (!genderKey.value) return null
  const ref = refAt(genderKey.value, metric, months)
  if (!ref) return null
  if (v < ref.p3) return { cls: 'out-low', label: '低于 P3', tip: '建议儿保评估(筛查线,非诊断)' }
  if (v > ref.p97) return { cls: 'out-high', label: '高于 P97', tip: '建议儿保评估(筛查线,非诊断)' }
  const where = v >= (ref.p3 + ref.p50) / 2 ? '区间中上段' : '区间中下段'
  return { cls: 'in', label: `P3-P97 内 · ${where}`, tip: '沿自身通道稳定生长即为正常' }
}
const hPos = computed(() => latest.value?.height ? position('height', latest.value.height, latest.value.months) : null)
const wPos = computed(() => latest.value?.weight ? position('weight', latest.value.weight, latest.value.months) : null)

// -- SVG chart ---------------------------------------------------------------
// W=300 H=96 viewBox units; band + P50 + child's polyline.
function chart(metric) {
  const recs = records.value.filter(r => r[metric] != null)
  if (recs.length < 2) return null
  const band = genderKey.value ? GROWTH_REF[genderKey.value][metric] : null
  const months = recs.map(r => r.months)
  const x0 = Math.min(0, ...months), x1 = Math.max(...months) + 2
  const vals = recs.map(r => r[metric])
  let lo = Math.min(...vals), hi = Math.max(...vals)
  if (band) {
    for (const a of band.ages) {
      if (a < x0 || a > x1) continue
      lo = Math.min(lo, band.p3[band.ages.indexOf(a)])
      hi = Math.max(hi, band.p97[band.ages.indexOf(a)])
    }
  }
  const pad = (hi - lo) * 0.08 || 1
  lo -= pad; hi += pad
  const X = (m) => 8 + (m - x0) / (x1 - x0) * 284
  const Y = (v) => 90 - (v - lo) / (hi - lo) * 82
  let bandPath = ''
  if (band) {
    const up = [], down = []
    for (const a of band.ages) {
      if (a < x0 || a > x1) continue
      up.push(`${X(a)},${Y(band.p97[band.ages.indexOf(a)])}`)
      down.push(`${X(a)},${Y(band.p3[band.ages.indexOf(a)])}`)
    }
    bandPath = 'M' + up.join(' L') + ' L' + down.reverse().join(' L') + ' Z'
  }
  const line = recs.map(r => `${X(r.months)},${Y(r[metric])}`).join(' L')
  return {
    bandPath, line,
    dots: recs.map(r => ({ x: X(r.months), y: Y(r[metric]), r: r[metric],
                           out: genderKey.value && (r[metric] < refAt(genderKey.value, metric, r.months)?.p3
                             || r[metric] > refAt(genderKey.value, metric, r.months)?.p97) })),
    x1, lastX: X(recs[recs.length - 1].months), lastY: Y(recs[recs.length - 1][metric]),
  }
}
const hChart = computed(() => chart('height'))
const wChart = computed(() => chart('weight'))
const list = computed(() => records.value.slice(-6).reverse())
</script>

<template>
  <template v-if="records.length">
    <h3>📏 生长曲线
      <span class="head-stats">
        <span>共 <b>{{ records.length }}</b> 条</span>
        <span v-if="latest">最近 {{ latest.date }}</span>
      </span>
    </h3>

    <div v-if="latest && (latest.height || latest.weight)" class="latest">
      <span class="lm">{{ latest.months }} 月龄</span>
      <span v-if="latest.height" class="lv">身高 <b>{{ latest.height }}</b> cm
        <span v-if="hPos" class="pos" :class="hPos.cls">{{ hPos.label }}</span></span>
      <span v-if="latest.weight" class="lv">体重 <b>{{ latest.weight }}</b> kg
        <span v-if="wPos" class="pos" :class="wPos.cls">{{ wPos.label }}</span></span>
    </div>

    <div v-if="hChart" class="chart">
      <div class="ct">身高 cm<span v-if="genderKey" class="cb">阴影=P3-P97 虚线=P50</span></div>
      <svg viewBox="0 0 300 96">
        <path v-if="hChart.bandPath" :d="hChart.bandPath" class="band" />
        <polyline :points="hChart.line" class="cline" />
        <circle v-for="(d, i) in hChart.dots" :key="i" :cx="d.x" :cy="d.y" r="3" :class="d.out ? 'cdot out' : 'cdot'" />
      </svg>
    </div>
    <div v-if="wChart" class="chart">
      <div class="ct">体重 kg</div>
      <svg viewBox="0 0 300 96">
        <path v-if="wChart.bandPath" :d="wChart.bandPath" class="band" />
        <polyline :points="wChart.line" class="cline" />
        <circle v-for="(d, i) in wChart.dots" :key="i" :cx="d.x" :cy="d.y" r="3" :class="d.out ? 'cdot out' : 'cdot'" />
      </svg>
    </div>
    <div v-if="!genderKey" class="src">档案未填性别,暂无参考区间对照——回对话补一下性别即可。</div>

    <div class="rlist">
      <div v-for="r in list" :key="r.date" class="rrow">
        <span class="rd">{{ r.date }}</span><span class="rm">{{ r.months }}月</span>
        <span class="rv">{{ r.height ? r.height + 'cm' : '—' }}</span>
        <span class="rv">{{ r.weight ? r.weight + 'kg' : '—' }}</span>
      </div>
    </div>
    <div class="src">区间:WS/T 423—2022(写入 knowledge/growth.md) · 筛查参照非诊断,出区间或跨百分位线建议儿保</div>
  </template>
  <template v-else>
    <h3>📏 生长曲线</h3>
    <div class="src">还没有生长记录——儿保体检本的身高体重抄回来:对话里说「记一下身高体重」,曲线和参考区间就亮了。</div>
  </template>
</template>

<style scoped>
.latest { display: flex; flex-wrap: wrap; gap: 6px 14px; align-items: baseline;
  background: var(--accent-soft); border-radius: 10px; padding: 8px 12px;
  font-size: 13px; margin-bottom: 10px; }
.latest .lm { color: var(--sub); font-size: 12px; }
.latest .lv b { font-size: 16px; }
.pos { font-size: 11.5px; border-radius: 6px; padding: 1px 8px; margin-left: 6px; }
.pos.in { background: var(--ok-bg); color: var(--ok); }
.pos.out-low { background: var(--todo-bg); color: var(--todo); }
.pos.out-high { background: var(--watch-bg); color: var(--watch); }
.chart { margin-bottom: 6px; }
.ct { font-size: 12px; color: var(--sub); margin-bottom: 2px; }
.ct .cb { float: right; font-size: 11px; }
svg { width: 100%; height: auto; display: block; }
.band { fill: var(--accent-soft); stroke: none; }
.cline { fill: none; stroke: var(--accent); stroke-width: 2; }
.cdot { fill: #fff; stroke: var(--accent); stroke-width: 2; }
.cdot.out { fill: var(--todo); stroke: var(--todo); }
.rlist { margin-top: 4px; }
.rrow { display: flex; gap: 10px; font-size: 12.5px; padding: 3px 0;
  border-bottom: 1px dashed var(--line); font-variant-numeric: tabular-nums; }
.rrow:last-child { border-bottom: none; }
.rd { color: var(--sub); flex: none; }
.rm { color: var(--sub); flex: none; width: 3.5em; }
.rv { flex: 1; }
</style>
