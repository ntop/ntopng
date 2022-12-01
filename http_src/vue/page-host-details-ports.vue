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
              <template v-for="chart_option in chart_options">
                <div class="col-6 mb-3">
                  <h3 class="widget-name">{{ chart_option.title }}</h3>
                  <Chart
                    :id="chart_option.id"
                    :chart_type="chart_option.type"
                    :base_url_request="chart_option.url"
                    :register_on_status_change="false">
                  </Chart>
                </div>
              </template>

              <template v-for="table_option in table_options">
                <div class="col-3 mt-5">
                  <h3 class="widget-name">{{ table_option.title }}</h3>
                  <Datatable 
                    :id="table_option.id"
                    :columns_config="table_option.config.columns_config"
                    :data_url="table_option.config.data_url"
                    :enable_search="table_option.config.enable_search"
                    :table_config="table_option.config.table_config">
                  </Datatable>
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
import { ref, onUnmounted, onBeforeMount, computed, watch } from "vue";
import { default as Chart } from "./chart.vue";
import { default as Datatable } from "./datatable.vue";
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';

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

const destroy = () => {
  traffic_table.value.destroy_table();
}

const reload_table = () => {
  traffic_table.value.reload();
}
    
onBeforeMount(async () => {
  start_datatable();
});

onUnmounted(async () => {
  destroy()
});

const chart_options = [
  {
    title: i18n('graphs.cli_ports'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/port/cli_port_data.lua`,
    id: `cli_port_flows`,
  },
  {
    title: i18n('graphs.srv_ports'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/port/srv_port_data.lua`,
    id: `srv_port_flows`,
  },
]

const table_options = [
  {
    title: i18n('ports_page.active_server_tcp_ports'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `cli_port_flows`,
    extra_params: {
      mode: 'local',
      protocol: 'tcp'
    },
    columns: [
      { columnName: i18n("port_application"), targets: 1, orderable: false, width: '10', data: 'port_info', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => { 
          return `<a href="/lua/flows_stats.lua?port=${data.port}">${data.port} (${data.l7_proto})</a>`
        } 
      },
      { visible: false }
    ]
  },
  {
    title: i18n('ports_page.active_server_udp_ports'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `cli_port_flows`,
    extra_params: {
      mode: 'local',
      protocol: 'udp'
    },
    columns: [
      { columnName: i18n("port_application"), targets: 1, orderable: false, width: '10', data: 'port_info', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => { 
          return `<a href="/lua/flows_stats.lua?port=${data.port}">${data.port} (${data.l7_proto})</a>`
        } 
      },
      { visible: false }
    ]
  },
  {
    title: i18n('ports_page.client_contacted_server_tcp_ports'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `srv_port_flows`,
    extra_params: {
      mode: 'remote',
      protocol: 'tcp'
    },
    columns: [
      { columnName: i18n("port_application"), targets: 1, orderable: false, width: '10', data: 'port_info', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => { 
          return `<a href="/lua/flows_stats.lua?port=${data.port}">${data.port} (${data.l7_proto})</a>`
        } 
      },
      { visible: false }
    ]
  },
  {
    title: i18n('ports_page.client_contacted_server_udp_ports'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/port/table_port_data.lua`,
    id: `srv_port_flows`,
    extra_params: {
      mode: 'remote',
      protocol: 'udp'
    },
    columns: [
      { columnName: i18n("port_application"), targets: 1, orderable: false, width: '10', data: 'port_info', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => { 
          return `<a href="/lua/flows_stats.lua?port=${data.port}">${data.port} (${data.l7_proto})</a>`
        } 
      },
      { visible: false }
    ]
  },
]

function start_datatable() {
  let url_params = {}
  
  url_params["host"] = ntopng_url_manager.get_url_entry("host")
  url_params["vlan"] = ntopng_url_manager.get_url_entry("vlan")
  url_params["ifid"] = ntopng_url_manager.get_url_entry("ifid")
    
  table_options.forEach((table) => {
    let tmp_params = {
      ...table.extra_params,
      ...url_params,
    }

    table.config = {
      table_buttons: {},
      data_url: NtopUtils.buildURL(table.url, tmp_params),
      enable_search: false,
      table_config: { 
        scrollX: false,
        serverSide: false, 
        columnDefs: table.columns
      },
      columns_config: table.columns
    };
  })
}
</script>






