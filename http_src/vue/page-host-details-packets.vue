<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card">
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
        <div class="row">
          <template v-for="chart_option in chart_options">
            <div class="col-6 mb-4 mt-4">
              <h3 class="widget-name">{{ chart_option.title }}</h3>
              <Chart
                :id="chart_option.id"
                :chart_type="chart_option.type"
                :base_url_request="chart_option.url"
                :register_on_status_change="false"
                @chart_reloaded="chart_done">
              </Chart>
            </div>
          </template>
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { onMounted } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import { default as Chart } from "./chart.vue";

const props = defineProps({
  page_csrf: String,
  url_params: Object,
})

const _i18n = (t) => i18n(t);
const chart_options = [
  {
    title: i18n('graphs.packets_sent'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/packets/sent_data.lua`,
    id: `packets_sent`,
  },
  {
    title: i18n('graphs.packets_rcvd'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/packets/rcvd_data.lua`,
    id: `packets_rcvd`,
  },
  {
    title: i18n('graphs.tcp_flags'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/packets/tcp_flags_data.lua`,
    id: `tcp_flags`,
  },
  {
    title: i18n('graphs.arp_distribution'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/packets/arp_data.lua`,
    id: `arp_requests`,
  },
]

function chart_done(data, tmp, tmp2) {
  NtopUtils.hideOverlays()
}

onMounted(() => {})

</script>






