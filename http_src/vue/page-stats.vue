<!-- (C) 2022 - ntop.org     -->
<template>
<div class="col-12 mb-2 mt-2">
  <div class="card h-100 overflow-hidden">
    <DataTimeRangePicker :id="id_date_time_picker"
			 ref="date_time_picker"
			 @epoch_change="epoch_change">
      <template v-slot:begin>
	<div class="d-flex align-items-center ms-2 me-2">
	  <button type="button" @click="show_manage_timeseries" class="btn btn-sm btn-primary">
	    Timeseries
	  </button>
	</div>
	<select class="me-2 form-select" @change="change_groups_options_mode" style="width:18rem;" v-model="current_groups_options_mode">
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
      </template>
    </DataTimeRangePicker>
    <!-- select metric -->
    <div class="form-group ms-2 me-2 mt-3 row">
      <div class="col-4">
	<SelectSearch v-model:selected_option="selected_metric"
		      :options="metrics"
		      :init="true"
		      @select_option="select_metric">
	</SelectSearch>
      </div>
    </div>
    
    <template v-for="(item, i) in charts_options_items" :key="item.key">
      <div style="height:300px;">
	<Chart :id="id_chart + i" :ref="el => { charts[i] = el }"
	       :chart_type="chart_type"
      	       :register_on_status_change="false"
	       :get_custom_chart_options="get_f_get_custom_chart_options(i)"
	       @chart_reloaded="chart_reloaded">
	</Chart>
      </div>
    </template>
  </div>
</div>
<!-- <SimpleTable :chart_options="last_chart_options" -->
<!-- ></SimpleTable> -->

<ModalTimeseries
  ref="modal_time_series"
  @apply="apply_modal_timeseries"></ModalTimeseries>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as Chart } from "./chart.vue";
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as SimpleTable } from "./simple-table.vue";
import { default as SelectSearch } from "./select-search.vue";

import timeseriesUtils from "../utilities/timeseries-utils.js";
import metricsManager from "../utilities/metrics-manager.js";

ntopng_utility.check_and_set_default_interval_time();

let id_chart = "chart";
let id_date_time_picker = "date_time_picker";
let chart_type = ntopChartApex.typeChart.TS_LINE;

const charts = ref([]);
const date_time_picker = ref(null);
const modal_time_series = ref(null);

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
const current_groups_options_mode = ref(groups_options_modes[0]);

let last_timeseries_groups_loaded = null;

const custom_metric = {
    label: "Custom Metrics",
};

onMounted(async () => {
    init();
    await Promise.all([
	ntopng_sync.on_ready(id_date_time_picker),
    ]);
    // chart.value.register_status();
});

async function init() {    
    metrics.value = await get_metrics();
    
    selected_metric.value = metricsManager.get_default_metric(metrics.value);
    await load_charts_selected_metric();
}

async function get_metrics(from_apply_modal_ts) {
    let metrics = await metricsManager.get_metrics(http_prefix);
    if (from_apply_modal_ts) {
	metrics.push(custom_metric);
    }
    return metrics;
}

function get_selected_timeseries_groups() {
    let timeseries_groups = [{
    	source_type: metricsManager.get_current_page_source_type(),
    	source: {
    	    value: metricsManager.get_default_source_value(),
    	},
    	metric: selected_metric.value,	
    }];
    return timeseries_groups;
}

async function select_metric(metric) {
    console.log(metric);
    // update modal
    modal_time_series.value.select_metric(metric);    
    // update chart
    await load_charts_selected_metric();
    // console.log("update chart from select");
    // chart.value.update_chart();
    // update metrics
    refresh_metrics(false);
}

async function load_charts_selected_metric() {
    let timeseries_groups = get_selected_timeseries_groups();
    await load_charts_data(timeseries_groups);
}

function epoch_change(new_epoch) {
    console.log(new_epoch);
    load_charts_data(last_timeseries_groups_loaded);
}

function chart_reloaded(chart_options) {
    console.log("chart reloaded");
}

function show_manage_timeseries() {
    modal_time_series.value.show();
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

async function refresh_metrics(from_apply_modal_ts) {
    metrics.value = await get_metrics(from_apply_modal_ts);
    if (from_apply_modal_ts) {
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
      
const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
