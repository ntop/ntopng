{#
(C) 2022 - ntop.org
This template is used by the `Service Map` page inside the `Hosts` menu.
#}

<template>
   <TimeseriesChart ref="chart" :id="id" :chart_type="chart_type" :get_custom_chart_options="get_chart_options"
      :register_on_status_change="false" :disable_pointer_events="false">
   </TimeseriesChart>

</template>
<script setup>
import { ref, onMounted } from "vue";
import timeseriesUtils from "../../utilities/timeseries-utils.js";
import { default as TimeseriesChart } from "../../vue/timeseries-chart.vue";
import formatterUtils from "../../utilities/formatter-utils.js";

/* *************************************************** */

const props = defineProps({
   id: String,
   refresh_rate: Number /* Expected in milliseconds */
});

const chart = ref(null);
const chart_type = ref(ntopChartApex.typeChart.TS_LINE);
let data = [];
let is_first_update = true;
const now = Math.floor(new Date().getTime());
for (let i = 0; i < 60; i++) {
   const time = now - ((59 - i) * (props.refresh_rate))
   data.push([ time, 0, 0 ]);
}
let data2 = [...data];

const get_chart_options = function () {
   const config = timeseriesUtils.formatSimpleSerie({ serie: [] }, [i18n('sent'), i18n('rcvd')], "normal", ["bps", "bps"])
   config.data = data;
   config.colors = ['#c6d9fd', '#90ee90']
   config.axes.y = {
      axisLabelFormatter: function (value, granularity, opts, dygraph) {
         return ''
      },
      valueFormatter: function (value, granularity, opts, dygraph) {
         return formatterUtils.getFormatter('bps')(value)
      },
      pixelsPerLabel: 10,
      axisLabelWidth: 0,
   }
   config.xAxisHeight = 6;
   config.axes.x.axisLabelFormatter = function (value, granularity, opts, dygraph) {
      return ''
   };
   config.axes.x.pixelsPerLabel = 0
   config.height = 60;
   config.drawGrid = false;
   config.axisLineColor = "transparent"
   config.ylabel = ''
   config.yRangePad = 0
   return config;
}

const update = async function (url) {
   const rsp = await ntopng_utility.http_request(url);
   data.shift();
   data2.shift();
   const last_time = data2[data2.length - 1][0];
   const interval_in_sec = props.refresh_rate / 1000
   const current_time = last_time + interval_in_sec * 1000
   const bytes_sent = rsp.totBytesSent - data2[data2.length - 1][1]
   const bytes_rcvd = rsp.totBytesRcvd - data2[data2.length - 1][2]

   if (is_first_update) {
      data.push([current_time, 0, 0])
      is_first_update = false;
   } else {
      const thpt_sent = (bytes_sent * 8) / (interval_in_sec)
      const thpt_rcvd = (bytes_rcvd * 8) / (interval_in_sec)
      data.push([ current_time, (thpt_sent < 0) ? 0 : thpt_sent, (thpt_rcvd < 0) ? 0 : -thpt_rcvd ])
   }
   
   data2.push([ current_time, rsp.totBytesSent, rsp.totBytesRcvd ])
   const serie = data.map((el) => { return [el[0] /* Timestamp */, el[1] /* Value */, el[2]] })
   chart.value.update_chart_series(serie);
}

const reset = async function () {
   const now = Math.floor(new Date().getTime());
   data = [];
   for (let i = 0; i < 60; i++) {
      const time = now - ((59 - i) * (props.refresh_rate))
      data.push([ time, 0, 0 ]);
   }
   data2 = [...data];
   is_first_update = true;
   chart.value.update_chart_series(data);
}

defineExpose({ update, reset });
</script>