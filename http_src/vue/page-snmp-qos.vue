<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="col-12 mb-2 mt-2">
    <div v-if="is_qos_polled">
      <div class="button-group mb-2 d-flex align-items-center"> <!-- TableHeader -->
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

      <div class="card h-100 overflow-hidden">
        <Loading :isLoading="loading_chart"></Loading>
        <DateTimeRangePicker style="margin-top:0.5rem;" class="ms-1" :id="id_date_time_picker" :enable_refresh="true"
          ref="date_time_picker" @epoch_change="epoch_change" :min_time_interval_id="min_time_interval_id"
          :custom_time_interval_list="time_preset_list">
        </DateTimeRangePicker>

        <div class="mt-3">
          <TimeseriesChart ref="chartRef" :id="all_qos_id" :get_custom_chart_options="getChartOptions" :disable_fixed_height="true" />
        </div>

        <div class="m-3 card card-shadow">
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
    <div v-else class="col-12 alert alert-info alert-dismissable">
      <span> {{ qos_not_polled_yet }} </span>
      <span class="ms-2 spinner-border spinner-border-sm" role="status"></span>
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
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as Loading } from "./loading.vue";
import { default as Spinner } from "./spinner.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import formatterUtils from "../utilities/formatter-utils";

/* ******************************************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({
  context: Object,
});

/* Consts */
const id_date_time_picker = "date_time_picker";
const min_time_interval_id = "10_min";
const all_qos_id = ref("chart_qos_all");
const filter_table_array = ref([]);
const loading = ref(true);
const loading_chart = ref(true);
const filters = ref([]);
const is_qos_polled = ref(false);
const chartRef = ref(null);
let pendingOptions = null;

async function getChartOptions(_url) {
  return pendingOptions;
}
const qos_not_polled_yet = _i18n('snmp.snmp_qos_info_not_polled');
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
const height_per_row = 62.5;
const height = ref(4 * height_per_row);

const batch_url = `${http_prefix}/lua/rest/v2/get/timeseries/batch.lua`;

const stats_rows = ref([]);
const formatter = formatterUtils.getFormatter("bps");

function set_stats_rows(result) {
  stats_rows.value = [];
  if (!result?.series) return;
  result.series.forEach((s) => {
    const ts_stats = s.statistics;
    if (!ts_stats) return;
    stats_rows.value.push({
      metric: s.name || s.id,
      perc_95: formatter(ts_stats["95th_percentile"]),
      avg:     formatter(ts_stats.average),
      max:     formatter(ts_stats.max_val),
      min:     formatter(ts_stats.min_val),
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
  refresh_chart();
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
      is_qos_polled.value = true;
      set_filters_list(null, opt);
    } else {
      is_qos_polled.value = false;
      setTimeout(load_table_filters_array, 10000)
    }
    return;
  }
  set_filter_array_label();
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

async function check_params() {
  const qos_class = ntopng_url_manager.get_url_entry("qos_class_id");
  if (!qos_class) {
    await load_table_filters_array();
  }
}

/* *************************************************** */

function build_ts_query() {
  const host         = ntopng_url_manager.get_url_entry("host") || "";
  const interface_id = ntopng_url_manager.get_url_entry("snmp_port_idx") || "0";
  const qos_class    = ntopng_url_manager.get_url_entry("qos_class_id") || "0";
  return `ifid:-1,device:${host},if_index:${interface_id},qos_class_id:${qos_class}`;
}

/* *************************************************** */

async function refresh_chart() {
  loading_chart.value = true;
  await check_params();

  const ts_query = build_ts_query();
  if (!ts_query) { loading_chart.value = false; return; }

  const post_body = {
    csrf:        props.context.csrf,
    ifid:        props.context.ifid,
    epoch_begin: ntopng_url_manager.get_url_entry("epoch_begin"),
    epoch_end:   ntopng_url_manager.get_url_entry("epoch_end"),
    queries: [{
      id:        "qos_cbqos",
      ts_schema: "snmp_if:cbqos",
      ts_query:  ts_query,
      limit:     180,
    }],
  };

  const resp = await ntopng_utility.http_post_request(batch_url, post_body);
  const result = resp?.results?.["qos_cbqos"] || null;
  if (result) result._meta = resp?.meta || {};
  pendingOptions = result;
  set_stats_rows(result);
  if (chartRef.value) chartRef.value.retrieveOptionsAndDraw('');
  loading_chart.value = false;
}

/* *************************************************** */

onBeforeMount(async () => {
  await load_table_filters_array();
});

onMounted(async () => {
  refresh_chart();
});

function epoch_change() {
  refresh_chart();
}

</script>