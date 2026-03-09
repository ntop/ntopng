<!--
  (C) 2013-26 - ntop.org
-->
<template>
    <PieChartSingle ref="chart" :chart="chart_config" />
  </template>
  
  <script setup>
  import { ref, computed, watch } from "vue";
  import PieChartSingle from "./charts/pie-chart.vue";
  
  const chart = ref(null);
  
  const props = defineProps({
    id:                 String,
    i18n_title:         String,
    ifid:               String,
    epoch_begin:        Number,
    epoch_end:          Number,
    max_width:          Number,
    max_height:         Number,
    params:             Object,
    get_component_data: Function,
    filters:            Object,
  });
  
  const get_url_params = () => {
    const raw = {
      ifid:        props.ifid,
      epoch_begin: props.epoch_begin,
      epoch_end:   props.epoch_end,
      ...props.params.url_params,
      ...props.filters,
    };
    return Object.fromEntries(Object.entries(raw).filter(([_, v]) => v != null));
  };
  
  // Override the fetch function so the dashboard loading lifecycle works
  const custom_fetch = async (url, url_params) => {
    // Return raw response, pie-chart.vue will unwrap result
    return await props.get_component_data(url, url_params, undefined, props.epoch_begin);
    };
  
  const chart_config = computed(() => ({
    name:       props.id,
    update_url: `${http_prefix}${props.params.url}`,
    url_params: get_url_params(),
    custom_fetch,
  }));
  
  watch(() => [props.epoch_begin, props.epoch_end, props.filters], () => {
    chart.value?.update();
  }, { flush: 'pre', deep: true });
  </script>