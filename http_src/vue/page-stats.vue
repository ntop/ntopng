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
    <div style="height:300px;">
      <Chart :id="id_chart" ref="chart"
      	     :get_params_url_request="get_params_url_request"
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
  @apply="reload_page"></ModalTimeseries>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as Chart } from "./chart.vue";
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as SimpleTable } from "./simple-table.vue";

import timeseriesUtils from "../utilities/timeseries-utils.js";

ntopng_utility.check_and_set_default_interval_time();

let id_chart = "chart";
let id_date_time_picker = "date_time_picker";

const chart = ref(null);
const date_time_picker = ref(null);
const modal_time_series = ref(null);

let chart_data_url = `${http_prefix}/lua/rest/v2/get/timeseries/ts.lua`;
let params_url_request = `ts_query=ifid%3A2&ts_compare=30m&version=4&zoom=30m&initial_point=true&ts_schema=iface%3Atraffic_rxtx&limit=180`;

const get_params_url_request = function(status) {
    let obj = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };
    return ntopng_url_manager.add_obj_to_url(obj, params_url_request);
};

const last_chart_options = ref({});
const chart_reloaded = (chart_options) => {
    console.log(chart_options);
    last_chart_options.value = chart_options;
}

const show_manage_timeseries = () => {
    modal_time_series.value.show();
};

let last_timeseries_groups;

async function get_custom_chart_options() {
    let timeseries_groups = last_timeseries_groups;
    if (last_timeseries_groups == null) {
	return {};
    }
    
    let status = ntopng_status_manager.get_status();
    let chart_data_url = `${http_prefix}/lua/rest/v2/get/timeseries/ts.lua`;
    let params_url_request = `ts_compare=30m&version=4&zoom=30m&initial_point=true&limit=180`;
    let params_obj = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };

    let ts_responses_promises = timeseries_groups.map((ts_group) => {
	let p_obj = {
	    ...params_obj,
	    ts_query: `${ts_group.source_type}:${ts_group.source.ifid}`,
	    ts_schema: `${ts_group.metric.schema}`,
	};
	let p_url_request =  ntopng_url_manager.add_obj_to_url(p_obj, params_url_request);
	let url = `${chart_data_url}?${p_url_request}`;
	return ntopng_utility.http_request(url);
    });
    let ts_chart_options = await Promise.all(ts_responses_promises);
    ts_chart_options.forEach((ts_options) => timeseriesUtils.tsToApexOptions(ts_options));
    console.log(ts_chart_options);
    let chart_options = ts_chart_options[0];
    for (let i = 1; i < ts_chart_options.length; i += 1) {
    	chart_options.series = chart_options.series.concat(ts_chart_options[i].series);
    }
    console.log(chart_options);
    return chart_options;
}

async function reload_page(timeseries_groups) {
    last_timeseries_groups = timeseries_groups;
    chart.value.update_chart();
}

onMounted(async () => {
    await Promise.all([
	ntopng_sync.on_ready(id_chart),
	ntopng_sync.on_ready(id_date_time_picker),
    ]);
    chart.value.register_status();
});
      
const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
