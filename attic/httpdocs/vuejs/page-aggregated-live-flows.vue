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
          :id="table_config.id"
          :key="table_config.data_url"
          :table_buttons="table_config.table_buttons"
          :columns_config="table_config.columns_config"
          :data_url="table_config.data_url"
          :filter_buttons="table_config.table_filters"
          :enable_search="table_config.enable_search"
          :table_config="table_config.table_config">
	    <template v-slot:menu>
	      <div class="d-flex align-items-center">
		<div class="d-flex no-wrap ms-auto" style="text-align:left;margin-right:1rem;min-width:20rem;">
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
import { ntopng_custom_events, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";
import { default as Loading } from "./loading.vue";
import { default as SelectSearch } from "./select-search.vue";

const _i18n = (t) => i18n(t);

const criteria_list_def = [
  { label: _i18n("application_proto"), value: 1, param: "application_protocol", table_id: "aggregated_app_proto", enterprise_m: false },
  { label: _i18n("client"), value: 2, param: "client", table_id: "aggregated_client", enterprise_m: false },
  { label: _i18n("server"), value: 3, param: "server", table_id: "aggregated_server", enterprise_m: false}, 
  { label: _i18n("client_server"), value: 4, param: "client_server", table_id: "aggregated_client_server", enterprise_m: true },
  { label: _i18n("application_proto_client_server"), value: 5, param: "app_client_server", table_id: "aggregated_app_client_server" , enterprise_m: true },
  { label: _i18n("info"), value: 6, param: "info", table_id: "aggregated_info", enterprise_m: true }
];

const criteria_list = get_criteria_voices();

function get_criteria_voices() {
  if(props.is_ntop_enterprise_m) {
    return ref(criteria_list_def);
  }
  else {
    let critera_list_def_com = [];
    criteria_list_def.forEach((c) => {
      if(!c.enterprise_m)
        critera_list_def_com.push(c);
    });

    return ref(critera_list_def_com);
  }
}

const selected_criteria = ref(criteria_list_def[0]);

function update_criteria() {
  ntopng_url_manager.set_key_to_url("aggregation_criteria", selected_criteria.value.param);
  url_params.aggregation_criteria = selected_criteria.value.param;
  set_datatable_config(url_params);

};


const loading = ref(null)
const table_config = ref({})
const table_aggregated_live_flows = ref(null);
let url_params = {};

const props = defineProps({
  is_ntop_enterprise_m: Boolean,
  vlans: Array,
  ifid: Number,
  aggregation_criteria: String,
  page: Number,
  sort: String,
  order: String,
  start: Number,
  length: Number

});


const format_client_name = function(data, rowData) {
  
  if(rowData.client_name.alerted) {
    rowData.client_name.complete_label = ` <i class='fas fa-exclamation-triangle' style='color: #B94A48;'></i>`+rowData.client_name.complete_label;
  }
  if(rowData.client_name.label && rowData.client_name.label != "") {

    if (!rowData.is_client_in_mem) {
      return `<label>${rowData.client_name.label }</label>`+rowData.client_name.complete_label;
    } else {
      return `<a href="${http_prefix}/lua/flows_stats.lua?client=${rowData.client_name.id}">${rowData.client_name.label}</a>`+rowData.client_name.complete_label+` <a href="${http_prefix}/lua/host_details.lua?host=${rowData.client_name.id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
    }
  } else {
    if(!rowData.is_client_in_mem)
      return `<label>${data.label}</label>`+rowData.client_name.complete_label;
    else
      return `<a href="${http_prefix}/lua/flows_stats.lua?client=${data.id}">${data.label}</a>`+rowData.client_name.complete_label+` <a href="${http_prefix}/lua/host_details.lua?host=${rowData.client_name.id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
  }
  
}

const format_server_name = function(data, rowData) {

  if(rowData.server_name.alerted) {
    rowData.server_name.complete_label = ` <i class='fas fa-exclamation-triangle' style='color: #B94A48;'></i>`+rowData.server_name.complete_label;
  }
  if(rowData.server_name.label && rowData.server_name.label != "") {
    if (!rowData.is_server_in_mem) {
      return `<label>${rowData.server_name.label }</label>`+rowData.server_name.complete_label;
    } else {
      return `<a href="${http_prefix}/lua/flows_stats.lua?server=${rowData.server_name.id}">${rowData.server_name.label}</a>`+rowData.server_name.complete_label+` <a href="${http_prefix}/lua/host_details.lua?host=${rowData.server_name.id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
    }
  } else {
    if(!rowData.is_server_in_mem)
      return `<label>${data.label}</label>`+rowData.server_name.complete_label;
    else
      return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data.id}">${data.label}</a>`+rowData.server_name.complete_label+` <a href="${http_prefix}/lua/host_details.lua?host=${rowData.server_name.id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
  }
}

const format_flows_icon = function(data, rowData) {

  let url = ``; 
  if(selected_criteria.value.value == 1)
    url = `${http_prefix}/lua/flows_stats.lua?application=${rowData.application.id}`;
  else if(selected_criteria.value.value == 2)
    url = `${http_prefix}/lua/flows_stats.lua?client=${rowData.client_name.id}`;
  else if (selected_criteria.value.value == 3)
    url = `${http_prefix}/lua/flows_stats.lua?server=${rowData.server_name.id}`;
  else if (selected_criteria.value.value == 4)
    url = `${http_prefix}/lua/flows_stats.lua?client=${rowData.client_name.id}&server=${rowData.server_name.id}`;
  else if (selected_criteria.value.value == 5)
    url = `${http_prefix}/lua/flows_stats.lua?application=${rowData.application.id}&client=${rowData.client_name.id}&server=${rowData.server_name.id}`;
  else if (selected_criteria.value.value == 6)
    url = `${http_prefix}/lua/flows_stats.lua?flow_info=${rowData.info.id}`;
  

  return `<a href=${url} class="btn btn-sm btn-info" ><i class= 'fas fa-stream'></i></a>`
}

const url = `${http_prefix}/lua/rest/v2/get/flow/aggregated_live_flows.lua`

const reload_table = () => {
  table_aggregated_live_flows.value.reload();
}
    
onBeforeMount(async () => {
  url_params = set_init_url_params();
  await set_datatable_config(url_params);
  update_url_params();
});

function set_init_url_params() {

  let actual_params = {
    ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,
    vlan_id: ntopng_url_manager.get_url_entry("vlan_id") || props.vlans ,
    aggregation_criteria: ntopng_url_manager.get_url_entry("aggregation_criteria") || selected_criteria.value.param,
    page: ntopng_url_manager.get_url_entry("page") || props.page,
    sort: ntopng_url_manager.get_url_entry("sort") || props.sort,
    order: ntopng_url_manager.get_url_entry("order") || props.order,
    start: ntopng_url_manager.get_url_entry("start") || props.start,
    length: ntopng_url_manager.get_url_entry("length") || props.length
  }

  selected_criteria.value = criteria_list_def.find((c) => c.param == actual_params.aggregation_criteria );

  for(const key in actual_params) {
    ntopng_url_manager.set_key_to_url(key, actual_params[key]);
  }  
  return actual_params;

}

function update_url_params() {
  for(const key in url_params) {
    ntopng_url_manager.set_key_to_url(key, url_params[key]);
  }  
}

async function set_datatable_config(params) {
  const datatableButton = [];

  let url_params_string = ntopng_url_manager.obj_to_url_params(params);

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
  
  let sortby = 8 // default column: Traffic rcvd

  if( selected_criteria.value.value != 1 )
    sortby = 7;
  
  if( selected_criteria.value.value == 5 )
    sortby = 10;
  
  
  let table_id = selected_criteria.value.table_id;
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: `${url}?${url_params_string}`,
    enable_search: true,
    table_filters: vlan_filters,
    id: table_id,
    table_config: { 
      serverSide: true,     
      responsive: false,
      scrollX: true,
      columnDefs: [
        { type: "file-size", targets: 6 },
        { type: "file-size", targets: 7 },
        { type: "file-size", targets: 8 },
      ]
    }
  };

  if(table_aggregated_live_flows.value == null || (table_aggregated_live_flows.value != null && !table_aggregated_live_flows.value.is_last_sorting_available(table_id)))
    defaultDatatableConfig.table_config.order = [[ sortby /* percentage column */, params.order]];

  let columns = [];

  columns.push(
    { 
      orderable: false, targets: 0, name: 'flows_icon', data: 'client', className: 'text-center', responsivePriority: 1, render: (data,_,rowData) => { 
      return format_flows_icon(data, rowData)}
    });

  if (selected_criteria.value.value == 1) {
    
    // application protocol case
    columns.push(
      { 
        columnName: i18n("application_proto"), targets: 0, name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
          return `<label>${data.complete_label}</label>`
        } 
      })
  } 
  else if (selected_criteria.value.value == 2) {

    
    // client case
    columns.push(
      { 
        columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
          
          return format_client_name(data, rowData)}
      })
  } 
  else if (selected_criteria.value.value == 3) {
    // server case
    columns.push(
      { 
        columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
        return format_server_name(data, rowData)}         
      })
  } 
  else if (props.is_ntop_enterprise_m) {
    if(selected_criteria.value.value == 4) {
      columns.push(
        { 
          columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
          return format_client_name(data, rowData)}
        },{ 
          columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
          return format_server_name(data, rowData)}         
        })
    } else if(selected_criteria.value.value == 5) {
      columns.push(
        { 
          columnName: i18n("application_proto"), targets: 0, name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
            return `<label>${data.complete_label}</label>`}
        },{ 
          columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
          return format_client_name(data, rowData)}
        },{ 
          columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data,_,rowData) => {
          return format_server_name(data, rowData)}         
        });
    } else if(selected_criteria.value.value == 6) {
      columns.push(
        { 
          columnName: i18n("info"), targets: 0, name: 'info', data: 'info', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
            return `<label>${data.label}</label>`}
        });
    }
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

    if(sortby > 1)
      sortby = sortby + 1

    if(table_aggregated_live_flows.value == null || (table_aggregated_live_flows.value != null && !table_aggregated_live_flows.value.is_last_sorting_available(table_id)))
      defaultDatatableConfig.table_config.order = [[ sortby /* percentage column */, params.order]];
    
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
  });
  
  if(selected_criteria.value.value != 2 && selected_criteria.value.value != 4)
    columns.push({columnName: i18n("clients"), targets: 0, name: 'num_clients', data: 'num_clients', className: 'text-nowrap text-center', responsivePriority: 1});
  
  if(selected_criteria.value.value != 3 && selected_criteria.value.value != 4) 
    columns.push({columnName: i18n("servers"), targets: 0, name: 'num_servers', data: 'num_servers', className: 'text-nowrap text-center', responsivePriority: 1})
  
  columns.push({ 
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
  });
  
  
  defaultDatatableConfig.columns_config = columns;
  table_config.value = defaultDatatableConfig;
}

</script>
