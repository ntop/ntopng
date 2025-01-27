<!--
  (C) 2013-22 - ntop.org
-->
      <!-- :get_params_url_request="get_url_params" -->

<template>
  <div>
    <TimeseriesChart ref="chart" :id="id" :chart_type="chart_type" :base_url_request="base_url"
      :get_custom_chart_options="get_chart_options" :register_on_status_change="false" :disable_pointer_events="false">
    </TimeseriesChart>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import metricsManager from "../utilities/metrics-manager.js";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import timeseriesUtils from "../utilities/timeseries-utils.js";

/* *************************************************** */

const height_per_row = 62.5 /* px */
const chart_type = ref(ntopChartApex.typeChart.TS_LINE);
const chart = ref(null);
const timeseries_groups = ref([]);
const group_option_mode = timeseriesUtils.getGroupOptionMode('1_chart_x_yaxis');
const height = ref(null);
const ts_request = ref([]);

/* *************************************************** */

const props = defineProps({
  id: String,          /* Component ID */
  i18n_title: String,  /* Title (i18n) */
  ifid: String,        /* Interface ID */
  epoch_begin: Number, /* Time interval begin */
  epoch_end: Number,   /* Time interval end */
  max_width: Number,   /* Component Width (4, 8, 12) */
  max_height: Number,  /* Component Hehght (4, 8, 12)*/
  params: Object,      /* Component-specific parameters from the JSON template definition */
  get_component_data: Function, /* Callback to request data (REST) */
  csrf: String,
  filters: Object,
});

/* *************************************************** */

/* Return the base url of the REST API */
const base_url = computed(() => {
  return `${http_prefix}${props.params.url}`;
});

/* *************************************************** */

function substitute_ifid(params_to_format, current_ifid) {
  let new_formatted_params = {};
  for (const param in (params_to_format)) {
    if (params_to_format[param].contains('$IFID$')) {
      /* Contains $IFID$, substitute with the interface id */
      new_formatted_params[param] = params_to_format[param].replace('$IFID$', current_ifid);
    } else {
      /* does NOT Contains $IFID$, add the plain param */
      new_formatted_params[param] = params_to_format[param];
    }
  }

  return new_formatted_params;
}

/* *************************************************** */

function substitute_exporter(params_to_format, current_exporter) {
  let new_formatted_params = {};
  for (const param in (params_to_format)) {
    if (params_to_format[param].contains('$EXPORTER$')) {
      /* Contains $EXPORTER$, substitute with the interface id */
      new_formatted_params[param] = params_to_format[param].replace('$EXPORTER$', current_exporter);
    } else {
      /* does NOT Contains $EXPORTER$, add the plain param */
      new_formatted_params[param] = params_to_format[param];
    }
  }

  return new_formatted_params;
}

/* *************************************************** */

function substitute_network(params_to_format, current_network) {
  let new_formatted_params = {};
  for (const param in (params_to_format)) {
    if (params_to_format[param].contains('$NETWORK$')) {
      /* Contains $NETWORK$, substitute with the interface id */
      new_formatted_params[param] = params_to_format[param].replace('$NETWORK$', current_network);
    } else {
      /* does NOT Contains $NETWORK$, add the plain param */
      new_formatted_params[param] = params_to_format[param];
    }
  }

  return new_formatted_params;
}

/* *************************************************** */

/* This function is used to substitute to the $IFID$ found in the
 * configuration the correct interface id
 */
async function format_ifids(params_to_format) {
  if (ts_request.value.length > 0) {
    /* Already populated, return */
    return;
  }
  const ifid_url = "lua/rest/v2/get/ntopng/interfaces.lua"
  const ifid_list = await ntopng_utility.http_request(`${http_prefix}/${ifid_url}`) || [];
  ifid_list.forEach((iface) => {
    let new_formatted_params = substitute_ifid(params_to_format, iface.ifid);
    new_formatted_params.source_def = [iface.ifid]
    ts_request.value.push(new_formatted_params);
  });
}

/* *************************************************** */

/* This function is used to substitute to the $EXPORTER$ found in the
 * configuration the correct flow exporter
 */
async function format_exporters(params_to_format) {
  if (ts_request.value.length > 0) {
    /* Already populated, return */
    return;
  }
  const exporters_url = "lua/pro/rest/v2/get/flowdevices/stats.lua"
  const exporters_list = await ntopng_utility.http_request(`${http_prefix}/${exporters_url}?ifid=${props.ifid}&gui=true`) || [];
  if (exporters_list) {
    exporters_list.forEach((exporter) => {
      if (exporter) {
        let new_formatted_params = substitute_exporter(params_to_format, exporter.probe_ip);
        new_formatted_params = substitute_ifid(new_formatted_params, exporter.ifid);
        new_formatted_params.source_def = [exporter.ifid, exporter.probe_ip]
        ts_request.value.push(new_formatted_params);
      }
    });
  }
}

/* *************************************************** */

/* This function is used to substitute to the $NETWORK$ found in the
 * configuration in the correct networks
 */
async function format_networks(params_to_format) {
  if (ts_request.value.length > 0) {
    /* Already populated, return */
    return;
  }
  const networks_url = "lua/rest/v2/get/network/networks.lua"
  const networks_list = await ntopng_utility.http_request(`${http_prefix}/${networks_url}?ifid=${props.ifid}`) || [];
  if (networks_list) {
    networks_list.forEach((network) => {
      if (network) {
        let new_formatted_params = substitute_network(params_to_format, network.id);
        new_formatted_params = substitute_ifid(new_formatted_params, props.ifid);
        new_formatted_params.source_def = [props.ifid, network.id];
        ts_request.value.push(new_formatted_params);
      }
    });
  }
}

/* *************************************************** */

/* This function is used to transform the $ANY$ params in the 
 * correct value (e.g. $ANY_IFID$ -> list of all ifid)
 */
async function resolve_any_params() {
  /* Clear the Array */
  ts_request.value = [];
  /* Here possible ANY, can be found in the post_params */
  const params = props.params.post_params?.ts_requests;
  for (const any_param in (params || {})) {
    switch (any_param) {
      case '$ANY_IFID$':
        await format_ifids(params[any_param]);
        break;
      case '$ANY_EXPORTER$':
        await format_exporters(params[any_param]);
        break;
      case '$ANY_NETWORK$':
        await format_networks(params[any_param]);
        break;
      default:
        let new_formatted_params = substitute_ifid(params[any_param], props.ifid);
        new_formatted_params.source_def = [props.ifid];
        ts_request.value.push(new_formatted_params);
        break;
    }
  }
}

/* *************************************************** */

/* The source_type can be found on the json and the source_array is automatically generated
 * by using the source_type
 */
async function get_timeseries_groups_from_metric(metric_schema, source_def) {
  const status = {
    epoch_begin: props.epoch_begin,
    epoch_end: props.epoch_end,
  };
  const source_type = metricsManager.get_source_type_from_id(props.params?.source_type);
  const source_array = await metricsManager.get_source_array_from_value_array(http_prefix, source_type, source_def);
  const metric = await metricsManager.get_metric_from_schema(http_prefix, source_type, source_array, metric_schema, null, status);
  const ts_group = metricsManager.get_ts_group(source_type, source_array, metric, { past: false });
  return ts_group;
}

/* *************************************************** */

async function retrieve_basic_info() {
  /* Return the timeseries group, info found in the json */
  if (timeseries_groups.value.length == 0) {
    for (const value of ts_request.value) {
      const metric_schema = value?.ts_schema;
      const source_def = value.source_def;
      delete value.source_def /* Remove the property otherwise it's going to be added to the REST */
      const group = await get_timeseries_groups_from_metric(metric_schema, source_def);
      timeseries_groups.value.push(group);
    }
  }
}

/* *************************************************** */

/* Remove the property otherwise it's going to be added to the REST */
function remove_extra_params() {
  for (const value of ts_request.value) {
    if (value.source_def) {
      delete value.source_def
    }
  }
}

/* *************************************************** */

/* This function run the REST API with the data */
async function get_chart_options() {
  await resolve_any_params();
  await retrieve_basic_info();
  remove_extra_params();
  const url = base_url.value;
  const post_params = {
    csrf: props.csrf,
    ifid: props.ifid,
    epoch_begin: props.epoch_begin,
    epoch_end: props.epoch_end,
    ...props.params.post_params,
    ...{
      ts_requests: ts_request.value
    }
  }
  /* Have to be used this get_component_data, in order to create report too */
  let result = await props.get_component_data(url, {}, post_params, props.epoch_begin);
  /* Format the result in the format needed by Dygraph */
  result = timeseriesUtils.tsArrayToOptionsArray(result, timeseries_groups.value, group_option_mode, '');
  if (result[0]) {
    result[0].height = height.value;
  }
  return result?.[0];
}

/* *************************************************** */

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
  refresh_chart();
}, { flush: 'pre', deep: true });

/* *************************************************** */

/* Run the init here */
onBeforeMount(async () => {
  await init();
});

/* *************************************************** */

onMounted(async () => { });

/* *************************************************** */

/* Defining the needed info by the get_chart_options function */
async function init() {
  height.value = (props.max_height || 4) * height_per_row;
}

/* *************************************************** */

/* Refresh function */
async function refresh_chart() {
  if (chart.value) {
    const result = await get_chart_options();
    chart.value.update_chart_series(result.data);
  }
}
</script>

