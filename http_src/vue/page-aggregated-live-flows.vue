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
          <Datatable ref="table_aggregated_live_flows" :key="table_config.data_url"
		     :table_buttons="table_config.table_buttons"
		     :columns_config="table_config.columns_config"
		     :data_url="table_config.data_url"
		     :filter_buttons="table_config.table_filters"
		     :enable_search="table_config.enable_search"
		     :table_config="table_config.table_config">
	    <template v-slot:menu>
	      <div class="d-flex align-items-center">
		<div class="d-flex no-wrap ms-auto" style="text-align:left;margin-right:1rem">
      <label class="my-auto me-1">{{ _i18n('criteria_filter') }}: </label>
		  <SelectSearch v-model:selected_option="selected_criteria"
				:options="criteria_list"
				@select_option="update_criteria">
		  </SelectSearch>
		</div>
	      </div>
	      
	    </template>
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
import { default as SelectSearch } from "./select-search.vue";

const _i18n = (t) => i18n(t);

const criteria_list_def = [
  { label: _i18n("application_proto"), value: 1, param: "application_protocol" },
  { label: _i18n("client"), value: 2, param: "client" },
  { label: _i18n("server"), value: 3, param: "server" },
  { label: _i18n("client_server"), value: 4, param: "client_server" }
];

const criteria_list = ref(criteria_list_def);

const selected_criteria = ref(criteria_list_def[0]);

function update_criteria() {
    set_datatable_config();
};


const loading = ref(null)
const table_config = ref({})
const table_aggregated_live_flows = ref(null);
const props = defineProps({
  vlans: Array,
  ifid: Number,
});


const format_client_name = function(data, rowData) {

  if(rowData.client_name.label && rowData.client_name.label != "") {

    if (!rowData.is_client_in_mem) {
      return `<label>${rowData.client_name.label }</label>`+rowData.client_name.complete_label;
    } else {
      return `<a href="${http_prefix}/lua/host_details.lua?host=${rowData.client_name.id}">${rowData.client_name.label}</a>`+rowData.client_name.complete_label;
    }
  } else {
    if(!rowData.is_client_in_mem)
      return `<label>${data.label}</label>`+rowData.client_name.complete_label;
    else
      return `<a href="${http_prefix}/lua/host_details.lua?host=${data.id}">${data.label}</a>`+rowData.client_name.complete_label;
  }
  
}

const format_server_name = function(data, rowData) {
  if(rowData.server_name.label && rowData.server_name.label != "") {
    if (!rowData.is_server_in_mem) {
      return `<label>${rowData.server_name.label }</label>`+rowData.server_name.complete_label;
    } else {
      return `<a href="${http_prefix}/lua/host_details.lua?host=${rowData.server_name.id}">${rowData.server_name.label}</a>`+rowData.server_name.complete_label;
    }
  } else {
    if(!rowData.is_server_in_mem)
      return `<label>${data.label}</label>`+rowData.server_name.complete_label;
    else
      return `<a href="${http_prefix}/lua/host_details.lua?host=${data.id}">${data.label}</a>`+rowData.server_name.complete_label;
  }
}

const format_flows_icon = function(data, rowData) {
  let url = ``; 
  if(selected_criteria.value.value == 2)
    url = `${http_prefix}/lua/host_details.lua?page=flows&host=${rowData.client_name.id}`;
  else if (selected_criteria.value.value == 3)
    url = `${http_prefix}/lua/host_details.lua?page=flows&host=${rowData.server_name.id}`;
  else if (selected_criteria.value.value == 4)
    url = `${http_prefix}/lua/host_details.lua?page=flows&host=${rowData.client_name.id}&talking_with=${rowData.server_name.id}`;
  
  return `<a href=${url} class="btn btn-sm btn-info" ><i class= 'fas fa-stream'></i></a>`
}

const url = `${http_prefix}/lua/rest/v2/get/flow/aggregated_live_flows.lua`

const reload_table = () => {
  table_aggregated_live_flows.value.reload();
}
    
onBeforeMount(async () => {
  await set_datatable_config();
});

async function set_datatable_config() {
  const datatableButton = [];
 
  let params = { 
    ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,
    vlan_id: ntopng_url_manager.get_url_entry("vlan_id"),
    aggregation_criteria: selected_criteria.value.param

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
        if(value.id != 0) {
          let params = { 
            ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,
            vlan_id: value.id,
            aggregation_criteria: selected_criteria.value.param
          };
          ntopng_url_manager.set_key_to_url('vlan_id', value.id);
          table.ajax.url(`${url}?${ntopng_url_manager.obj_to_url_params(params)}`);
          loading.value.show_loading();
          table.ajax.reload();
          loading.value.hide_loading();
        }
        
      }
    })
  }
  
  
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: `${url}?${url_params}`,
    enable_search: true,
    table_filters: vlan_filters,
    table_config: { 
      serverSide: true,     
      responsive: false,
      scrollX: true,
      order: [[ 8 /* percentage column */, 'desc' ]],
      columnDefs: [
        { type: "file-size", targets: 6 },
        { type: "file-size", targets: 7 },
        { type: "file-size", targets: 8 },
      ]
    }
  };

  let columns = [];
  if (selected_criteria.value.value == 1) {
    
    // application protocol case
    columns.push(
      { 
        columnName: i18n("application_proto"), targets: 0, name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
          return `<a href="${http_prefix}/lua/flows_stats.lua?application=${data.id}">${data.label}</a>`
        } 
      })
  } 
  else if (selected_criteria.value.value == 2 ) {

    
    // client case
    columns.push(
      { 
        orderable: false, targets: 0, name: 'flows_icon', data: 'client', className: 'text-center', responsivePriority: 1, render: (data,_,rowData) => { 
        return format_flows_icon(data, rowData)}
      }
      ,{ 
        columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
          
          return format_client_name(data, rowData)}
      })
  } 
  else if (selected_criteria.value.value == 3 ) {
    // server case
    columns.push(
      { 
        orderable: false, targets: 0, name: 'flows_icon', data: 'client', className: 'text-nowrap text-center', responsivePriority: 1, render: (data,_,rowData) => { 
        return format_flows_icon(data, rowData)}
      }
      ,{ 
        columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
        return format_server_name(data, rowData)}         
      })
  } 
  else if(selected_criteria.value.value == 4) {
    columns.push(
      { 
        orderable: false, targets: 0, name: 'flows_icon', data: 'client', className: 'text-nowrap text-center', responsivePriority: 1, render: (data,_,rowData) => { 
        return format_flows_icon(data, rowData)}
      }
      ,{ 
        columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
        return format_client_name(data, rowData)}
      },{ 
        columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
        return format_server_name(data, rowData)}         
      })
  }
  
  if(props.vlans.length > 0) {
    columns.push({ 
      columnName: i18n("vlan"), targets: 0, name: 'vlan_id', data: 'vlan_id', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => {
        if(data.id === 0)
          return ``
        else 
          return `<a href="${http_prefix}/lua/flows_stats.lua?vlan=${data.id}">${data.label}</a>`
      } 
    })

    defaultDatatableConfig.table_config.order = [[ 8 /* percentage column */, 'desc' ]];
    defaultDatatableConfig.table_config.columnDefs = [
      { type: "file-size", targets: 7 },
      { type: "file-size", targets: 8 },
      { type: "file-size", targets: 9 },
    ];
  }

  columns.push({ 
    columnName: i18n("flows"), targets: 0, name: 'flows', data: 'flows', className: 'text-nowrap text-center', responsivePriority: 1
  }, { 
    columnName: i18n("total_score"), targets: 0, name: 'score', data: 'tot_score', className: 'text-nowrap text-center', responsivePriority: 1
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
