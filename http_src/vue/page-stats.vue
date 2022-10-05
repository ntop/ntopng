<!-- (C) 2022 - ntop.org     -->
<template>
<div class="col-12 mb-2 mt-2">
  <AlertInfo></AlertInfo>
  <div class="card h-100 overflow-hidden">
    <DataTimeRangePicker style="margin-top:0.5rem;"
			 :id="id_date_time_picker"
			 ref="date_time_picker"
			 @epoch_change="epoch_change">
      <template v-slot:begin>
      </template>
      <template v-slot:extra_buttons>
	<button v-if="enable_snapshots" class="btn btn-link btn-sm" @click="show_modal_snapshot" :title="_i18n('page_stats.manage_snapshots_btn')"><i class="fas fa-lg fa-camera-retro"></i></button>
	<button v-if="traffic_extraction_permitted" class="btn btn-link btn-sm" @click="show_modal_traffic_extraction" :title="_i18n('traffic_recording.pcap_download')"><i class="fas fa-lg fa-download"></i></button>
	
      </template>
    </DataTimeRangePicker>
    <!-- select metric -->
    <div v-show="ts_menu_ready" class="form-group ms-1 me-1 mt-1">
      <div class="inline select2-size me-2 mt-2">
	<SelectSearch v-model:selected_option="selected_metric"
		      :options="metrics"
		      @select_option="select_metric">
	</SelectSearch>
      </div>
      <div class="inline select2-size me-2 mt-2">
	<SelectSearch v-model:selected_option="current_groups_options_mode"
		      :options="groups_options_modes"
		      @select_option="change_groups_options_mode">
	</SelectSearch>
      </div>
      <button type="button" @click="show_manage_timeseries" class="btn btn-sm btn-primary inline" style='vertical-align: super;'>
      	Manage Timeseries
      </button>
      
    </div>
    
    <template v-for="(item, i) in charts_options_items" :key="item.key">
      <div class="m-3" style="height:300px;">
	<Chart :id="id_chart + i" :ref="el => { charts[i] = el }"
	       :chart_type="chart_type"
      	       :register_on_status_change="false"
	       :get_custom_chart_options="get_f_get_custom_chart_options(i)"
	       @zoom="epoch_change"
	       @chart_reloaded="chart_reloaded">
	</Chart>
      </div>
    </template>
  </div>
  
  <div class="mt-4 card card-shadow">
    <div class="card-body">
      <BootstrapTable
	id="page_stats_bootstrap_table"
	:columns="stats_columns"
	:rows="stats_rows"
	:print_html_column="(col) => print_stats_column(col)"
	:print_html_row="(col, row) => print_stats_row(col, row)">
      </BootstrapTable>
    </div>
  </div>
  
  <div class="mt-4 card card-shadow">
    <div class="card-body">
      <div class="mb-4 text-nowrap" style="font-size: 1.1rem;">
        <i class="fa-solid fa-chart-line"></i> 	{{_i18n('page_stats.top_applications')}}
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

<ModalSnapshot v-if="enable_snapshots" ref="modal_snapshot"
	       :csrf="csrf"
	       :page="page_snapshots"
	       @added_snapshot="refresh_snapshots"
	       @deleted_snapshots="refresh_snapshots"
	       @deleted_all_snapshots="refresh_snapshots">
</ModalSnapshot>

<ModalTimeseries
  ref="modal_timeseries"
  @apply="apply_modal_timeseries">
</ModalTimeseries>

<ModalTrafficExtraction
  id="page_stats_modal_traffic_extraction"
  ref="modal_traffic_extraction">
</ModalTrafficExtraction>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, watch } from "vue";
import { default as Chart } from "./chart.vue";
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as AlertInfo } from "./alert-info.vue";

import { default as SelectSearch } from "./select-search.vue";
import { default as Datatable } from "./datatable.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";
import timeseriesUtils from "../utilities/timeseries-utils.js";
import metricsManager from "../utilities/metrics-manager.js";
import formatterUtils from "../utilities/formatter-utils";
import { DataTableUtils } from "../utilities/datatable/sprymedia-datatable-utils";
import NtopUtils from "../utilities/ntop-utils";

const props = defineProps({
    csrf: String,
    enable_snapshots: Boolean,
    is_clickhouse_enabled: Boolean,
    traffic_extraction_permitted: Boolean,
});

ntopng_utility.check_and_set_default_interval_time();

const _i18n = (t) => i18n(t);

let id_chart = "chart";
let id_date_time_picker = "date_time_picker";
let chart_type = ntopChartApex.typeChart.TS_LINE;
let config_app_table = ref({});
const charts = ref([]);
const date_time_picker = ref(null);
const top_applications_table = ref(null);
const modal_timeseries = ref(null);
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

const custom_metric = { label: i18n('page_stats.custom_metrics'), currently_active: false }

const page_snapshots = "timeseries";

const ts_menu_ready = ref(false);

function init_groups_option_mode() {
    let groups_mode = ntopng_url_manager.get_url_entry("timeseries_groups_mode");
    if (groups_mode != null && groups_mode != "") {
	return timeseriesUtils.getGroupOptionMode(groups_mode);
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

function reload_table() {
    let table = top_applications_table.value;
    NtopUtils.showOverlays();
    table.reload();
    NtopUtils.hideOverlays();
}

let last_push_custom_metric = null;
async function get_metrics(push_custom_metric, force_refresh) {
    if (!force_refresh && last_push_custom_metric == push_custom_metric) { return metrics.value; }
    
    let metrics = await metricsManager.get_metrics(http_prefix);
    if (push_custom_metric) {
	metrics.push(custom_metric);
    }
    if (cache_snapshots == null || force_refresh) {
	cache_snapshots = await get_snapshots_metrics();
    }
    let snapshots_metrics = cache_snapshots;
    snapshots_metrics.forEach((sm) => metrics.push(sm));
    /* Order Metrics */
    metrics.sort(NtopUtils.sortAlphabetically);
    
    return metrics;
}

async function get_snapshots_metrics() {
    if (!props.enable_snapshots) { return; }
    let url = `${http_prefix}/lua/pro/rest/v2/get/filters/snapshots.lua?page=${page_snapshots}`;
    
    let snapshots_obj = await ntopng_utility.http_request(url);
    let snapshots = ntopng_utility.object_to_array(snapshots_obj);
    let metrics_snapshots = snapshots.map((s) => {
	return {
            ...s,
            is_snapshot: true,
            label: `${s.name}`,
	    group: "Snapshots",
	};
    });
    console.log(snapshots);
    return metrics_snapshots;
}

async function get_selected_timeseries_groups() {
    let metric = selected_metric.value;
    return get_timeseries_groups_from_metric(metric);
}

async function get_timeseries_groups_from_metric(metric) {
    let source_type = metricsManager.get_current_page_source_type();
    let source = await metricsManager.get_default_source(http_prefix, source_type);
    let ts_group = metricsManager.get_ts_group(source_type, source, metric);
    let timeseries_groups = [ts_group];
    return timeseries_groups;
}

async function add_metric_from_metric_schema(metric_schema, metric_query) {
    let metric = metrics.value.find((m) => m.schema == metric_schema && m.query == metric_query);
    if (metric == null) {
	console.error(`metric = ${metric_schema}, query = ${metric_query} not found.`);
	return;
    }
    let timeseries_groups = await get_timeseries_groups_from_metric(metric);
    modal_timeseries.value.set_timeseries_groups(last_timeseries_groups_loaded);
    modal_timeseries.value.add_ts_group(timeseries_groups[0], true);
}

async function select_metric(metric) {
    if (metric.is_snapshot == true) {
	let url_parameters = metric.filters;
	let timeseries_url_params = ntopng_url_manager.get_url_entry("timeseries_groups", url_parameters);
	let timeseries_groups = await metricsManager.get_timeseries_groups_from_url(http_prefix, timeseries_url_params);
	current_groups_options_mode.value = timeseriesUtils.getGroupOptionMode(ntopng_url_manager.get_url_entry("timeseries_groups_mode", url_parameters));
	await load_charts_data(timeseries_groups);
    } else {
	await load_charts_selected_metric();
	refresh_metrics(false);
    }
}

async function load_charts_selected_metric() {
    let timeseries_groups = await get_selected_timeseries_groups();
    await load_charts_data(timeseries_groups);
}

function epoch_change(new_epoch) {    
    console.log(new_epoch);
    let push_custom_metric = selected_metric.value.label == custom_metric.label;
    load_charts_data(last_timeseries_groups_loaded);    
    reload_table_data();
    refresh_metrics(push_custom_metric, true);
}

function chart_reloaded(chart_options) {
    console.log("chart reloaded");
}

function show_modal_snapshot() {
    modal_snapshot.value.show();
}

function show_manage_timeseries() {
    if (last_timeseries_groups_loaded == null) { return; }
    modal_timeseries.value.show(last_timeseries_groups_loaded);
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

let cache_snapshots = null;
function refresh_snapshots() {
    let push_custom_metric = selected_metric.value.label == custom_metric.label;
    refresh_metrics(push_custom_metric, true);
}

async function refresh_metrics(push_custom_metric, force_refresh) {
    metrics.value = await get_metrics(push_custom_metric, force_refresh);
    if (push_custom_metric) {
	selected_metric.value = custom_metric;
    }
}

async function apply_modal_timeseries(timeseries_groups) {
    console.log("apply modal-timeseries in page-stats");
    refresh_metrics(true);
    await load_charts_data(timeseries_groups);
}

function change_groups_options_mode() {    
    load_charts_data(last_timeseries_groups_loaded, true);
}

let ts_chart_options;
async function load_charts_data(timeseries_groups, not_reload) {
    let status = ntopng_status_manager.get_status();
    let ts_compare = get_ts_compare(status);
    if (!not_reload) {	
	let chart_data_url = `${http_prefix}/lua/rest/v2/get/timeseries/ts.lua`;
	let params_url_request = `ts_compare=${ts_compare}&version=4&zoom=${ts_compare}&initial_point=true&limit=180`;
	let params_obj = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };
	
	let ts_responses_promises = timeseries_groups.map((ts_group) => {
	    let ts_query = `${ts_group.source_type.value}:${ts_group.source.value}`
	    if(ts_group.metric.query) {
		ts_query = `${ts_query},${ts_group.metric.query}`
	    }
	    let p_obj = {
		...params_obj,
		ts_query: ts_query,
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
    
    let charts_options = timeseriesUtils.tsArrayToApexOptionsArray(ts_chart_options, timeseries_groups, current_groups_options_mode.value, ts_compare);
    
    set_charts_options_items(charts_options);
    set_stats_rows(ts_chart_options, timeseries_groups, status);
    
    // set last_timeseries_groupd_loaded
    last_timeseries_groups_loaded = timeseries_groups;
    console.log("SET last_timeseries_groups_loaded");
    console.log(last_timeseries_groups_loaded);
    // update url params
    update_url_params();
}

function update_url_params() {
    ntopng_url_manager.set_key_to_url("timeseries_groups_mode", current_groups_options_mode.value.value);
    metricsManager.set_timeseries_groups_in_url(last_timeseries_groups_loaded);
}

function set_charts_options_items(charts_options) {
    charts_options_items.value = charts_options.map((options, i) => {
	return {
	    key: ntopng_utility.get_random_string(),
	    chart_options: options,
	};
    });
}

function get_ts_compare(status) {
    // 5m, 30m, 1h, 1d, 1w, 1M, 1Y
    let r = Number.parseInt((status.epoch_end - status.epoch_begin) / 60);
    if (r <= 5) {
	return "5m";
    } else if (r <= 30) {
	return "30m";
    } else if (r <= 60) {
	return "1h";
    } else if (r <= 60 * 24) {
	return "1d";
    } else if (r <= 60 * 24 * 7) {
	return "1w";
    } else if (r <= 60 * 24 * 30) {
	return "1M";
    } else {
	return "1Y";
    }
}

function get_datatable_url() {
    let chart_data_url = `${http_prefix}/lua/pro/rest/v2/get/interface/top/ts_stats.lua`;
    let p_obj = {
	zoom: '5m',
	ts_query: `ifid:${ntopng_url_manager.get_url_entry('ifid')}`,
	epoch_begin: `${ntopng_url_manager.get_url_entry('epoch_begin')}`,
	epoch_end: `${ntopng_url_manager.get_url_entry('epoch_end')}`,
	detail_view: `top_protocols`,
	new_charts: `true`
    };
    
    let p_url_request =  ntopng_url_manager.add_obj_to_url(p_obj, '');
    return `${chart_data_url}?${p_url_request}`;
}

async function reload_table_data() {
    const url = get_datatable_url();
    top_applications_table.value.update_url(url);
    top_applications_table.value.reload();
}

async function load_datatable_data() {
    const url = get_datatable_url()
    set_table_configuration(url)
};

function set_table_configuration(url) {
    const default_sorting_columns = 2 /* Percentage column */
    let columns = [
	{ columnName: i18n("application"), name: 'application', data: 'protocol', className: 'text-nowrap', responsivePriority: 1, handlerId: "page-stats-action-link-application", render: (data, type, service) => {
	    let handler = {
		handlerId: "page-stats-action-link-application",
		onClick: () => {
		    console.log(data);
		    console.log(service);
		    let schema = `top:${service.ts_schema}`;
		    add_metric_from_metric_schema(schema, service.ts_query)
		},
	    };
	    return DataTableUtils.createLinkCallback({ text: data.label, handler });
	},},
	{ columnName: i18n("traffic"), name: 'traffic', data: 'traffic', orderable: false, className: 'text-nowrap', responsivePriority: 1,
	  render: (data) => {
	      return NtopUtils.bytesToSize(data)
	  }, 
	},
	{ columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage', className: 'text-nowrap', responsivePriority: 1,
	  render: (data) => {
      const percentage = data.toFixed(1);
      return NtopUtils.createProgressBar(percentage)
	  } 
	}
    ];  
    
    /* If ClickHouse is enabled, then add an href to Historical Flows */
    if(true) {
	let handlerIdJumpHistorical = "page-stats-action-jump-historical";
	columns.push({
	    columnName: i18n("actions"),
	    width: '5%',
	    name: 'actions',
	    className: 'text-center',
	    orderable: false,
	    responsivePriority: 0,
	    handlerId: handlerIdJumpHistorical,
	    render: (data, type, service) => {
		const jump_to_historical = {
		    handlerId: handlerIdJumpHistorical,
		    onClick: () => {
			let l7_proto = ntopng_url_manager.serialize_param("l7proto", `${service.protocol.id};eq`); 
			let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?ifid=${ntopng_url_manager.get_url_entry('ifid')}&epoch_begin=${ntopng_url_manager.get_url_entry('epoch_begin')}&epoch_end=${ntopng_url_manager.get_url_entry('epoch_end')}&${l7_proto}`;
			console.log(historical_flows_url);
			window.open(historical_flows_url);
		    }
		};
		return DataTableUtils.createActionButtons([
		    { class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		]);
	    }
	});
    }
    
    const datatable_config = {
	table_buttons: [ { text: '<i class="fas fa-sync"></i>', className: 'btn-link', action: function () { reload_table(); } } ],
	columns_config: columns,
	data_url: url,
	enable_search: true,
	table_config: { serverSide: false, order: [[ default_sorting_columns, 'desc' ]] }
    };
    config_app_table = datatable_config
}

let stats_columns = [
    { id: "metric", label: _i18n("page_stats.metric") },
    { id: "avg", label: _i18n("page_stats.average") },
    { id: "perc_95", label: _i18n("page_stats.95_perc") },
    { id: "max", label: _i18n("page_stats.max") },
    { id: "min", label: _i18n("page_stats.min") },
    { id: "total", label: _i18n("page_stats.total") },
];

const stats_rows = ref([]);

function set_stats_rows(ts_chart_options, timeseries_groups, status) {
    let extend_serie_name = true;
    const f_get_total_formatter_type = (type) => {
	if (type == "bps") { return "bytes_network"; }
	return type;
    };    
    stats_rows.value = [];
    ts_chart_options.forEach((options, i) => {
	let ts_group = timeseries_groups[i];
	options.series.forEach((s, j) => {
	    let ts_id = timeseriesUtils.getSerieId(s);
	    let s_metadata = ts_group.metric.timeseries[ts_id];
	    let formatter = formatterUtils.getFormatter(ts_group.metric.measure_unit);
	    let ts_stats = options.statistics?.by_serie[j];
	    let name = timeseriesUtils.getSerieName(s_metadata.label, ts_id, ts_group, extend_serie_name);
	    let total = null;
	    let total_formatter_type = f_get_total_formatter_type(ts_group.metric.measure_unit);
	    let total_formatter = formatterUtils.getFormatter(total_formatter_type);
	    if (ts_stats.total != null) {
		let interval = status.epoch_end - status.epoch_begin;
		total = interval * ts_stats.average;
	    }
	    
	    let row = {
		metric: name,
		total: total_formatter(total),
		perc_95: formatter(ts_stats["95th_percentile"]),
		avg: formatter(ts_stats.average),
		max: formatter(ts_stats.max_val),
		min: formatter(ts_stats.min_val),
	    };
	    stats_rows.value.push(row);
	});
    });
}

function print_stats_column(col) {
    return col.label;
}

function print_stats_row(col, row) {
    let label = row[col.id];
    return label;
}

const modal_traffic_extraction = ref(null);
function show_modal_traffic_extraction() {
    modal_traffic_extraction.value.show();
}

</script>

<style scoped>
  .inline {
    display: inline-block;
  }
  .select2-size {
    min-width: 18rem;
  }
</style>
