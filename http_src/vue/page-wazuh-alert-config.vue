<!-- (C) 2026 - ntop.org -->
<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card">
        <div class="card-body">
          <ModalDeleteConfirm ref="modal_delete_confirm" :title="delete_title" :body="delete_body"
            @delete="delete_row" />

          <ModalAddWazuhAlertRule ref="modal_add_rule" :context="props.context"
            :url_request="rule_urls" @add="refresh_table" />

          <ModalAddWazuhAlertException ref="modal_add_exception"
            :context="props.context" :url_request="exception_urls" @add="refresh_table" />

          <NavbarTabs :tabs="tabs" :active_tab_id="active_tab" @on_click="(tab) => switch_tab(tab.id)" />

          <DateTimeRangePicker v-if="active_tab === 'alerts'" id="wazuh_alerts_date_range" class="mt-3 mb-2"
            @epoch_change="on_alerts_epoch_change" />

          <TableWithConfig v-show="active_tab === 'alerts'" ref="table_ref_alerts" table_config_id="wazuh_alerts"
            :csrf="props.context.csrf" :showLoading="true" :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            :get_extra_params_obj="get_alerts_extra_params" @custom_event="on_table_custom_event">
          </TableWithConfig>

          <TableWithConfig v-show="active_tab === 'rules'" ref="table_ref_rules" table_config_id="wazuh_alert_rules"
            :csrf="props.context.csrf" :showLoading="true" :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            @custom_event="on_table_custom_event">
            <template #custom_buttons>
              <button class="btn btn-link" type="button" @click="show_add_dialog">
                <i class="fas fa-plus"></i>
              </button>
            </template>
          </TableWithConfig>

          <TableWithConfig v-show="active_tab === 'exceptions'" ref="table_ref_exceptions" table_config_id="wazuh_alert_exceptions"
            :csrf="props.context.csrf" :showLoading="true" :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            @custom_event="on_table_custom_event">
            <template #custom_buttons>
              <button class="btn btn-link" type="button" @click="show_add_dialog">
                <i class="fas fa-plus"></i>
              </button>
            </template>
          </TableWithConfig>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddWazuhAlertRule } from "./modal-add-wazuh-alert-rule.vue";
import { default as ModalAddWazuhAlertException } from "./modal-add-wazuh-alert-exception.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as formatterUtils } from "../utilities/formatter-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const tabs = [
  { id: "alerts", label_i18n: "wazuh_alert_config.alerts" },
  { id: "rules", label_i18n: "wazuh_alert_config.alert_rules" },
  { id: "exceptions", label_i18n: "wazuh_alert_config.alert_exceptions" },
];

const active_tab = ref("alerts");
const table_ref_alerts = ref(null);
const table_ref_rules = ref(null);
const table_ref_exceptions = ref(null);

const modal_delete_confirm = ref(null);
const modal_add_rule = ref(null);
const modal_add_exception = ref(null);

const delete_title = ref("");
const delete_body = ref("");
const row_to_delete = ref(null);

const TABLE_CONFIG_MAP = {
  rules: "wazuh_alert_rules",
  exceptions: "wazuh_alert_exceptions",
  alerts: "wazuh_alerts",
};

const TABLE_REF_MAP = {
  rules: () => table_ref_rules,
  exceptions: () => table_ref_exceptions,
  alerts: () => table_ref_alerts,
};

function active_table_ref() {
  return TABLE_REF_MAP[active_tab.value]();
}

const rule_urls = {
  add: `${http_prefix}/lua/pro/rest/v2/add/wazuh/alert_rule.lua`,
  edit: `${http_prefix}/lua/pro/rest/v2/edit/wazuh/alert_rule.lua`,
};

const exception_urls = {
  add: `${http_prefix}/lua/pro/rest/v2/add/wazuh/alert_exception.lua`,
  edit: `${http_prefix}/lua/pro/rest/v2/edit/wazuh/alert_exception.lua`,
};

/* ************************************** */

function switch_tab(id) {
  if (active_tab.value !== id) {
    active_tab.value = id;
  }
  ntopng_url_manager.set_key_to_url("tab", id);
}

/* ************************************** */

function show_add_dialog() {
  if (active_tab.value === "rules") {
    modal_add_rule.value.show();
  } else {
    modal_add_exception.value.show();
  }
}

/* ************************************** */

function show_edit_dialog(row) {
  if (active_tab.value === "rules") {
    modal_add_rule.value.show(row);
  } else {
    modal_add_exception.value.show(row);
  }
}

/* ************************************** */

function show_delete_dialog(row) {
  row_to_delete.value = row;
  delete_title.value = active_tab.value === "rules"
    ? _i18n("wazuh_alert_config.delete_rule")
    : _i18n("wazuh_alert_config.delete_exception");
  delete_body.value = `${_i18n("wazuh_alert_config.delete_confirm")} ${row.id}`;
  modal_delete_confirm.value.show(delete_body.value, delete_title.value);
}

/* ************************************** */

async function delete_row() {
  const row = row_to_delete.value;
  let url;
  let params = { csrf: props.context.csrf };

  if (active_tab.value === "rules") {
    url = `${http_prefix}/lua/pro/rest/v2/delete/wazuh/alert_rule.lua`;
    params.wazuh_rule_id = row.id;
  } else {
    url = `${http_prefix}/lua/pro/rest/v2/delete/wazuh/alert_exception.lua`;
    params.wazuh_exception_id = row.id;
  }

  await ntopng_utility.http_post_request(url, params);
  refresh_table();
}

/* ************************************** */

function refresh_table() {
  active_table_ref().value?.refresh_table();
}

/* ************************************** */

function on_table_custom_event(event) {
  const handlers = {
    click_button_edit: (e) => show_edit_dialog(e.row),
    click_button_delete: (e) => show_delete_dialog(e.row),
  };
  if (handlers[event.event_id]) {
    handlers[event.event_id](event);
  }
}

/* ************************************** */

function on_alerts_epoch_change(epoch_status) {
  ntopng_url_manager.set_key_to_url("epoch_begin", `${epoch_status.epoch_begin}`);
  ntopng_url_manager.set_key_to_url("epoch_end", `${epoch_status.epoch_end}`);
  table_ref_alerts.value?.refresh_table();
}

/* ************************************** */

function get_alerts_extra_params() {
  const epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
  const epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
  if (epoch_begin == null || epoch_end == null) {
    return {};
  }
  return { epoch_begin, epoch_end };
}

/* ************************************** */

// On the exceptions tab an empty value means "any" (rendered as "*"); on the
// alerts (and any other) tab an empty value just means no data (rendered blank)
function format_empty_or_wildcard(value) {
  if (value !== "" && value != null) {
    return value;
  }
  return (active_tab.value === "exceptions") ? "*" : "";
}

/* ************************************** */

const map_table_def_columns = (columns) => {
  let map_columns = {
    /**
     * Renders rule groups as a comma-separated list
     */
    "groups": (value) => (Array.isArray(value) && value.length) ? value.join(", ") : "*",

    /**
     * Renders boolean-like flags (immediate/enabled) as check/cross icons
     */
    "immediate": (value) => value == 1
      ? `<i class="fas fa-check text-success"></i>`
      : `<i class="fas fa-times text-danger"></i>`,
    "enabled": (value) => value == 1
      ? `<i class="fas fa-check text-success"></i>`
      : `<i class="fas fa-times text-danger"></i>`,

    /**
     * Renders empty fields; on the exceptions tab empty means "any" ("*"),
     * on the alerts tab empty just means no data (blank)
     */
    "agent_name": (value) => format_empty_or_wildcard(value),

    "src_ip": (value) => format_empty_or_wildcard(value),

    "dst_ip": (value) => format_empty_or_wildcard(value),

    "username": (value) => format_empty_or_wildcard(value),

    "process": (value) => format_empty_or_wildcard(value),

    "rule_group": (value) => format_empty_or_wildcard(value),

    /**
     * Renders rule_id, 0 meaning "any"
     */
    "rule_id": (value) => (value == 0) ? "*" : value,

    /**
     * Formats the alert timestamp using the ntopng date formatter
     */
    "timestamp": (value) => formatterUtils.formatDateTime(parseInt(value)),

    /**
     * Renders the Wazuh rule level as a colored badge with its label
     */
    "rule_level": (value) => formatterUtils.formatWazuhLevel(value),
  };

  columns.forEach((c) => {
    if (map_columns[c.data_field] != null) {
      c.render_func = map_columns[c.data_field];
    }
  });

  return columns;
};

/* ************************************** */

function column_data(col, row) {
  return row[col.data.data_field];
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
  if (col == null) return;

  if (col.id === "groups") {
    const val0 = (r0.groups || []).join(",");
    const val1 = (r1.groups || []).join(",");
    return sortingFunctions.sortByName(val0, val1, col.sort);
  }

  const r0_col = column_data(col, r0);
  const r1_col = column_data(col, r1);

  return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
}

/* ************************************** */

onMounted(() => {
  const url_tab = ntopng_url_manager.get_url_entry("tab");
  if (url_tab && TABLE_CONFIG_MAP[url_tab]) {
    active_tab.value = url_tab;
  }
});
</script>
