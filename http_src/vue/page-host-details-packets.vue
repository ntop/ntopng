<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card">
        <div class="card-body">
          <MultiPieChart :context="pie_charts_context" />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, computed } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import MultiPieChart from "./charts/multi-pie-chart.vue";

const props = defineProps({
  context: Object,
});

const _i18n = (t) => i18n(t);

const url_params = {
  host: ntopng_url_manager.get_url_entry("host") || '',
  vlan: ntopng_url_manager.get_url_entry("vlan") || '',
  ifid: ntopng_url_manager.get_url_entry("ifid") || '',
};

const pie_charts_context = computed(() => ({
  charts_per_row: 2,
  charts: [
    {
      name:       'packets_sent',
      title:      i18n('graphs.packets_sent'),
      update_url: `${http_prefix}/lua/rest/v2/get/host/packets/sent_data.lua`,
      url_params,
      unit : 'number'
    },
    {
      name:       'packets_rcvd',
      title:      i18n('graphs.packets_rcvd'),
      update_url: `${http_prefix}/lua/rest/v2/get/host/packets/rcvd_data.lua`,
      url_params,
      unit : 'number'
    },
    {
      name:       'tcp_flags',
      title:      i18n('graphs.tcp_flags'),
      update_url: `${http_prefix}/lua/rest/v2/get/host/packets/tcp_flags_data.lua`,
      url_params,
      unit : 'number'
    },
    {
      name:       'arp_requests',
      title:      i18n('graphs.arp_distribution'),
      update_url: `${http_prefix}/lua/rest/v2/get/host/packets/arp_data.lua`,
      url_params,
      unit : 'number'
    },
  ],
}));


function chart_done(data, tmp, tmp2) {
  NtopUtils.hideOverlays()
}

onMounted(() => { })

</script>
