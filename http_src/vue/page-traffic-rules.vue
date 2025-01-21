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
          <div id="traffic_rules">
            <ModalDeleteConfirm ref="modal_delete_confirm" :title="title_delete" :body="body_delete"
              @delete="delete_row">
            </ModalDeleteConfirm>
            <ModalAddTrafficRules ref="modal_add_host_rule" :metric_list="metric_list"
              :interface_metric_list="interface_metric_list" :frequency_list="frequency_list" :init_func="init_edit"
              :has_vlans="props.context.has_vlans" :has_profiles="props.context.has_profiles" @add="add_host_rule" @edit="edit">
            </ModalAddTrafficRules>

            <Datatable ref="table_traffic_rules" :table_buttons="traffic_rules_table_config.table_buttons"
              :columns_config="traffic_rules_table_config.columns_config" :data_url="traffic_rules_table_config.data_url"
              :enable_search="traffic_rules_table_config.enable_search"
              :table_config="traffic_rules_table_config.table_config">
            </Datatable>
          </div>
        </div>
        <div class="card-footer">
          <NoteList :note_list="note_list">
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
import { default as ModalAddTrafficRules } from "./modal-add-traffic-rules.vue";
import NtopUtils from "../utilities/ntop-utils";

const props = defineProps({
    context: Object,
});

const table_traffic_rules = ref(null);
const modal_delete_confirm = ref(null);
const modal_add_host_rule = ref(null);
const _i18n = (t) => i18n(t);
const row_to_delete = ref({});
const row_to_edit = ref({});
const invalid_add = ref(false);

const metric_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=host`;
const metric_ifname_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=interface`;

const metric_host_pool_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=host_pool`;
const metric_network_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=CIDR`;
const metric_vlan_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=vlan`;
const metric_profiles_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=profiles`;

const metric_flow_exp_device_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/metrics.lua?rule_type=exporter`;
const flow_devices_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevices/list.lua`;
const flow_devices_details_url = `${http_prefix}/lua/pro/enterprise/flowdevice_details.lua`;
const host_pool_url = `${http_prefix}/lua/rest/v2/get/host/pool/pools.lua`;
const network_list_url = `${http_prefix}/lua/rest/v2/get/network/networks.lua`;
const ifid_url = `${http_prefix}/lua/rest/v2/get/ntopng/interfaces.lua`;
const vlans_url = `${http_prefix}/lua/get_vlans_data.lua`;
const profiles_url = `${http_prefix}/lua/get_traffic_profiles.lua`;
const data_url = `${http_prefix}/lua/pro/rest/v2/get/interface/traffic_rules/data.lua`;
const add_rule_url = `${http_prefix}/lua/pro/rest/v2/add/interface/traffic_rules/rule.lua`;
const remove_rule_url = `${http_prefix}/lua/pro/rest/v2/delete/interface/traffic_rules/rule.lua`;

const note_list = [
  _i18n('if_stats_config.generic_notes_1'),
  _i18n('if_stats_config.generic_notes_2'),
  _i18n('if_stats_config.generic_notes_3'),
];

const rest_params = {
  ifid: props.context.ifid,
  csrf: props.context.page_csrf,
  gui: true // Some API requires this to return html content for backward compatibility
};

let traffic_rules_table_config = {};
let title_delete = _i18n('if_stats_config.delete_traffic_rules_title');
let title_edit = _i18n('if_stats_config.edit_local_network_rules');
let body_delete = _i18n('if_stats_config.delete_traffic_rules_description');
let metric_list = [];
let interface_metric_list = [];
let host_pool_metric_list = [];
let ifid_list = [];
let flow_exporter_list = [];
let flow_exporter_metric_list = [];
let host_pool_list = [];
let network_list = [];
let network_metric_list = [];
let vlan_list = [];
let vlan_metric_list = [];
let profiles_list = [];
let profiles_metric_list = [];


const frequency_list = [
  { title: i18n('show_alerts.5_min'), label: i18n('show_alerts.5_min'), id: '5min', value: '5min' },
  { title: i18n('show_alerts.hourly'), label: i18n('show_alerts.hourly'), id: 'hour', value: 'hour' },
  { title: i18n('show_alerts.daily'), label: i18n('show_alerts.daily'), id: 'day', value: 'day' },
  { title: i18n('show_alerts.monthly'), label: i18n('show_alerts.monthly'), id: 'month', value: 'month' }
];

const show_delete_dialog = function (row) {
  row_to_delete.value = row;
  modal_delete_confirm.value.show();
};

const load_selected_field = function (row) {
  row_to_edit.value = row;

  row_to_delete.value = row;

  modal_add_host_rule.value.show(row);

};

async function edit(params) {
  //await delete_row();

  await add_host_rule(params);
};

const init_edit = function () {
  const row = row_to_edit.value;
  row_to_edit.value = null;
  return row;
};

const destroy_table = function () {
  table_traffic_rules.value.destroy_table();
};

const reload_table = function () {
  table_traffic_rules.value.reload();
};

const delete_row = async function () {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_rule_url, {
    ...rest_params,
    ...{
      rule_id: row.id,
      rule_type: row.rule_type
    }
  })

  await $.post(url, function (rsp, status) {
    reload_table();
  });
};

const add_host_rule = async function (params) {

  params.csrf = props.context.page_csrf;
  params.ifid = props.context.ifid;
  const rsp = await ntopng_utility.http_post_request(add_rule_url, params);

  invalid_add.value = rsp.rsp;

  if (invalid_add.value == false) {
    modal_add_host_rule.value.close();
    reload_table();
  } else {
    modal_add_host_rule.value.invalidAdd();
  }

};


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
};

const format_metric = function (data, rowData) {
  let metric_label = data

  if (rowData.metric_label) {
    metric_label = rowData.metric_label;
  } else {
    if (rowData.rule_type != 'interface') {
      metric_list.forEach((metric) => {
        if (metric.id == data) {
          if (rowData.extra_metric) {
            if (rowData.extra_metric == metric.extra_metric)
              metric_label = metric.label
          } else {
            metric_label = metric.label
          }
        }
      })
    } else {
      interface_metric_list.forEach((metric) => {
        if (metric.id == data) {
          if (rowData.extra_metric) {
            if (rowData.extra_metric == metric.extra_metric)
              metric_label = metric.label
          } else {
            metric_label = metric.label
          }
        }
      })
    }
  }

  return metric_label
};

const format_frequency = function (data) {
  let frequency_title = ''
  frequency_list.forEach((frequency) => {
    if (data == frequency.id)
      frequency_title = frequency.title;
  })

  return frequency_title
};

const format_threshold = function (data, rowData) {
  let formatted_data = parseInt(data);
  let threshold_sign = "> ";

  if ((rowData.threshold_sign) && (rowData.threshold_sign == '-1'))
    threshold_sign = "< "

  if ((rowData.metric_type) && (rowData.metric_type == 'throughput')) {
    formatted_data = threshold_sign + NtopUtils.bitsToSize(data)
  } else if ((rowData.metric_type) && (rowData.metric_type == 'volume')) {
    formatted_data = threshold_sign + NtopUtils.bytesToSize(data);
  } else if ((rowData.metric_type) && (rowData.metric_type.contains('percentage'))) {
    if (data < 0) {
      data = data * (-1);
    }
    formatted_data = threshold_sign + NtopUtils.fpercent(data);
  } else if ((rowData.metric_type) && (rowData.metric_type == 'value')) {
    if (data < 0) {
      data = data * (-1);
    }
    formatted_data = threshold_sign + data;
  }

  return formatted_data
};

const format_last_measurement = function (data, rowData) {
  let formatted_data = parseInt(data);
  if (rowData.target == "*") {
    return "";
  }

  if (data == null) {
    return "";
  }
  if ((rowData.metric_type) && (rowData.metric_type == 'throughput')) {
    formatted_data = NtopUtils.bitsToSize(data)
  } else if ((rowData.metric_type) && (rowData.metric_type == 'volume')) {
    formatted_data = NtopUtils.bytesToSize(data);
  } else if ((rowData.metric_type) && (rowData.metric_type.includes('percentage'))) {
    const sign_data = data < 0 ? -1 : 1;
    const absolute_value = NtopUtils.fpercent(data * sign_data);
    formatted_data = sign_data == -1 ? `<label title='${i18n("percentage_decrease")}'> (-) ${absolute_value} </label>` : `<label title='${i18n("percentage_increase")}'>${absolute_value}</label>`;
  }

  return formatted_data
};

const format_rule_type = function (data, rowData) {
  let formatted_data = '';
  if ((rowData.rule_type) && (rowData.rule_type == 'interface')) {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("interface") + " <i class='fas fa-ethernet'></i></span>"
  } else if ((rowData.rule_type) && (rowData.rule_type == 'Host')) {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("about.host_checks_directory") + " <i class='fas fa-laptop'></i></span>"
  } else if ((rowData.rule_type) && rowData.rule_type == 'host_pool') {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("alert_entities.host_pool") + " <i class='fas fa-laptop'></i></span>"

  } else if ((rowData.rule_type) && rowData.rule_type == 'CIDR') {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("network") + " <i class='fas fa-laptop'></i></span>"

  } else if ((rowData.rule_type) && (rowData.rule_type == 'exporter') && rowData.metric == "flowdev:traffic") {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("flow_exporter_device") + " <i class='fas fa-laptop'></i></span>"

  } else if ((rowData.rule_type) && (rowData.rule_type == 'exporter') && rowData.metric.includes("flowdev_port")) {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("interface_flow_exporter_device") + " <i class='fas fa-ethernet'></i></span>"
  } else if ((rowData.rule_type) && rowData.rule_type == 'vlan') {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("vlan") + " <i class='fas fa-ethernet'></i></span>"
  } else if ((rowData.rule_type) && rowData.rule_type == 'profiles') {
    formatted_data = "<span class='badge bg-secondary'>" + _i18n("if_stats_config.target_profile") + " <i class='fas fa-ethernet'></i></span>"
  }

  return formatted_data;
};

const format_target = function (data, rowData) {
  let formatted_data = '';
  if ((rowData.rule_type) && (rowData.rule_type == 'interface')) {
    formatted_data = rowData.selected_iface;
  } else if (rowData.rule_type && (rowData.rule_type == 'Host' || rowData.rule_type == 'CIDR')) {
    formatted_data = rowData.target;
  } else if (rowData.rule_type == 'host_pool') {
    formatted_data = rowData.host_pool_label;
  } else if (rowData.rule_type == 'vlan') {
    formatted_data = rowData.vlan_label;
  } else if (rowData.rule_type == 'profiles') {
    formatted_data = rowData.target;
  } else if (rowData.rule_type && rowData.rule_type == 'exporter' && rowData.metric == "flowdev:traffic") {
    formatted_data = rowData.target;
  } else {
    let interface_label = rowData.flow_exp_ifid_name != "" && rowData.flow_exp_ifid_name != null ? rowData.flow_exp_ifid_name : rowData.flow_exp_ifid;
    formatted_data = rowData.target + " " + _i18n("on_interface") + ": " + interface_label;
  }
  return formatted_data;
};

const get_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_url, rest_params)

  await $.get(url, function (rsp, status) {
    metric_list = rsp.rsp;
  });
};


const get_host_pool_list = async function () {
  const url = NtopUtils.buildURL(host_pool_url, rest_params)
  let tmp_host_pool_list;
  await $.get(url, function (rsp, status) {
    tmp_host_pool_list = rsp.rsp;
  });

  tmp_host_pool_list.sort((a, b) => (a.label > b.label) ? 1 : ((b.label > a.label) ? -1 : 0));
  host_pool_list = tmp_host_pool_list;
};

const get_network_list = async function () {
  const url = NtopUtils.buildURL(network_list_url, rest_params)

  let tmp_network_list
  await $.get(url, function (rsp, status) {
    tmp_network_list = rsp.rsp;
  });

  tmp_network_list.sort((a, b) => (a.label > b.label) ? 1 : ((b.label > a.label) ? -1 : 0));
  network_list = tmp_network_list;

};

const get_interface_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_ifname_url, rest_params)

  await $.get(url, function (rsp, status) {
    interface_metric_list = rsp.rsp;
  });

};

const get_host_pool_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_host_pool_url, rest_params)

  let tmp_host_pool_metric_list
  await $.get(url, function (rsp, status) {
    tmp_host_pool_metric_list = rsp.rsp;
  });

  tmp_host_pool_metric_list.sort((a, b) => (a.label > b.label) ? 1 : ((b.label > a.label) ? -1 : 0));
  host_pool_metric_list = tmp_host_pool_metric_list;
};


const get_network_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_network_url, rest_params)

  let tmp_network_metric_list;
  await $.get(url, function (rsp, status) {
    tmp_network_metric_list = rsp.rsp;
  });

  tmp_network_metric_list.sort((a, b) => (a.label > b.label) ? 1 : ((b.label > a.label) ? -1 : 0));
  network_metric_list = tmp_network_metric_list;

};

const get_vlan_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_vlan_url, rest_params)

  let tmp_vlan_metric_list;
  await $.get(url, function (rsp, status) {
    tmp_vlan_metric_list = rsp.rsp;
  });

  tmp_vlan_metric_list.sort((a, b) => (a.label > b.label) ? 1 : ((b.label > a.label) ? -1 : 0));
  vlan_metric_list = tmp_vlan_metric_list;

};

const get_profiles_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_profiles_url, rest_params)

  let tmp_profiles_metric_list;
  await $.get(url, function (rsp, status) {
    tmp_profiles_metric_list = rsp.rsp;
  });

  profiles_metric_list = tmp_profiles_metric_list;
}

const get_flow_exporter_devices_metric_list = async function () {
  const url = NtopUtils.buildURL(metric_flow_exp_device_url, {
    ...rest_params
  })

  await $.get(url, function (rsp, status) {
    flow_exporter_metric_list = rsp.rsp;
  });

};

const get_flow_exporter_devices_list = async function () {
  const url = NtopUtils.buildURL(flow_devices_url, {
    ...rest_params
  })

  await $.get(url, function (rsp, status) {
    flow_exporter_list = rsp.rsp;
  });

};

const get_ifid_list = async function () {
  const url = NtopUtils.buildURL(ifid_url, rest_params)

  await $.get(url, function (rsp, status) {
    ifid_list = rsp.rsp;
  });
};

const get_vlans = async function () {
  const url = NtopUtils.buildURL(vlans_url, rest_params)

  await $.get(url, function (rsp, status) {
    vlan_list = JSON.parse(rsp).data;
  });
};

const get_profiles = async function () {
  const url = NtopUtils.buildURL(profiles_url, rest_params)

  await $.get(url, function (rsp, status) {
    profiles_list = rsp.data;
  });
}

const start_datatable = function () {
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
    { columnName: _i18n("actions"), width: '5%', targets: 0, name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, render: function (_, type, rowData) { return add_action_column(rowData) } },
    { columnName: _i18n("id"), visible: false, targets: 1, name: 'id', data: 'id', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: _i18n("if_stats_config.target"), targets: 2, width: '20', name: 'target', data: 'target', className: 'text-nowrap', responsivePriority: 1, render: function (data, _, rowData) { return format_target(data, rowData) } },
    { columnName: _i18n("if_stats_config.rule_type"), targets: 3, width: '20', name: 'rule_type', data: 'rule_type', className: 'text-center', responsivePriority: 1, render: function (data, _, rowData) { return format_rule_type(data, rowData) } },
    { columnName: _i18n("if_stats_config.metric"), targets: 4, width: '10', name: 'metric', data: 'metric', className: 'text-center', responsivePriority: 1, render: function (data, _, rowData) { return format_metric(data, rowData) } },
    { columnName: _i18n("if_stats_config.frequency"), targets: 5, width: '10', name: 'frequency', data: 'frequency', className: 'text-center', responsivePriority: 1, render: function (data) { return format_frequency(data) } },
    { columnName: _i18n("if_stats_config.last_measurement"), targets: 6, width: '10', name: 'last_measurement', data: 'last_measurement', className: 'text-center', responsivePriority: 1, render: function (data, _, rowData) { return format_last_measurement(data, rowData) } },
    { columnName: _i18n("if_stats_config.threshold"), targets: 7, width: '10', name: 'threshold', data: 'threshold', className: 'text-end', responsivePriority: 1, render: function (data, _, rowData) { return format_threshold(data, rowData) } },
    { columnName: _i18n("metric_type"), visible: false, targets: 8, name: 'metric_type', data: 'metric_type', className: 'text-nowrap', responsivePriority: 1 },
  ];

  const hostRulesTableConfig = {
    table_buttons: datatableButton,
    data_url: NtopUtils.buildURL(data_url, rest_params),
    enable_search: true,
    columns_config: columns,
    table_config: {
      scrollX: false,
      serverSide: false,
      order: [[1 /* target */, 'desc']],
      columnDefs: columns
    }
  };

  traffic_rules_table_config = hostRulesTableConfig;
};

onBeforeMount(async () => {
  start_datatable();
  await get_metric_list();
  await get_ifid_list();
  await get_interface_metric_list();
  await get_flow_exporter_devices_metric_list();
  await get_flow_exporter_devices_list();
  await get_host_pool_list();
  await get_host_pool_metric_list();
  await get_network_list();
  await get_network_metric_list();
  if (props.context.has_vlans) {
    await get_vlans();
    await get_vlan_metric_list();
  }
  if (props.context.has_profiles) {
    await get_profiles();
    await get_profiles_metric_list();
  }
  modal_add_host_rule.value.metricsLoaded(metric_list, ifid_list, interface_metric_list, flow_exporter_list, flow_exporter_metric_list, props.context.page_csrf, null, null, host_pool_list, network_list, host_pool_metric_list, network_metric_list, vlan_list, vlan_metric_list, profiles_list, profiles_metric_list);
});

onUnmounted(() => {
  destroy_table();
});
</script>
