<!-- (C) 2022 - ntop.org     -->
<template>
<div class="col-12 mb-2 mt-2">
  <div class="card h-100 overflow-hidden">
    <DataTimeRangePicker :id="id_date_time_picker" ref="date_time_picker">
      <template v-slot:begin>
	<div class="d-flex align-items-center ms-2 me-2">
	  <button type="button" @click="show_manage_timeseries" class="btn btn-sm btn-primary">
	    Timeseries
	  </button>
	</div>
      </template>
    </DataTimeRangePicker>
    <!-- select metric -->
    <div class="form-group ms-2 me-2 mt-3 row">
      <div class="col-4">
	<SelectSearch ref="select_search"
		      v-model:selected_option="selected_metric"
		      :options="metrics"
		      @select_option="select_metric">
	</SelectSearch>
      </div>
    </div>
    
    <div style="height:300px;">
      <Chart :id="id_chart" ref="chart"
	     :chart_type="chart_type"
      	     :register_on_status_change="false"
	     :get_custom_chart_options="get_custom_chart_options"
	     @chart_reloaded="chart_reloaded">
      </Chart>
    </div>
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

const chart = ref(null);
const date_time_picker = ref(null);
const modal_time_series = ref(null);
const select_search = ref(null);

const metrics = ref([]);
const selected_metric = ref({});

const custom_metric = {
    label: "Custom Metrics",
};

onMounted(async () => {
    init();
    select_search.value.init();
    await Promise.all([
	ntopng_sync.on_ready(id_chart),
	ntopng_sync.on_ready(id_date_time_picker),
    ]);
    chart.value.register_status();
});

async function init() {    
    metrics.value = await get_metrics();
    
    selected_metric.value = metricsManager.get_default_metric(metrics.value);
    set_last_timeseries_groups();
    
    console.log("update chart from init");
    chart.value.update_chart();
}

async function get_metrics(from_apply_modal_ts) {
    let metrics = await metricsManager.get_metrics(http_prefix);
    if (from_apply_modal_ts) {
	metrics.push(custom_metric);
    }
    return metrics;
}

let last_timeseries_groups;

function set_last_timeseries_groups() {
    last_timeseries_groups = [{
    	source_type: metricsManager.get_current_page_source_type(),
    	source: {
    	    value: metricsManager.get_default_source_value(),
    	},
    	metric: selected_metric.value,	
    }];
}

function select_metric(metric) {
    console.log(metric);
    // update modal
    modal_time_series.value.select_metric(metric);    
    // update chart
    set_last_timeseries_groups();
    console.log("update chart from select");
    chart.value.update_chart();
    // update metrics
    refresh_metrics(false);
}

const last_chart_options = ref({});
const chart_reloaded = (chart_options) => {
    last_chart_options.value = chart_options;
}

const show_manage_timeseries = () => {
    modal_time_series.value.show();
};

async function get_custom_chart_options() {
    if (last_timeseries_groups == null) {
	return {};
    }
    let timeseries_groups = last_timeseries_groups;
    
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
    let ts_chart_options = await Promise.all(ts_responses_promises);
    console.log(ts_chart_options);
    console.log(timeseries_groups);
    let chart_options = timeseriesUtils.tsArrayToApexOptions(ts_chart_options, timeseries_groups);
    // ts_chart_options.forEach((ts_options, i) => timeseriesUtils.tsToApexOptions(ts_options, timeseries_groups[i].metric));
    // console.log(ts_chart_options);

    // timeseriesUtils.mergeApexOptions(ts_chart_options, timeseries_groups);
    
    // let chart_options = ts_chart_options[0];
    // for (let i = 1; i < ts_chart_options.length; i += 1) {
    // 	chart_options.series = chart_options.series.concat(ts_chart_options[i].series);
    // }
    console.log(chart_options);
    return chart_options;
}

async function refresh_metrics(from_apply_modal_ts) {
    metrics.value = await get_metrics(from_apply_modal_ts);
    if (from_apply_modal_ts) {
	selected_metric.value = custom_metric;
    }
}

async function apply_modal_timeseries(timeseries_groups) {
    console.log("reload page by modal-timeseries");
    refresh_metrics(true);
    last_timeseries_groups = timeseries_groups;
    chart.value.update_chart();
}
      
const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
