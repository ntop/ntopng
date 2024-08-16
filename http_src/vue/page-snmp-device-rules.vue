<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <ModalDeleteConfirm ref="modal_delete_confirm" :title="title_delete" :body="body_delete" @delete="delete_row">
    </ModalDeleteConfirm>
    <ModalAddSNMPRules ref="modal_add_snmp_device_rule" :frequency_list="frequency_list" :init_func="init_edit"
      @add="add_host_rule" @edit="edit">
    </ModalAddSNMPRules>
    <div class="col-md-12 col-lg-12">
      <div v-if="!context.is_check_enabled" class="alert alert-warning alert-dismissable">
        <span class="text-warning me-1"></span>
        <span> {{ active_alert_text }}</span>
      </div>
      <div class="card">
        <div class="card-body">
          <div class="m-2 mb-3">
            <TableWithConfig ref="table_snmp_rules" :table_id="table_id" :csrf="context.csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
              <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" ref="add_host" @click="open_add_host_rule_modal">
                  <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
                    :title="_i18n('add_vs_host')"></i>
                </button>
              </template>
            </TableWithConfig>
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
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NoteList } from "./note-list.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddSNMPRules } from "./modal-add-snmp-device-rules.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";

const props = defineProps({
  context: Object,
});

const context = ref({
  csrf: props.context.csrf,
  ifid: props.context.ifid,
  is_check_enabled: props.context.is_check_enabled
});

const table_host_rules = ref(null)
const modal_delete_confirm = ref(null)
const modal_add_snmp_device_rule = ref(null)
const _i18n = (t) => i18n(t);
const row_to_delete = ref({})
const row_to_edit = ref({})

const snmp_metric_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/metric/rule_metrics.lua`
const snmp_devices_url = `${http_prefix}/lua/pro/enterprise/get_snmp_devices_list.lua`

const add_rule_url = `${http_prefix}/lua/pro/rest/v2/add/snmp/device/rule.lua`
const remove_rule_url = `${http_prefix}/lua/pro/rest/v2/delete/snmp/device/rule.lua`
const table_snmp_rules = ref();
const table_id = ref("snmp_device_rules");

const note_list = [
  _i18n('if_stats_config.generic_notes_1'),
  _i18n('if_stats_config.generic_notes_2'),
  _i18n('if_stats_config.generic_notes_3'),
]

const rest_params = {
  ifid: context.value.ifid,
  csrf: context.value.csrf,
}

let title_delete = _i18n('if_stats_config.delete_host_rules_title')
let body_delete = _i18n('if_stats_config.delete_host_rules_description')
const active_alert_text = _i18n('snmp.snmp_devices_rules_active_alert_warning')
let snmp_metric_list = []
let snmp_devices_list = []


const frequency_list = [
  { title: i18n('show_alerts.5_min'), label: i18n('show_alerts.5_min'), id: '5min' },
  { title: i18n('show_alerts.hourly'), label: i18n('show_alerts.hourly'), id: 'hour' },
  { title: i18n('show_alerts.daily'), label: i18n('show_alerts.daily'), id: 'day' }
]

/* ******************************************************************** */

const click_button_delete = function (row) {
  row_to_delete.value = row;
  modal_delete_confirm.value.show();
}

/* ******************************************************************** */

const click_button_edit = function (row) {
  row_to_edit.value = row;
  row_to_delete.value = row;
  modal_add_snmp_device_rule.value.show(row);
}

/* ******************************************************************** */

const get_snmp_metric_list = async function () {
  const url = NtopUtils.buildURL(snmp_metric_url, rest_params)

  await $.get(url, function (rsp, status) {
    snmp_metric_list = rsp.rsp;
  });
}

/* ******************************************************************** */

const get_snmp_devices_list = async function () {
  rest_params.verbose = true
  const url = NtopUtils.buildURL(snmp_devices_url, rest_params)
  await $.get(url, function (rsp, status) {
    snmp_devices_list = rsp.rsp;
  });
  snmp_devices_list.push({ column_key: "*", column_name: "all" })
}

/* ******************************************************************** */

const format_threshold = function (data, row) {
  let threshold;
  let formatted_data;

  (data.sign && data.sign == '-1') ?
    threshold = "<" : threshold = ">"

  if (row.metric.type == 'volume') {
    formatted_data = formatterUtils.getFormatter("bytes")(data.value);
  } else if (row.metric.type == 'throughput') {
    formatted_data = formatterUtils.getFormatter("bps_no_scale")(data.value);
  } else {
    formatted_data = formatterUtils.getFormatter("percentage")(data.value);
  }

  return `${threshold} ${formatted_data}`
}

/* ******************************************************************** */

/* Function to map columns data */
const map_table_def_columns = (columns) => {
  let map_columns = {
    "device": (data, row) => {
      return data.label;
    },
    "interface": (data, row) => {
      return data.label;
    },
    "metric": (data, row) => {
      return data.label;
    },
    "frequency": (data, row) => {
      return frequency_list.find((el) => el.id == data).label;
    },
    "threshold": (data, row) => {
      return format_threshold(data, row);
    },
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
    if (c.id == "actions") {
      const visible_dict = {
        edit_rule: true,
        delete_host: true,
      };
      c.button_def_array.forEach((b) => {
        if (!visible_dict[b.id]) {
          b.class.push("disabled");
        }
      });
    }
  });

  return columns;
};

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_edit": click_button_edit,
    "click_button_delete": click_button_delete,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ******************************************** */

/* Function used to sort the columns of the table */
function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = column_data(col, r0);
    let r1_col = column_data(col, r1);

    if (col.id == "device") {
      return sortingFunctions.sortByName(r0_col.label, r1_col.label, col.sort);
    } else if (col.id == "interface") {
      return sortingFunctions.sortByName(r0_col.label, r1_col.label, col.sort);
    } else if (col.id == "metric") {
      return sortingFunctions.sortByName(r0_col.label, r1_col.label, col.sort);
    } else if (col.id == "frequency") {
      return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
    } else if (col.id == "threshold") {
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col.value, r1_col.value, col.sort);
    }
  }
}

/* ******************************************************************** */

const open_add_host_rule_modal = function() {
  modal_add_snmp_device_rule.value.show();
}

/* ******************************************************************** */

const reload_table = function () {
  table_snmp_rules.value.refresh_table();
}

/* ******************************************************************** */

const delete_row = async function () {
  const row = row_to_delete.value.row;
  const url = NtopUtils.buildURL(remove_rule_url, {
    ...rest_params,
    ...{
      rule_id: row.id,
    }
  })

  await $.post(url, function (rsp, status) {
    reload_table();
  });
}

/* ******************************************************************** */

async function edit(params) {
  await delete_row();
  await add_host_rule(params);
}

/* ******************************************************************** */

const init_edit = function () {
  const row = row_to_edit.value;
  row_to_edit.value = null;
  return row;
}

/* ******************************************************************** */

const add_host_rule = async function (params) {
  const url = NtopUtils.buildURL(add_rule_url, {
    ...rest_params,
    ...params
  })

  await $.post(url, function (rsp, status) {
    reload_table();
  });
}

/* ******************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ******************************************** */

onBeforeMount(async () => {
  await get_snmp_metric_list();
  await get_snmp_devices_list();
  modal_add_snmp_device_rule.value.metricsLoaded(snmp_devices_list, snmp_metric_list, context.csrf);
})
</script>
