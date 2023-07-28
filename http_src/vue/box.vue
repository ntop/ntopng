<!--
  (C) 2013-22 - ntop.org
-->
<template>
    <div :class="col_width_class" class="widget-box-main-dashboard">
      <div :class="row_height_class" class="widget-box">
        <h4 class="dashboard-component-title">{{ title }}</h4>
	<slot name="box_content"></slot>
      </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
  
const props = defineProps({
  title: String,
  col_width: Number,
  row_height: Number,
});

const col_width_class = computed(() => {
    return `col-${props.col_width || 4}`;
});

const row_height_class = computed(() => {
    return `row-${props.row_height || 4}`;
});
</script>

<style scoped>
</style>
