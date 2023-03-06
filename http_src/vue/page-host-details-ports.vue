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
          <div id="host_details_ports">
            <div class="row mb-4 mt-4" id="host_details_ports">
              <template v-for="table_option in table_options">
                <div class="col-6">
                  <BootstrapTable
                    :id="table_option.id"
                    :columns="table_option.columns"
                    :rows="table_option.stats_rows"
                    :print_html_column="(col) => print_stats_column(col)"
                    :print_html_row="(col, row) => print_stats_row(col, row)">
                  </BootstrapTable>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
  
<script setup>
import { ref, onUnmounted, onBeforeMount, computed, watch, onMounted } from "vue";
import { default as Chart } from "./chart.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { ntopng_events_manager, ntopng_url_manager, ntopng_utility } from '../services/context/ntopng_globals_services';
import NtopUtils from "../utilities/ntop-utils";

const ports_table = ref(null);
const charts = ref([]);
const config_traffic_table = ref({});

const _i18n = (t) => i18n(t);
const props = defineProps({
  page_csrf: String,
})

const get_f_get_custom_chart_options = () => {
  console.log("get_f_");
  return async (url) => {
    return charts_options_items.value[chart_index].chart_options;
  }
}

function print_stats_column(col) {
  return col.label;
}

function print_stats_row(col, row) {
  debugger;
  let label = row.label;
  return label;
}

const destroy = () => {
  traffic_table.value.destroy_table();
}

const reload_table = () => {
  traffic_table.value.reload();
}
    
onBeforeMount(async () => {
  await start_datatable();
});

onMounted(async () => {
  NtopUtils.hideOverlays();
})

onUnmounted(async () => {
  destroy()
});

const chart_options = [
  {
    title: i18n('graphs.cli_ports'),
    type: ntopChartApex.typeChart.DONUT,
    url: `${http_prefix}/lua/rest/v2/get/host/port/cli_port_data.lua`,
    id: `cli_port_flows`,
  },
  {
    title: i18n('graphs.srv_ports'),
    type: ntopChartApex.typeChart.DONUT,
    url: `${http_prefix}/lua/rest/v2/get/host/port/srv_port_data.lua`,
    id: `srv_port_flows`,
  },
]

const table_options = [
  {
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `cli_port_flows`,
    extra_params: {
      mode: 'local',
      protocol: 'tcp'
    },
    columns: [
      { id: "active_server_tcp_ports", label: _i18n("ports_page.active_server_tcp_ports") },
      { id: "port_application", label: _i18n("port") },
    ],
    stats_rows: [],
  },
  {
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `cli_port_flows`,
    extra_params: {
      mode: 'local',
      protocol: 'udp'
    },
    columns: [
      { id: "active_server_udp_ports", label: _i18n("ports_page.active_server_udp_ports") },
      { id: "port_application", label: _i18n("port") },
    ],
    stats_rows: [],
  },
  {
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `srv_port_flows`,
    extra_params: {
      mode: 'remote',
      protocol: 'tcp'
    },
    columns: [
      { id: "client_contacted_server_tcp_ports", label: _i18n("ports_page.client_contacted_server_tcp_ports") },
      { id: "port_application", label: _i18n("port") },
    ],
    stats_rows: [],
  },
  {
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `srv_port_flows`,
    extra_params: {
      mode: 'remote',
      protocol: 'udp'
    },
    columns: [
      { id: "client_contacted_server_udp_ports", label: _i18n("ports_page.client_contacted_server_udp_ports") },
      { id: "port_application", label: _i18n("port") },
    ],
    stats_rows: [],
  },
]

async function start_datatable() {
  let url_params = {}
  
  url_params["host"] = ntopng_url_manager.get_url_entry("host")
  url_params["vlan"] = ntopng_url_manager.get_url_entry("vlan")
  url_params["ifid"] = ntopng_url_manager.get_url_entry("ifid")
    
  table_options.forEach((table) => {
    let tmp_params = {
      ...table.extra_params,
      ...url_params,
    }

    $.get(NtopUtils.buildURL(table.url, tmp_params), async function(data, status){
      debugger;
      let rows = []
      data.rsp.forEach((data) => {
        const port = data.port_info.port
        const proto = data.port_info.l7_proto
        rows.push({ label: `${port} (${proto})` })
      })
      table.stats_rows = rows;
    });
  })
}
</script>






