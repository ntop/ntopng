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
      	     :base_url_request="chart_data_url"
      	     :get_params_url_request="get_params_url_request"
      	     :chart_options_converter="chart_options_converter"
      	     :register_on_status_change="false">
      </Chart>
    </div>
  </div>
</div>
<ModalTimeseries ref="modal_time_series"></ModalTimeseries>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as Chart } from "./chart.vue";
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";

ntopng_utility.check_and_set_default_interval_time();

let id_chart = "chart";
let id_date_time_picker = "date_time_picker";

const chart = ref(null);
const date_time_picker = ref(null);
const modal_time_series = ref(null);

let chart_data_url = `${http_prefix}/lua/rest/v2/get/timeseries/ts.lua`;
let params_url_request = `ts_query=ifid%3A2&ts_compare=30m&version=4&zoom=30m&initial_point=true&ts_schema=iface%3Atraffic_rxtx&limit=180`;
let chart_options_converter = ntopChartApex.typeOptionsConverter.TS_INTERFACE;

const get_params_url_request = function(status) {
    let obj = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };
    return ntopng_url_manager.add_obj_to_url(obj, params_url_request);
};

const show_manage_timeseries = () => {
    modal_time_series.value.show();
};

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
