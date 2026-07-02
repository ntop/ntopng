<!--
  (C) 2026 - ntop.org

  Drop-in D3 replacement for dashboard-bar.vue (which uses ApexCharts).
  Accepts exactly the same props from the dashboard template engine.
  Renders via charts/bar-chart.vue (pure D3, no ApexCharts dependency).

  direction prop (from params.direction in the JSON template):
    "vertical"   (default) — columns pointing up
    "horizontal"            — bars pointing right

  stacked prop (from params.stacked in the JSON template):
    true / false
-->
<template>
  <BarChart :chart="chart_cfg" :hideLoading="hideLoading" />
</template>

<script setup>
import { computed, watch, ref } from "vue";
import { default as BarChart } from "./charts/bar-chart.vue";

const props = defineProps({
  id: String,
  i18n_title: String,
  ifid: String,
  epoch_begin: Number,
  epoch_end: Number,
  max_width: Number,
  max_height: Number,
  params: Object,
  get_component_data: Function,
  filters: Object,
  hideLoading: Boolean,
  showOnlyFirstLoading: Boolean,
});

/*
  Build a chart config object compatible with bar-chart.vue's `chart` prop.
  We use custom_fetch to delegate to get_component_data (the same callback
  used by dashboard-bar.vue) so that the data path is identical.
*/
const chart_cfg = computed(() => ({
  title:     null,
  update_url: `${http_prefix}${props.params?.url ?? ""}`,
  url_params: buildUrlParams(),
  direction:  props.params?.direction ?? "vertical",
  stacked:    props.params?.stacked   ?? false,
  unit:       props.params?.unit      ?? null,
  label:      props.params?.label     ?? null,
  custom_fetch: props.get_component_data ? customFetch : undefined,
}));

function buildUrlParams() {
  return {
    ifid: props.ifid,
    epoch_begin: props.epoch_begin,
    epoch_end: props.epoch_end,
    new_charts: true,
    ...(props.params?.url_params ?? {}),
    ...(props.filters ?? {}),
  };
}

async function customFetch(url, url_params) {
  return props.get_component_data(url, url_params, undefined, props.epoch_begin);
}
</script>
