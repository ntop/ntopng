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
        <div class="mb-4">
          <h4>{{ _i18n('if_stats_config.traffic_rules') }}</h4>
        </div>
      	<div id="host_rules">
          <ModalDeleteConfirm ref="modal_delete_confirm"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_row">
          </ModalDeleteConfirm>
          <ModalAddHostRules ref="modal_add_host_rule"
            :metric_list="metric_list"
            :interface_metric_list="interface_metric_list"
            :frequency_list="frequency_list"
            :init_func="init_edit"
            @add="add_host_rule"
            @edit="edit">
          </ModalAddHostRules>
          
          <Datatable ref="table_host_rules"
            :table_buttons="host_rules_table_config.table_buttons"
            :columns_config="host_rules_table_config.columns_config"
            :data_url="host_rules_table_config.data_url"
            :enable_search="host_rules_table_config.enable_search"
            :table_config="host_rules_table_config.table_config">
          </Datatable>
        </div>
      </div>
      <div class="card-footer">
        <NoteList
        :note_list="note_list">
        </NoteList>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, onBeforeMount, onUnmounted } from "vue";
import { default as Datatable } from "./datatable.vue";
import { default as NoteList } from "./note-list.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddHostRules } from "./modal-add-host-rules.vue";
import NtopUtils from "../utilities/ntop-utils";

const props = defineProps({
  page_csrf: String,
  ifid: String,
})

const table_host_rules = ref(null)
const modal_delete_confirm = ref(null)
const modal_add_host_rule = ref(null)
const _i18n = (t) => i18n(t);
const row_to_delete = ref({})
const row_to_edit = ref({})


const metric_url = `${http_prefix}/lua/pro/rest/v2/get/interface/host_rules/host_rules_metric.lua?rule_type=host`
const metric_ifname_url = `${http_prefix}/lua/pro/rest/v2/get/interface/host_rules/host_rules_metric.lua?rule_type=interface`
const metric_flow_exp_device_url = `${http_prefix}/lua/pro/rest/v2/get/interface/host_rules/host_rules_metric.lua?rule_type=exporter`
const flow_devices_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevices/stats.lua`
const flow_devices_details_url = `${http_prefix}/lua/pro/enterprise/flowdevice_details.lua`
const ifid_url = `${http_prefix}/lua/rest/v2/get/ntopng/interfaces.lua`
const data_url = `${http_prefix}/lua/pro/rest/v2/get/interface/host_rules/host_rules_data.lua`
const add_rule_url = `${http_prefix}/lua/pro/rest/v2/add/interface/host_rules/add_host_rule.lua`
const remove_rule_url = `${http_prefix}/lua/pro/rest/v2/delete/interface/host_rules/delete_host_rule.lua`
  
const note_list = [
  _i18n('if_stats_config.generic_notes_1'),
  _i18n('if_stats_config.generic_notes_2'),
  _i18n('if_stats_config.generic_notes_3'),
]

const rest_params = {
  ifid: props.ifid,
  csrf: props.page_csrf
}

let host_rules_table_config = {}
let title_delete = _i18n('if_stats_config.delete_host_rules_title')
let title_edit = _i18n('if_stats_config.edit_local_network_rules')
let body_delete = _i18n('if_stats_config.delete_host_rules_description')
let metric_list = []
let interface_metric_list = []
let ifid_list = []
let flow_exporter_list = []
let flow_exporter_metric_list = []


const frequency_list = [
  { title: i18n('show_alerts.5_min'), label: i18n('show_alerts.5_min'), id: '5min' },
  { title: i18n('show_alerts.hourly'), label: i18n('show_alerts.hourly'), id: 'hour' },
  { title: i18n('show_alerts.daily'), label: i18n('show_alerts.daily'), id: 'day' }
]

const show_delete_dialog = function(row) {
  row_to_delete.value = row;
  modal_delete_confirm.value.show();
}

const load_selected_field = function(row) {
  row_to_edit.value = row;
  
  row_to_delete.value = row;

  modal_add_host_rule.value.show(row);

}

async function edit(params) {
  await delete_row();

  await add_host_rule(params);
}

const init_edit = function() {
  const row = row_to_edit.value;
  row_to_edit.value = null;
  return row;
}

const destroy_table = function() {
  table_host_rules.value.destroy_table();
}

const reload_table = function() {
  table_host_rules.value.reload();
}

const delete_row = async function() {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_rule_url, {
    ...rest_params,
    ...{
      rule_id: row.id,
      rule_type: row.rule_type
    }
  })
  
  await $.post(url, function(rsp, status){
    reload_table();
  });
}

const add_host_rule = async function(params) {
  const url = NtopUtils.buildURL(add_rule_url, {
    ...rest_params,
    ...params
  })
  
  await $.post(url, function(rsp, status){
    reload_table();
  });
}


const add_action_column = function (rowData) {
  let delete_handler = {
	  handlerId: "delete_host",	  
	  onClick: () => {
      show_delete_dialog(rowData);
	  },
	};

  let edit_handler = {
    handlerId: "edit_rule",
    onClick: () => {
      load_selected_field(rowData);
    },
  }
  
  return DataTableUtils.createActionButtons([
    { class: `pointer`, handler: edit_handler, icon: 'fa-edit', title: i18n('edit') },
	  { class: `pointer`, handler: delete_handler, icon: 'fa-trash', title: i18n('delete') },
	]);
}

const format_metric = function(data, rowData) {
  let metric_label = data  

  if (rowData.metric_label) {
    metric_label = rowData.metric_label;
  } else {
    if (rowData.rule_type != 'interface') {
      metric_list.forEach((metric) => {
      if(metric.id == data) {
        if(rowData.extra_metric) {
          if(rowData.extra_metric == metric.extra_metric)
            metric_label = metric.label
        } else {
          metric_label = metric.label
        }
        }
      })
    } else {
      interface_metric_list.forEach((metric) => {
      if(metric.id == data) {
        if(rowData.extra_metric) {
          if(rowData.extra_metric == metric.extra_metric)
            metric_label = metric.label
        } else {
          metric_label = metric.label
        }
        }
      })
    }
  }
  
  
  return metric_label
}

const format_frequency = function(data) {
  let frequency_title = ''
  frequency_list.forEach((frequency) => {
    if(data == frequency.id)
      frequency_title = frequency.title;
  })

  return frequency_title
}

const format_threshold = function(data, rowData) {
  let formatted_data = parseInt(data);
  let threshold_sign = "> ";

  if((rowData.threshold_sign) && (rowData.threshold_sign == '-1'))
    threshold_sign = "< "

  if((rowData.metric_type) && (rowData.metric_type == 'throughput')) {
    formatted_data = threshold_sign + NtopUtils.bitsToSize(data * 8)
  } else if((rowData.metric_type) && (rowData.metric_type == 'volume')) {
    formatted_data = threshold_sign + NtopUtils.bytesToSize(data);
  } else if((rowData.metric_type) && (rowData.metric_type == 'percentage')){
    if (data < 0) {
      data = data * (-1);
    }
    formatted_data = threshold_sign + NtopUtils.fpercent(data);
  }

  return formatted_data
}

const format_last_measurement = function(data, rowData) {
  let formatted_data = parseInt(data);
  debugger;
  if(rowData.target == "*") {
    return "";
  }

  if((rowData.metric_type) && (rowData.metric_type == 'throughput')) {
    formatted_data = NtopUtils.bitsToSize(data * 8)
  } else if((rowData.metric_type) && (rowData.metric_type == 'volume')) {
    formatted_data = NtopUtils.bytesToSize(data);
  } else if((rowData.metric_type) && (rowData.metric_type == 'percentage')){
    if (data < 0) {
      data = data * (-1);
    }
    formatted_data = NtopUtils.fpercent(data);
  }

  return formatted_data
}
const format_rule_type = function(data, rowData) {
  let formatted_data = '';
  if ((rowData.rule_type) && (rowData.rule_type == 'interface') ) {
    formatted_data = "<span class='badge bg-secondary'>"+_i18n("interface")+" <i class='fas fa-ethernet'></i></span>"
  } else if ((rowData.rule_type) && (rowData.rule_type == 'Host') ) {
    formatted_data = "<span class='badge bg-secondary'>"+_i18n("about.host_checks_directory")+" <i class='fas fa-laptop'></i></span>"
  } else if ((rowData.rule_type) && (rowData.rule_type == 'exporter') && rowData.metric == "flowdev:traffic") {
    formatted_data = "<span class='badge bg-secondary'>"+_i18n("flow_exporter_device")+" <i class='fas fa-laptop'></i></span>"

  } else if((rowData.rule_type) && (rowData.rule_type == 'exporter') && rowData.metric == "flowdev_port:traffic")
    formatted_data = "<span class='badge bg-secondary'>"+_i18n("interface_flow_exporter_device")+" <i class='fas fa-ethernet'></i></span>"

  return formatted_data;
}

const format_target = function(data, rowData) {
  let formatted_data = '';
  if ((rowData.rule_type) && (rowData.rule_type == 'interface') ) {
    formatted_data = rowData.selected_iface;
  } else if(rowData.rule_type && rowData.rule_type == 'Host') {
    formatted_data = rowData.target;
  } else if (rowData.rule_type && rowData.rule_type == 'exporter' && rowData.metric =="flowdev:traffic") {
    formatted_data = rowData.target;
  } else {
    formatted_data = rowData.target + " "+_i18n("on_interface")+": " + rowData.flow_exp_ifid_name;
  }
  return formatted_data;
}

const get_metric_list = async function() {
  const url = NtopUtils.buildURL(metric_url, rest_params)

  await $.get(url, function(rsp, status){
    metric_list = rsp.rsp;
  });
}

const get_interface_metric_list = async function() {
  const url = NtopUtils.buildURL(metric_ifname_url, rest_params)

  await $.get(url, function(rsp, status){
    interface_metric_list = rsp.rsp;
  });

}

const get_flow_exporter_devices_metric_list = async function() {
  const url = NtopUtils.buildURL(metric_flow_exp_device_url, {
    ...rest_params
  })

  await $.get(url, function(rsp, status){
    flow_exporter_metric_list = rsp.rsp;
  }); 

}

const get_flow_exporter_devices_list = async function() {
  const url = NtopUtils.buildURL(flow_devices_url, {
    ...rest_params
  })

  await $.get(url, function(rsp, status){
    flow_exporter_list = rsp.rsp;
  }); 

}

const get_ifid_list = async function() {
  const url = NtopUtils.buildURL(ifid_url, rest_params)

  await $.get(url, function(rsp, status){
    ifid_list = rsp.rsp;
  });
}

const start_datatable = function() {
  const datatableButton = [];

  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function () {
      reload_table();
    }
  }, {
    text: '<i class="fas fa-plus"></i>',
    className: 'btn-link',
    action: function () {
      modal_add_host_rule.value.show();
    }
  });
  
  const columns = [
    { columnName: _i18n("id"), visible: false, targets: 0, name: 'id', data: 'id', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: _i18n("if_stats_config.target"), targets: 1, width: '20', name: 'target', data: 'target', className: 'text-nowrap', responsivePriority: 1, render: function(data, _, rowData) {return format_target(data, rowData) } },
    { columnName: _i18n("if_stats_config.rule_type"), targets: 2, width: '20', name: 'rule_type', data: 'rule_type', className: 'text-center', responsivePriority: 1, render: function(data, _, rowData) {return format_rule_type(data, rowData) } },
    { columnName: _i18n("if_stats_config.metric"), targets: 3, width: '10', name: 'metric', data: 'metric', className: 'text-center', responsivePriority: 1, render: function(data, _, rowData) { return format_metric(data, rowData) } },
    { columnName: _i18n("if_stats_config.frequency"), targets: 4, width: '10', name: 'frequency', data: 'frequency', className: 'text-center', responsivePriority: 1, render: function(data) { return format_frequency(data) } },
    { columnName: _i18n("if_stats_config.last_measurement"), targets: 4, width: '10', name: 'last_measurement', data: 'last_measurement', className: 'text-center', responsivePriority: 1, render: function(data, _, rowData) { return format_last_measurement(data, rowData) } },
    { columnName: _i18n("if_stats_config.threshold"), targets: 5, width: '10', name: 'threshold', data: 'threshold', className: 'text-end', responsivePriority: 1, render: function(data, _, rowData) { return format_threshold(data, rowData) } },
    { columnName: _i18n("metric_type"), visible: false, targets: 6, name: 'metric_type', data: 'metric_type', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: _i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, render: function (_, type, rowData) { return add_action_column(rowData) } }
  ];

  const hostRulesTableConfig = {
    table_buttons: datatableButton,
    data_url: NtopUtils.buildURL(data_url, rest_params),
    enable_search: true,
    columns_config: columns,
    table_config: { 
      scrollX: false,
      serverSide: false, 
      order: [[ 1 /* target */, 'desc' ]],
      columnDefs: columns
    }
  };
  
  host_rules_table_config = hostRulesTableConfig;
}

onBeforeMount(async () => {
  start_datatable();
  await get_metric_list();
  await get_ifid_list();
  await get_interface_metric_list();
  await get_flow_exporter_devices_metric_list();
  await get_flow_exporter_devices_list();
  modal_add_host_rule.value.metricsLoaded(metric_list, ifid_list, interface_metric_list, flow_exporter_list, flow_exporter_metric_list, props.page_csrf);
})

onUnmounted(() => {
  destroy_table();
})
</script>






