<script setup>
defineProps({ block: Object, kid: Object })
</script>

<template>
  <h3>🔔 待回访<span class="tag">{{ block.type }}</span></h3>
  <template v-if="(kid.followups || []).length">
    <div v-for="(f, i) in kid.followups" :key="i" class="frow">
      <span class="due">{{ f.due }}</span><span>{{ f.topic }}</span>
    </div>
  </template>
  <div v-else class="src">暂无待回访项 🎉</div>
</template>
