<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="col-12 mb-2 mt-2">
    <div v-if="show_filters" class="button-group mb-2 d-flex align-items-center"> <!-- TableHeader -->
      <div class="form-group d-flex align-items-end" style="flex-wrap: wrap;">
        <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
          <span class="no-wrap d-flex align-items-center filters-label fs-6"><b>{{ item["basic_label"]
              }}</b></span>
          <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5" dropdown_size="medium"
            :disabled="loading" :options="item['options']" @select_option="add_filter">
          </SelectSearch>
        </div>
        <div class="d-flex justify-content-center align-items-center">
          <div class="btn btn-sm btn-primary mb-1 me-3" type="button" @click="search_timeseries">
            {{ _i18n('search') }}
          </div>
          <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
        </div>
      </div>
    </div>
    <div v-else class="col-12 alert alert-info alert-dismissable">
      <span> {{ qos_not_polled_yet }}</span>
    </div>

    <div class="card h-100 overflow-hidden">
      <Loading v-if="loading_chart"></Loading>
      <DateTimeRangePicker style="margin-top:0.5rem;" class="ms-1" :id="id_date_time_picker" :enable_refresh="true"
        ref="date_time_picker" @epoch_change="epoch_change" :min_time_interval_id="min_time_interval_id"
        :custom_time_interval_list="time_preset_list">
      </DateTimeRangePicker>

      <div class="mt-3" :class="[(loading_chart) ? 'ntopng-gray-out' : '']">
        <TimeseriesChart ref="all_qos_chart" :id="all_qos_id" :chart_type="chart_type" :base_url_request="base_url"
          :get_custom_chart_options="get_chart_options" :register_on_status_change="false"
          :disable_pointer_events="false" :key="all_qos_id">
        </TimeseriesChart>
      </div>

      <div class="m-3 card card-shadow" :class="[(loading_chart) ? 'ntopng-gray-out' : '']">
        <div class="card-body">
          <BootstrapTable id="page_stats_bootstrap_table" :columns="stats_columns" :rows="stats_rows"
            :print_html_column="(col) => print_stats_column(col)"
            :print_html_row="(col, row) => print_stats_row(col, row)">
          </BootstrapTable>
        </div>
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
import { default as Loading } from "./loading.vue";
import { default as Spinner } from "./spinner.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import formatterUtils from "../utilities/formatter-utils";
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
const all_qos_id = ref("chart_qos_all");
const basic_source_type = "snmp_qos";
const group_option_mode = timeseriesUtils.getGroupOptionMode('1_chart_x_metric');
const filter_table_array = ref([]);
const loading = ref(false);
const loading_chart = ref(false);
const filters = ref([]);
const show_filters = ref(true);
const qos_not_polled_yet = _i18n('snmp.snmp_qos_info_not_polled')
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
const stats_columns = [
  { id: "metric", label: i18n("page_stats.metric") },
  { id: "avg", label: i18n("page_stats.average"), class: "text-end" },
  { id: "perc_95", label: i18n("page_stats.95_perc"), class: "text-end" },
  { id: "max", label: i18n("page_stats.max"), class: "text-end" },
  { id: "min", label: i18n("page_stats.min"), class: "text-end" },
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
  ts_query: "ifid:-1,device:%host,if_index:%interface_id,qos_class_id:%qos_class",
  ts_schema: "snmp_if:qos",
  tskey: "%interface_id",
  source_def: [
    "-1", /* System Interface */
    "%host",
    "%interface_id",
    "%qos_class"
  ]
}]);;

const stats_rows = ref([]);

function set_stats_rows(result) {
  const f_get_total_formatter_type = (type) => {
    let map_type = {
      "bps": "bytes",
      "fps": "flows",
      "alertps": "alerts",
      "hitss": "hits",
      "pps": "packets",
    };
    if (map_type[type] != null) {
      return map_type[type];
    }
    return type;
  };
  stats_rows.value = [];
  result.forEach((options, i) => {
    options.series?.forEach((s, j) => {
      const ts_stats = s.statistics;
      const name = timeseries_groups.value[0].metric.timeseries[s.id].label;
      const formatter = formatterUtils.getFormatter(timeseries_groups.value[0].metric.measure_unit);
      const row = {
        metric: name,
        perc_95: formatter(ts_stats["95th_percentile"]),
        avg: formatter(ts_stats.average),
        max: formatter(ts_stats.max_val),
        min: formatter(ts_stats.min_val),
      };
      stats_rows.value.push(row);
    });
  });
}

/* *************************************************** */

function print_stats_column(col) {
  return col.label;
}

/* *************************************************** */

function print_stats_row(col, row) {
  let label = row[col.id];
  return label;
}

/* *************************************************** */

function search_timeseries() {
  /* This is a trick to reload the entire timeseries component
   * if not reloaded there could be some issues with parameters
   */
  all_qos_id.value = ntopng_url_manager.get_url_entry("qos_class_id");
}

/* *************************************************** */

async function add_filter(opt) {
  ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
  await load_table_filters_array(opt);
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

function set_filters_list(res, opt) {
  if (!res) {
    filter_table_array.value = filters.value.filter((t) => {
      if (t.show_with_key) {
        const key = ntopng_url_manager.get_url_entry(t.show_with_key)
        if (key !== t.show_with_value) {
          return false
        }
        const first_option = t.options[0];
        if (opt && opt.key !== first_option.key) {
          /* Changing the dropdown, changing the option too */
          ntopng_url_manager.set_key_to_url(first_option.key, first_option.value);
        }
      }
      return true
    })
  } else {
    filters.value = res.filter(t => t.value.length > 0).map((t) => {
      /* Do not add filters if no values are found */
      if (t.value.length == 0)
        return;

      const key_in_url = ntopng_url_manager.get_url_entry(t.name);
      if ((key_in_url === null || key_in_url === '') && t.value[0]) {
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
    if (filters.value.length > 0) {
      show_filters.value = true;
      set_filters_list(null, opt);
    } else {
      show_filters.value = false;
    }
    return;
  }
  set_filter_array_label();
}

/* ************************************** */

function substitute_params(params) {
  let res = {}
  const host = ntopng_url_manager.get_url_entry("host");
  const interface_id = ntopng_url_manager.get_url_entry("snmp_port_idx") || "0"; /* Default value */
  const qos_class = ntopng_url_manager.get_url_entry("qos_class_id") || "0"; /* Default value */
  if (!(host && interface_id)) {
    /* Safe check */
    return params
  }
  for (const value of params) {
    res.ts_query = value.ts_query.replace('%host', host).replace('%interface_id', interface_id).replace('%qos_class', qos_class);
    res.tskey = value.tskey.replace('%interface_id', interface_id);
    res.ts_schema = value.ts_schema
    res.source_def = [];
    value.source_def.forEach((source, index) => {
      let tmp = source.replace('%host', host);
      tmp = tmp.replace('%interface_id', interface_id);
      tmp = tmp.replace('%qos_class', qos_class);
      res.source_def[index] = tmp;
    });
  }
  return res
}

/* ************************************** */

async function load_table_filters_array(opt) {
  loading.value = true;
  let extra_params = get_extra_params_obj();
  let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const url = `${http_prefix}/lua/pro/rest/v2/get/snmp/device/qos_filters.lua?${url_params}`;
  const res = await ntopng_utility.http_request(url);
  set_filters_list(res, opt)
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
  const tmp = substitute_params(ts_request.value);
  const metric_schema = tmp?.ts_schema;
  const source_def = tmp.source_def;
  if (source_def && metric_schema) {
    delete tmp.source_def /* Remove the property otherwise it's going to be added to the REST */
    /* Return the timeseries group, info found in the json */
    if (timeseries_groups.value.length == 0) {
      const group = await get_timeseries_groups_from_metric(metric_schema, source_def);
      timeseries_groups.value.push(group);
    }
    return [tmp];
  }
  return null;
}

/* *************************************************** */

/* Remove the property otherwise it's going to be added to the REST */
function remove_extra_params(tmp) {
  for (const value of tmp) {
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

async function check_params() {
  const qos_class = ntopng_url_manager.get_url_entry("qos_class_id");
  if (!qos_class) {
    await load_table_filters_array();
  }
}

/* *************************************************** */

/* This function run the REST API with the data */
async function get_chart_options() {
  loading_chart.value = true;
  await check_params();
  const tmp = await retrieve_basic_info();
  let result = [];
  if (tmp) {
    remove_extra_params(tmp);
    const url = base_url.value;
    const post_params = {
      csrf: props.context.csrf,
      ifid: props.context.ifid,
      epoch_begin: ntopng_url_manager.get_url_entry("epoch_begin"),
      epoch_end: ntopng_url_manager.get_url_entry("epoch_end"),
      ts_requests: tmp
    }
    /* Have to be used this get_component_data, in order to create report too */
    result = await get_component_data(url, '', post_params);
  }
  set_stats_rows(result)
  /* Format the result in the format needed by Dygraph */
  result = timeseriesUtils.tsArrayToOptionsArray(result, timeseries_groups.value, group_option_mode, '');
  if (result[0]) {
    result[0].height = height.value;
  }
  loading_chart.value = false;
  return result?.[0];
}

/* *************************************************** */

/* Run the init here */
onBeforeMount(async () => {
  load_table_filters_array();
  height.value = 4 * height_per_row;
});

/* *************************************************** */

onMounted(async () => { });

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