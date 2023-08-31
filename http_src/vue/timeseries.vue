<!--
  (C) 2013-22 - ntop.org
-->
      <!-- :get_params_url_request="get_url_params" -->

<template>
<div>
  <TimeseriesChart
    ref="chart"
    :id="id"
    :chart_type="chart_type"
    :base_url_request="base_url"
    :get_custom_chart_options="get_chart_options"
    :register_on_status_change="false">
  </TimeseriesChart>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import { ntopng_custom_events, ntopng_events_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import metricsManager from "../utilities/metrics-manager.js";
import NtopUtils from "../utilities/ntop-utils";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import timeseriesUtils from "../utilities/timeseries-utils.js";

const height_per_row = 62.5 /* px */

const _i18n = (t) => i18n(t);

const chart_type = ref(ntopChartApex.typeChart.TS_LINE);
const chart = ref(null);
const timeseries_group = ref(null);
const group_option_mode = ref(null);
const chart_options = ref(null);
const height = ref(null);

const props = defineProps({
  id: String,          /* Component ID */
  i18n_title: String,  /* Title (i18n) */
  ifid: Number,        /* Interface ID */
  epoch_begin: Number, /* Time interval begin */
  epoch_end: Number,   /* Time interval end */
  max_width: Number,   /* Component Width (4, 8, 12) */
  max_height: Number,  /* Component Hehght (4, 8, 12)*/
  params: Object,      /* Component-specific parameters from the JSON template definition */
  get_component_data: Function, /* Callback to request data (REST) */
  csrf: String
});

/* Return the base url of the REST API */
const base_url = computed(() => {
  return `${http_prefix}${props.params.url}`;
});

/* This function is used to retrieve ts_key and ts_query from the url_params
 * and correctly format it, by substituting the $IFID$ with the correct
 * interface id.  
 */
function get_ts_info() {
  let ts_key = props.params.url_params?.tskey;
  let ts_query = props.params.url_params?.ts_query;

  /* Push ifid to the parameters (e.g. "ts_query=ifid:$IFID$" */
  if(ts_key.contains('$IFID$')) {
    ts_key = ts_key.replace('$IFID$', props.ifid);
  }
  if(ts_query.contains('$IFID$')) {
    ts_query = ts_query.replace('$IFID$', props.ifid);
  }

  return {
    tskey: ts_key,
    ts_query: ts_query
  }
}

/* Format the url_params and return the formatted params */
const get_url_params = () => {
  const ts_info = get_ts_info();
  const url_params = {
    ifid: props.ifid,
    epoch_begin: props.epoch_begin,
    epoch_end: props.epoch_end,
    ...props.params.url_params,
    ...ts_info
  }
  let query_params = ntopng_url_manager.obj_to_url_params(url_params);
  /* Push ifid to the parameters (e.g. "ts_query=ifid:$IFID$" */
  query_params = query_params.replaceAll("%24IFID%24" /* $IFID$ */, props.ifid);

  return query_params;
}

/* The source_type can be found on the json and the source_array is automatically generated
 * by using the source_type
 */
async function get_timeseries_groups_from_metric(metric_schema) {
  const status = {
    epoch_begin: props.epoch_begin,
    epoch_end: props.epoch_end,
  };
  const source_type = metricsManager.get_source_type_from_id(props.params?.source_type);
  const source_array = await metricsManager.get_default_source_array(http_prefix, source_type);
  const metric = await metricsManager.get_metric_from_schema(http_prefix, source_type, source_array, metric_schema, null, status);
  const ts_group = metricsManager.get_ts_group(source_type, source_array, metric);
  const timeseries_groups = [ts_group];
  return timeseries_groups;
}

async function retrieve_basic_info() {
  /* Return the timeseries group, info found in the json */
  if(timeseries_group.value == null) {
    const metric_schema = props.params.url_params?.ts_schema;
    timeseries_group.value = await get_timeseries_groups_from_metric(metric_schema);
  }
  /* NOTE: currently only accepted the 1_chart_x_yaxis mode */
  if(group_option_mode.value == null) {
    group_option_mode.value = timeseriesUtils.getGroupOptionMode('1_chart_x_yaxis');
  }
}

/* This function run the REST API with the data */
async function get_chart_options() {
  await retrieve_basic_info();
  const url = base_url.value;
  const url_params = get_url_params();
  /* Have to be used this get_component_data, in order to create report too */
  let result = await props.get_component_data(url, url_params);
  /* Format the result in the format needed by Dygraph */
  result = timeseriesUtils.tsArrayToOptionsArray(result, timeseries_group.value, group_option_mode.value, '');
  if(result[0]) {
    result[0].height = height.value;
  }
  return result?.[0];
}

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end], (cur_value, old_value) => {
  refresh_chart();
}, { flush: 'pre'});

/* Run the init here */
onBeforeMount(async() => {
  await init();
});

onMounted(() => {});

/* Defining the needed info by the get_chart_options function */
async function init() {
  height.value = (props.height || 4) * height_per_row;
}

/* Refresh function */
async function refresh_chart() {
  if(chart.value) {
    const result = await get_chart_options();
    chart.value.update_chart_series(result.data);
  }
}
</script>

