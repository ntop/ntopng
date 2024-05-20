<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="col-12 mb-2 mt-2">
    <div class="button-group mb-2 d-flex align-items-center"> <!-- TableHeader -->
      <div class="form-group d-flex align-items-end" style="flex-wrap: wrap;">
        <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
          <span class="no-wrap d-flex align-items-center filters-label"><b>{{ item["basic_label"]
              }}</b></span>
          <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5" dropdown_size="small"
            :disabled="loading" :options="item['options']" @select_option="check_filter_validation">
          </SelectSearch>
        </div>
        <div class="d-flex justify-content-center align-items-center">
          <div class="btn btn-sm btn-primary mt-2 me-3" type="button" @click="search_timeseries">
            {{ _i18n('search') }}
          </div>
          <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
        </div>
      </div>
    </div>

    <div class="card h-100 overflow-hidden">
      <DateTimeRangePicker style="margin-top:0.5rem;" class="ms-1" :id="id_date_time_picker" :enable_refresh="true"
        ref="date_time_picker" @epoch_change="epoch_change" :min_time_interval_id="min_time_interval_id"
        :custom_time_interval_list="time_preset_list">
      </DateTimeRangePicker>

      <div class="mt-3">
        <TimeseriesChart ref="all_qos_chart" :id="all_qos_id" :chart_type="chart_type" :base_url_request="base_url"
          :get_custom_chart_options="get_chart_options" :register_on_status_change="false"
          :disable_pointer_events="false">
        </TimeseriesChart>
      </div>
    </div>

    <div class="card-footer">
      <NoteList :note_list="note_list"> </NoteList>
    </div>
  </div>
</template>

<script setup>
/* Imports */
import { ref, onMounted, onBeforeMount, computed } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Spinner } from "./spinner.vue";
import metricsManager from "../utilities/metrics-manager.js";
import timeseriesUtils from "../utilities/timeseries-utils.js";

/* ******************************************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({
  context: Object,
});

/* Consts */
const id_date_time_picker = "date_time_picker";
const chart_type = ntopChartApex.typeChart.TS_LINE;
const min_time_interval_id = "10_min";
const all_qos_id = "chart_qos_all";
const basic_source_type = "snmp_interface";
const group_option_mode = timeseriesUtils.getGroupOptionMode('1_chart_x_yaxis');
const filter_table_array = ref([]);
const loading = ref(false);
const filters = ref([]);
const note_list = [
  _i18n("snmp.snmp_note_periodic_interfaces_polling"),
  _i18n("snmp.snmp_note_thpt_calc"),
  _i18n("snmp.snmp_lldp_cdp_descr")
];
const time_preset_list = [
  { value: "10_min", label: i18n('show_alerts.presets.10_min'), currently_active: false },
  { value: "30_min", label: i18n('show_alerts.presets.30_min'), currently_active: true },
  { value: "hour", label: i18n('show_alerts.presets.hour'), currently_active: false },
  { value: "2_hours", label: i18n('show_alerts.presets.2_hours'), currently_active: false },
  { value: "6_hours", label: i18n('show_alerts.presets.6_hours'), currently_active: false },
  { value: "12_hours", label: i18n('show_alerts.presets.12_hours'), currently_active: false },
  { value: "day", label: i18n('show_alerts.presets.day'), currently_active: false },
  { value: "week", label: i18n('show_alerts.presets.week'), currently_active: false },
  { value: "month", label: i18n('show_alerts.presets.month'), currently_active: false },
  { value: "year", label: i18n('show_alerts.presets.year'), currently_active: false },
  { value: "custom", label: i18n('show_alerts.presets.custom'), currently_active: false, disabled: true, },
];

/* Height and width of the charts */
const height_per_row = 62.5
const height = ref(null);

/* Consts */

/* *************************************************** */

/* Return the base url of the REST API */
const base_url = computed(() => {
  return `${http_prefix}/lua/pro/rest/v2/get/timeseries/ts_multi.lua`;
});

/* Refs */
const all_qos_chart = ref(null);
const timeseries_groups = ref([]);
const ts_request = ref([{
  ts_query: "ifid:-1,device:%host,if_index:%interface_id",
  ts_schema: "snmp_if:traffic",
  tskey: "%interface_id",
  source_def: [
    "-1", /* System Interface */
    "%host",
    "%interface_id"
  ]
}]);

/* *************************************************** */

function search_timeseries() {

}

/* *************************************************** */

function check_filter_validation() {

}

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

function set_filter_array_label() {
  filter_table_array.value.forEach((el, index) => {
    /* Setting the basic label */
    if (el.basic_label == null) {
      el.basic_label = el.label;
    }

    /* Getting the currently selected filter */
    const url_entry = ntopng_url_manager.get_url_entry(el.id)
    el.options.forEach((option) => {
      if (option.value.toString() === url_entry) {
        el.current_option = option;
      }
    })
  })
}

/* ************************************** */

function set_filters_list(res) {
  if (!res) {
    filter_table_array.value = filters.value.filter((t) => {
      if (t.show_with_key) {
        const key = ntopng_url_manager.get_url_entry(t.show_with_key)
        if (key !== t.show_with_value) {
          return false
        }
      }
      return true
    })
  } else {
    filters.value = res.map((t) => {
      const key_in_url = ntopng_url_manager.get_url_entry(t.name);
      if (key_in_url === null || key_in_url === '') {
        ntopng_url_manager.set_key_to_url(t.name, t.value[0].value);
      }
      return {
        id: t.name,
        label: t.label,
        title: t.tooltip,
        options: t.value,
        show_with_key: t.show_with_key,
        show_with_value: t.show_with_value,
      };
    });
    set_filters_list();
    return;
  }
  set_filter_array_label();
}

/* ************************************** */

function substitute_params(params) {
  let res = {}
  const host = ntopng_url_manager.get_url_entry("host");
  const interface_id = ntopng_url_manager.get_url_entry("snmp_port_idx");
  for (const value of params) {
    res.ts_query = value.ts_query.replace('%host', host).replace('%interface_id', interface_id);
    res.tskey = value.tskey.replace('%interface_id', interface_id);
    res.ts_schema = value.ts_schema
    res.source_def = [];
    value.source_def.forEach((source, index) => {
      let tmp = source.replace('%host', host);
      tmp = tmp.replace('%interface_id', interface_id);
      res.source_def[index] = tmp;
    });
  }
  return res
}

/* ************************************** */

async function load_table_filters_array() {
  loading.value = true;
  let extra_params = get_extra_params_obj();
  let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const url = `${http_prefix}/lua/pro/rest/v2/get/snmp/device/qos_filters.lua?${url_params}`;
  const res = await ntopng_utility.http_request(url);
  set_filters_list(res)
  loading.value = false;
}

/* *************************************************** */

/* The source_type can be found on the json and the source_array is automatically generated
 * by using the source_type
 */
async function get_timeseries_groups_from_metric(metric_schema, source_def) {
  const status = {
    epoch_begin: ntopng_url_manager.get_url_entry("epoch_begin"),
    epoch_end: ntopng_url_manager.get_url_entry("epoch_end"),
  };
  const source_type = metricsManager.get_source_type_from_id(basic_source_type);
  const source_array = await metricsManager.get_source_array_from_value_array(http_prefix, source_type, source_def);
  const metric = await metricsManager.get_metric_from_schema(http_prefix, source_type, source_array, metric_schema, null, status);
  const ts_group = metricsManager.get_ts_group(source_type, source_array, metric, { past: false });
  return ts_group;
}

/* *************************************************** */

async function retrieve_basic_info() {
  /* Return the timeseries group, info found in the json */
  if (timeseries_groups.value.length == 0) {
    ts_request.value[0] = substitute_params(ts_request.value);
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

async function get_component_data(url, url_params, post_params) {
  let info = null;
  const data_url = `${url}?${url_params}`;
  info = ntopng_utility.http_post_request(data_url, post_params)

  return info;
}

/* *************************************************** */

/* This function run the REST API with the data */
async function get_chart_options() {
  await retrieve_basic_info();
  remove_extra_params();
  const url = base_url.value;
  const post_params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    epoch_begin: ntopng_url_manager.get_url_entry("epoch_begin"),
    epoch_end: ntopng_url_manager.get_url_entry("epoch_end"),
    ts_requests: ts_request.value
  }
  /* Have to be used this get_component_data, in order to create report too */
  let result = await get_component_data(url, '', post_params);
  /* Format the result in the format needed by Dygraph */
  result = timeseriesUtils.tsArrayToOptionsArray(result, timeseries_groups.value, group_option_mode, '');
  if (result[0]) {
    result[0].height = height.value;
  }
  return result?.[0];
}

/* *************************************************** */

/* Run the init here */
onBeforeMount(async() => {
  await load_table_filters_array();
  init();
});

/* *************************************************** */

onMounted(async () => { });

/* *************************************************** */

/* Defining the needed info by the get_chart_options function */
async function init() {
  height.value = 4 * height_per_row;
}

/* *************************************************** */

function epoch_change() {
  refresh_chart();
}

/* *************************************************** */

/* Refresh function */
async function refresh_chart() {
  if (all_qos_chart.value) {
    const result = await get_chart_options();
    all_qos_chart.value.update_chart_series(result.data);
  }
}

</script>