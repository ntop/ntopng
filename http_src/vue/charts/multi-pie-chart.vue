<!--
  (C) 2026 - ntop.org
-->

<template>
  <div class="pie-charts-wrapper" :style="gridStyle">
    <PieChartSingle
      v-for="chart in charts"
      :key="chart.name"
      :chart="chart"
    />
  </div>
</template>

<script setup>
import { computed } from "vue";
import PieChartSingle from "./pie-chart.vue";

const props = defineProps({
  context:        { type: Object, default: undefined },
  chart:          { type: Object, default: undefined },
  charts_per_row: { type: Number, default: null },
});

const charts = computed(() => {
  if (props.context?.charts) return props.context.charts;
  if (props.chart)            return [props.chart];
  return [];
});

const gridStyle = computed(() => {
  const perRow = props.charts_per_row ?? props.context?.charts_per_row ?? charts.value.length;
  return {
    display:             "grid",
    gridTemplateColumns: `repeat(${perRow}, 1fr)`,
    gap:                 "10px",
    width:               "100%",
  };
});
</script>