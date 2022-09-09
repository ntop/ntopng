<!-- (C) 2022 - ntop.org     -->
<template>
<div class="col-12 mb-2 mt-2">
  <div class="card h-100 overflow-hidden">
    <DataTimeRangePicker :id="id_date_time_picker"
			 ref="date_time_picker"
			 @epoch_change="epoch_change">
      <template v-slot:begin>
      </template>
      <template v-slot:extra_buttons>
	<button class="btn btn-link btn-sm" @click="show_modal_snapshot" title="Manage Snapshots"><i class="fas fa-lg fa-camera-retro"></i></button>
	
      </template>
    </DataTimeRangePicker>
    <!-- select metric -->
    <div v-show="ts_menu_ready" class="form-group ms-1 me-1 mt-1">
      <div class="inline select2-size me-2" style="top:0.4rem;position:relative;">
	<SelectSearch v-model:selected_option="selected_metric"
		      :options="metrics"
		      :init="true"
		      @select_option="select_metric">
	</SelectSearch>
      </div>
      <div class="inline mb-2 select2-size">
	<select class="me-2  form-select" @change="change_groups_options_mode" style="width:18rem;" v-model="current_groups_options_mode">
	  <option :value="groups_options_modes[0]">
	    One Chart
	  </option>
	  <option :value="groups_options_modes[1]">
	    One Chart for each Y-axis
	  </option>
	  <option :value="groups_options_modes[2]">
	    One Chart for each Metric
	  </option>
	</select>
      </div>
      
      <button type="button" @click="show_manage_timeseries" class="btn btn-sm btn-primary inline">
      	Manage Timeseries
      </button>
      
    </div>
    
    <template v-for="(item, i) in charts_options_items" :key="item.key">
      <div class="m-3" style="height:300px;">
	<Chart :id="id_chart + i" :ref="el => { charts[i] = el }"
	       :chart_type="chart_type"
      	       :register_on_status_change="false"
	       :get_custom_chart_options="get_f_get_custom_chart_options(i)"
	       @chart_reloaded="chart_reloaded">
	</Chart>
      </div>
    </template>
  </div>
  <div class="mt-4 card card-shadow">
    <div class="card-body">
      <div class="mb-4 text-nowrap" style="font-size: 1.1rem;">
        <i class="fa-solid fa-chart-line"></i> Top Applications
      </div>
      <Datatable ref="top_applications_table"
        :table_buttons="config_app_table.table_buttons"
        :columns_config="config_app_table.columns_config"
        :data_url="config_app_table.data_url"
        :enable_search="config_app_table.enable_search"
        :table_config="config_app_table.table_config">
      </Datatable>
    </div>
  </div>
</div>
<!-- <SimpleTable :chart_options="last_chart_options" -->
<!-- ></SimpleTable> -->
<ModalSnapshot ref="modal_snapshot"
	       :csrf="csrf"
	       page="timeseries">
</ModalSnapshot>

<ModalTimeseries
  ref="modal_time_series"
  @apply="apply_modal_timeseries"></ModalTimeseries>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, watch } from "vue";
import { default as Chart } from "./chart.vue";
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as SimpleTable } from "./simple-table.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as Datatable } from "./datatable.vue";

import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";
import timeseriesUtils from "../utilities/timeseries-utils.js";
import metricsManager from "../utilities/metrics-manager.js";

const props = defineProps({
    csrf: String,
});

ntopng_utility.check_and_set_default_interval_time();

let id_chart = "chart";
let id_date_time_picker = "date_time_picker";
let chart_type = ntopChartApex.typeChart.TS_LINE;
let config_app_table = ref({});
const charts = ref([]);
const date_time_picker = ref(null);
const top_applications_table = ref(null);
const modal_time_series = ref(null);
const modal_snapshot = ref(null);

const metrics = ref([]);
const selected_metric = ref({});

/**
 * { key: identifier of Chart component, if change Chart will be destroyed and recreated,
 *  chart_options: chart options }[]
 **/
const charts_options_items = ref([]);

/**
 * Modes that represent how it's possible display timeseries.
 */
const groups_options_modes = ntopng_utility.object_to_array(timeseriesUtils.groupsOptionsModesEnum);
/**
 * Current display timeseries mode.
 */
const current_groups_options_mode = ref(init_groups_option_mode());

let last_timeseries_groups_loaded = null;

const custom_metric = {
    label: "Custom Metrics",
};
const ts_menu_ready = ref(false);

function init_groups_option_mode() {
    let groups_mode = ntopng_url_manager.get_url_entry("timeseries_groups_mode");
    if (groups_mode != null && groups_mode != "") {
	return groups_mode;
    }
    return groups_options_modes[0];
}

onBeforeMount(async() => {
  await load_datatable_data();
});

onMounted(async () => {
    init();
    await Promise.all([
	ntopng_sync.on_ready(id_date_time_picker),
    ]);
    // chart.value.register_status();
});

async function init() {
    //get_default_timeseries_groups
    let push_custom_metric = true;
    let timeseries_groups = await metricsManager.get_timeseries_groups_from_url(http_prefix);
    if (timeseries_groups == null) {
      push_custom_metric = false;
      timeseries_groups = await metricsManager.get_default_timeseries_groups(http_prefix);
    }
    metrics.value = await get_metrics(push_custom_metric);

    if (push_custom_metric == true) {
	selected_metric.value = custom_metric;
    } else {
	selected_metric.value = metricsManager.get_default_metric(metrics.value);
    }
    ts_menu_ready.value = true;
    await load_charts_data(timeseries_groups);
}

async function get_metrics(push_custom_metric) {
    let metrics = await metricsManager.get_metrics(http_prefix);
    if (push_custom_metric) {
	metrics.push(custom_metric);
    }
    return metrics;
}

async function get_selected_timeseries_groups() {
    let source_type = metricsManager.get_current_page_source_type();
    let source = await metricsManager.get_default_source(http_prefix, source_type);
    let metric = selected_metric.value;
    let ts_group = metricsManager.get_ts_group(source_type, source, metric);
    let timeseries_groups = [ts_group];
    return timeseries_groups;
}

async function select_metric(metric) {
    console.log(metric);
    // update chart
    await load_charts_selected_metric();
    // console.log("update chart from select");
    // chart.value.update_chart();
    // update metrics
    refresh_metrics(false);
}

async function load_charts_selected_metric() {
    let timeseries_groups = await get_selected_timeseries_groups();
    await load_charts_data(timeseries_groups);
}

function epoch_change(new_epoch) {
  console.log(new_epoch);
  load_charts_data(last_timeseries_groups_loaded);
  reload_table_data();
}

function chart_reloaded(chart_options) {
    console.log("chart reloaded");
}

function show_modal_snapshot() {
    modal_snapshot.value.show();
}

function show_manage_timeseries() {
    if (last_timeseries_groups_loaded == null) { return; }
    modal_time_series.value.show(last_timeseries_groups_loaded);
};

/**
 * Function called by Chart component to draw or update that return chart options.
 **/
function get_f_get_custom_chart_options(chart_index) {
    console.log("get_f_");
    return async (url) => {
	console.log("get_charts_options");	
	return charts_options_items.value[chart_index].chart_options;
    }
}

async function refresh_metrics(push_custom_metric) {
    metrics.value = await get_metrics(push_custom_metric);
    if (push_custom_metric) {
	selected_metric.value = custom_metric;
    }
}

async function apply_modal_timeseries(timeseries_groups) {
    console.log("apply modal-timeseries in page-stats");
    refresh_metrics(true);
    await load_charts_data(timeseries_groups);
    
    // chart.value.update_chart();
}

function change_groups_options_mode() {    
    load_charts_data(last_timeseries_groups_loaded, true);
}

let ts_chart_options;
async function load_charts_data(timeseries_groups, not_reload) {
    if (!not_reload) {	
	let status = ntopng_status_manager.get_status();
	let chart_data_url = `${http_prefix}/lua/rest/v2/get/timeseries/ts.lua`;
	let params_url_request = `ts_compare=30m&version=4&zoom=30m&initial_point=true&limit=180`;
	let params_obj = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };
	
	let ts_responses_promises = timeseries_groups.map((ts_group) => {
    	    let p_obj = {
    		...params_obj,
    		ts_query: `${ts_group.source_type.value}:${ts_group.source.value}`,
    		ts_schema: `${ts_group.metric.schema}`,
    	    };
    	    let p_url_request =  ntopng_url_manager.add_obj_to_url(p_obj, params_url_request);
    	    let url = `${chart_data_url}?${p_url_request}`;
    	    return ntopng_utility.http_request(url);
	});
	ts_chart_options = await Promise.all(ts_responses_promises);
    }
    console.log(ts_chart_options);
    console.log(timeseries_groups);

    let charts_options = timeseriesUtils.tsArrayToApexOptionsArray(ts_chart_options, timeseries_groups, current_groups_options_mode.value);

    set_charts_options_items(charts_options);
    
    // set last_timeseries_groupd_loaded
    last_timeseries_groups_loaded = timeseries_groups;
    console.log("SET last_timeseries_groups_loaded");
    console.log(last_timeseries_groups_loaded);
    // update url params
    update_url_params();
}

function update_url_params(timeseries_groups) {
    ntopng_url_manager.set_key_to_url("timeseries_groups_mode", current_groups_options_mode.value);
    metricsManager.set_timeseries_groups_in_url(last_timeseries_groups_loaded);
}

function set_charts_options_items(charts_options) {
    charts_options_items.value = charts_options.map((options, i) => {
	return {
	    key: ntopng_utility.get_random_string(),
	    chart_options: options,
	};
    });
    // let old_charts_length = charts_options_items.value.length;
    // charts_options_items.value = charts_options.map((options, i) => {
    // 	let key;
    // 	if (charts_options_items.value.length > i) {
    // 	    key = charts_options_items.value[i].key;
    // 	} else {
    // 	    key = ntopng_utility.get_random_string();
    // 	}
    // 	return {
    // 	    key,
    // 	    chart_options: options,
    // 	};
    // });
    // let new_charts_length = charts_options_items.value.length;
    // charts.value.filter((c, i) => i < old_charts_length && i < new_charts_length).forEach((chart) => {
    // 	console.log("UPDATE CHART");
    // 	chart.update_chart();
    // });
}

function get_datatable_url() {
  let chart_data_url = `${http_prefix}/lua/pro/get_ts_table.lua`;
	let p_obj = {
    zoom: '5m',
    ts_query: `ifid:${ntopng_url_manager.get_url_entry('ifid')}`,
    ts_schema: `iface:traffic_rx_tx`,
    epoch_begin: `${ntopng_url_manager.get_url_entry('epoch_begin')}`,
    epoch_end: `${ntopng_url_manager.get_url_entry('epoch_end')}`,
    detail_view: `top_protocols`,
    new_charts: `true`
  };
  
  let p_url_request =  ntopng_url_manager.add_obj_to_url(p_obj, '');
  return `${chart_data_url}?${p_url_request}`;
}

function reload_table_data() {
  const url = get_datatable_url();
  top_applications_table.value.update_url(url);
  top_applications_table.value.reload();
}

async function load_datatable_data() {
  const url = get_datatable_url()
  set_table_configuration(url)
};

function set_table_configuration(url) {
  const default_sorting_columns = 1 /* Traffic column */
  const columns = [
    { columnName: i18n("application"), width: '35%', name: 'application', data: 'protocol', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("traffic"), name: 'traffic', width: '30%', data: 'traffic', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("percentage"), name: 'traffic_perc', width: '35%', data: 'percentage', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("actions"), name: 'actions', data: 'drilldown',  className: 'text-center', orderable: false, responsivePriority: 0, render: (data, type, service) => {
        return DatatableVue.create_action_buttons(data, type, service);
      },
    }
  ];  

  const datatable_config = {
    table_buttons: [ { text: '<i class="fas fa-sync"></i>', className: 'btn-link', action: function () { DatatableVue.reload_table(); } } ],
    columns_config: columns,
    data_url: url,
    enable_search: true,
    table_config: { serverSide: false, order: [[ default_sorting_columns, 'desc' ]] }
  };
  config_app_table = ntopng_utility.clone(datatable_config)
}
      
const _i18n = (t) => i18n(t);

</script>

<style scoped>
  .inline {
    display: inline-block;
  }
  .select2-size {
    min-width: 18rem;
  }
</style>
