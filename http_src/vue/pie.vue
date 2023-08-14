<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div>
    <Chart
        :id="id"
        :chart_type="chart_type"
        :base_url_request="params_url"
        :register_on_status_change="false"
        @chart_reloaded="chart_done">
    </Chart>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";
import { default as Chart } from "./chart.vue";

const _i18n = (t) => i18n(t);

const chart_type = ref(ntopChartApex.typeChart.DONUT);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: Number,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
});

const params_url = computed(() => {
  const url_params = {
     ifid: props.ifid,
     epoch_begin: props.epoch_begin,
     epoch_end: props.epoch_end,
     ...props.params.url_params
  }
  let query_params = ntopng_url_manager.obj_to_url_params(url_params);

  /* Push ifid to the parameters (e.g. "ts_query=ifid:$IFID$" */
  query_params = query_params.replaceAll("%24IFID%24" /* $IFID$ */, props.ifid);

  return `${http_prefix}${props.params.url}?${query_params}`;
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end], (cur_value, old_value) => {
    refresh_chart();
}, { flush: 'pre'});

onBeforeMount(() => {
    init();
});

onMounted(() => {
});

function init() {
    refresh_chart();
}

async function refresh_chart() {
    //TODO 
}

function chart_done(data, tmp, tmp2) {
}
</script>

<style>

</style>
