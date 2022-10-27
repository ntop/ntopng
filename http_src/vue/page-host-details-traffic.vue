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
      	<div id="host_details_traffic">
          <div class="row mb-4 mt-4" id="host_details_traffic">
            <template v-for="chart_option in chart_options">
              <div class="col-4">
                <h3 class="widget-name">{{ chart_option.title }}</h3>
                <Chart
                  :id="chart_option.id"
                  :chart_type="chart_option.type"
                  :base_url_request="chart_option.url"
                  :register_on_status_change="false">
                </Chart>
              </div>
            </template>
          </div>
          
          <Datatable ref="traffic_table"
            :table_buttons="config_traffic_table.table_buttons"
            :columns_config="config_traffic_table.columns_config"
            :data_url="config_traffic_table.data_url"
            :enable_search="config_traffic_table.enable_search"
            :table_config="config_traffic_table.table_config">
          </Datatable>
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

const traffic_table = ref(null);
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
  traffic_table.value.destroy_table();
}
    
onBeforeMount(async () => {
  start_datatable();
});

onUnmounted(async () => {
  destroy()
});

const chart_options = [
  {
    title: i18n('graphs.l4_proto'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/l4/proto_data.lua`,
    id: `traffic_protos`,
  },
  {
    title: i18n('graphs.contacted_hosts'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/l4/contacted_hosts_data.lua`,
    id: `contacted_hosts`,
  },
  {
    title: i18n('graphs.traffic'),
    type: ntopChartApex.typeChart.PIE,
    url: `${http_prefix}/lua/rest/v2/get/host/l4/traffic_data.lua`,
    id: `traffic`,
  },
]

function start_datatable(PageVue) {
  const datatableButton = [];
  let url_params = {}
  
  url_params["host"] = ntopng_url_manager.get_url_entry("host")
  url_params["vlan"] = ntopng_url_manager.get_url_entry("vlan")
  url_params["ifid"] = ntopng_url_manager.get_url_entry("ifid")

  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      traffic_table.value.reload_table();
    }
  });
    
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/host/stats/l4_traffic.lua`, url_params),
    enable_search: true,
    table_config: { 
      serverSide: false, 
      order: [[ 6 /* percentage column */, 'desc' ]],
      columnDefs: [
        { type: "time-uni", targets: 1 },
        { type: "file-size", targets: 2 },
        { type: "file-size", targets: 3 },
        { type: "file-size", targets: 5 },
      ]
    }
  };
  
  /* Applications table configuration */  

  let columns = [
    { columnName: i18n("protocol"), targets: 0, width: '10', name: 'protocol', data: 'protocol', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("chart"), targets: 1, width: '10', name: 'historical', data: 'historical', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("traffic_labels.bytes_sent"), targets: 2, width: '10', name: 'sent', data: 'bytesSent', className: 'text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }  
    },
    { columnName: i18n("traffic_labels.bytes_rcvd"), targets: 3, width: '10', name: 'rcvd', data: 'bytesRcvd',  className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }  
    },
    { columnName: i18n("traffic_labels.breakdown"), targets: 4, width: '20', name: 'breakdown', data: 'breakdown', orderable: false, className: 'text-center text-nowrap', responsivePriority: 2, render: (data, type, row) => {
        const percentage_sent = (row.bytes_sent * 100) / row.tot_bytes;
        const percentage_rcvd = (row.bytes_rcvd * 100) / row.tot_bytes;
        return NtopUtils.createBreakdown(percentage_sent, percentage_rcvd, i18n('host_details.sent'), i18n('host_details.rcvd'));
      }  
    },
    { columnName: i18n("traffic_labels.total_bytes"), targets: 5, width: '20', name: 'tot_bytes', data: 'totalBytes', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }   
    },
    { columnName: i18n("traffic_labels.total_percentage"), targets: 6, width: '20', name: 'percentage', data: 'totalPctg',  className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        const percentage = data.toFixed(1);
        return NtopUtils.createProgressBar(percentage);
      }  
    },
  ];

  let trafficConfig = ntopng_utility.clone(defaultDatatableConfig);
  trafficConfig.columns_config = columns;
  config_traffic_table.value = trafficConfig;
}
</script>






