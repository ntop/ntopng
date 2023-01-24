<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card  card-shadow">
      <Loading ref="loading"></Loading>
      <div class="card-body">
        <div id="aggregated_live_flows">          
          <Datatable ref="table_aggregated_live_flows"
            :table_buttons="table_config.table_buttons"
            :columns_config="table_config.columns_config"
            :data_url="table_config.data_url"
            :filter_buttons="table_config.table_filters"
            :enable_search="table_config.enable_search"
            :table_config="table_config.table_config">
          </Datatable>
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";
import { default as Loading } from "./loading.vue";

const loading = ref(null)
const table_config = ref({})
const table_aggregated_live_flows = ref(null);
const props = defineProps({
  vlans: Array,
  ifid: Number,
});

const _i18n = (t) => i18n(t);
const url = `${http_prefix}/lua/rest/v2/get/flow/aggregated_live_flows.lua`

const reload_table = () => {
  table_aggregated_live_flows.value.reload();
}
    
onBeforeMount(async () => {
  await start_datatable();
});

async function start_datatable() {
  const datatableButton = [];
  let params = { 
    ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,
    vlan_id: ntopng_url_manager.get_url_entry("vlan_id")
  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      reload_table();
    }
  });

  const vlan_filters = []
  
  if(props.vlans.length > 0) {
    vlan_filters.push({
      filterTitle: _i18n('map_page.vlans'),
      filters: props.vlans,
      filterMenuKey: 'vlan_id',
      columnIndex: 0,
      removeAllEntry: true,
      callbackFunction: (table, value) => {
        let params = { 
          ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid ,
          vlan_id: value.id,
        };
        ntopng_url_manager.set_key_to_url('vlan_id', value.id);
        table.ajax.url(`${url}?${ntopng_url_manager.obj_to_url_params(params)}`);
        loading.value.show_loading();
        table.ajax.reload();
        loading.value.hide_loading();
      }
    })
  }
  
  
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: `${url}?${url_params}`,
    enable_search: true,
    table_filters: vlan_filters,
    table_config: { 
      serverSide: false, 
      //order: [[ 0 /* percentage column */, 'desc' ]],
      columnDefs: [
        { type: "file-size", targets: 5 },
        { type: "file-size", targets: 6 },
        { type: "file-size", targets: 7 },
      ],
    }
  };

  let columns = [
    { 
      columnName: i18n("application_proto"), targets: 0, name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
        return `<a href="${http_prefix}/lua/flows_stats.lua?application=${data.id}" target="_blank">${data.label}</a>`
      } 
    },
  ];

  if(props.vlans.length > 0)
    columns.push({ 
      columnName: i18n("vlan"), targets: 0, name: 'vlan_id', data: 'vlan_id', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => {
        if(data.id === 0)
          return ``
        else 
          return `<a href="${http_prefix}/lua/flows_stats.lua?vlan=${data.id}" target="_blank">${data.label}</a>`
      } 
    })

  columns.push({ 
    columnName: i18n("flows"), targets: 0, name: 'flows', data: 'flows', className: 'text-nowrap text-center', responsivePriority: 1
  }, { 
    columnName: i18n("clients"), targets: 0, name: 'num_clients', data: 'num_clients', className: 'text-nowrap text-center', responsivePriority: 1
  }, { 
    columnName: i18n("servers"), targets: 0, name: 'num_servers', data: 'num_servers', className: 'text-nowrap text-center', responsivePriority: 1
  }, { 
    columnName: i18n("breakdown"), targets: 0, sorting: false, name: 'breakdown', data: 'breakdown', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => {
      return NtopUtils.createBreakdown(data.percentage_bytes_sent, data.percentage_bytes_rcvd, i18n('sent'), i18n('rcvd'));
    }
  }, { 
    columnName: i18n("traffic_sent"), targets: 0, name: 'bytes_sent', data: 'bytes_sent', className: 'text-nowrap text-end', responsivePriority: 1, render: (data) => {
      return NtopUtils.bytesToSize(data);
    }
  }, { 
    columnName: i18n("traffic_rcvd"), targets: 0, name: 'bytes_rcvd', data: 'bytes_rcvd', className: 'text-nowrap text-end', responsivePriority: 1, render: (data) => {
      return NtopUtils.bytesToSize(data);
    }
  }, { 
    columnName: i18n("total_traffic"), targets: 0, name: 'tot_traffic', data: 'tot_traffic', className: 'text-nowrap text-end', responsivePriority: 1, render: (data) => {
      return NtopUtils.bytesToSize(data);
    }
  })
  
  
  defaultDatatableConfig.columns_config = columns;
  table_config.value = defaultDatatableConfig;
}

</script>
