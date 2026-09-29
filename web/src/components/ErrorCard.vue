<script setup>
defineProps({ type: [String, Object] })
</script>

<template>
  <div class="card err">
    <h3>⚠️ 无法渲染的卡片</h3>
    <div>type <code>{{ type }}</code> 不在白名单或数据结构不符,已跳过;其余卡片不受影响。</div>
  </div>
</template>
