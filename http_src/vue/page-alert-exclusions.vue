<!-- (C) 2026 - ntop.org -->
<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card">
        <div class="card-body">
          <ModalDeleteConfirm
            ref="modal_delete_confirm"
            :title="delete_title"
            :body="delete_body"
            @delete="delete_row"
          />
          <ModalDeleteConfirm
            ref="modal_delete_all"
            :title="_i18n('edit_check.delete_all_alert_exclusions')"
            :body="_i18n('edit_check.delete_all_alert_exclusions_message')"
            @delete="delete_all"
          />
          <ModalAddCheckExclusion
            ref="modal_add_check"
            :alert_exclusions_page="active_tab"
            :host_alert_types="props.context.host_alert_types"
            :flow_alert_types="props.context.flow_alert_types"
            @add="add_exclusion"
          />

          <TableWithConfig
            :key="active_tab"
            ref="table_ref"
            :table_config_id="TABLE_CONFIG_MAP_id"
            :get_extra_params_obj="get_extra_params"
            :f_map_columns="map_columns"
            @custom_event="on_table_custom_event"
          >
            <template #custom_header>
              <NavbarTabs
                :tabs="tabs"
                :active_tab_id="active_tab"
                @on_click="(tab) => switch_tab(tab.id)"
              />
            </template>
            <template #custom_buttons>
              <button class="btn btn-link" type="button" @click="show_add_dialog">
                <i class="fas fa-plus"></i>
              </button>
            </template>
          </TableWithConfig>
        </div>

        <div class="card-footer">
          <button type="button" class="btn btn-danger" @click="modal_delete_all.show()">
            <i class="fas fa-trash"></i>
            {{ _i18n("edit_check.delete_all_alert_exclusions") }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddCheckExclusion } from "./modal-add-check-exclusion.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";

const props = defineProps({
  context: Object,
});

const _i18n = (key) => i18n(key);

// navbar tabs selector to choose which table tab
const tabs = [
  { id: "hosts",           label_i18n: "hosts" },
  { id: "domain_names",    label_i18n: "edit_check.domain_names" },
  { id: "tls_certificate", label_i18n: "edit_check.tls_certificate" },
];

const active_tab = ref("hosts");
const table_ref = ref(null);

// modal refs
const modal_delete_confirm = ref(null);
const modal_delete_all     = ref(null);
const modal_add_check      = ref(null);

// Delete modal state
const delete_title  = ref("");
const delete_body   = ref("");
const row_to_delete = ref(null);

// maps navbar tab to table config
const TABLE_CONFIG_MAP = {
  hosts:           "alert_exclusions_hosts",
  domain_names:    "alert_exclusions_domain_names",
  tls_certificate: "alert_exclusions_tls_certificate",
};

const TYPE_MAP = {
  hosts:           "host",
  domain_names:    "domain",
  tls_certificate: "certificate",
};

// use selected
const TABLE_CONFIG_MAP_id = computed(() => TABLE_CONFIG_MAP[active_tab.value]);

function get_extra_params() {
  return { type: TYPE_MAP[active_tab.value] };
}

function alert_page_to_type() {
  return TYPE_MAP[active_tab.value] || "";
}

// switch selected tab
function switch_tab(id) {
  if (active_tab.value !== id) {
    active_tab.value = id;
    // set to url the selected subdir
    ntopng_url_manager.set_key_to_url("subdir", id);
  }
}

// Add edit modal
function show_add_dialog() {
  modal_add_check.value.show();
}

function show_edit_dialog(row) {
  const type = alert_page_to_type();
  const payload = {
    type,
    subdir:    row.subdir,
    label:     row.comment,
    // fields the modal uses internally to delete the old entry on save
    alert_addr:        row.excluded_key,
    alert_domain:      row.excluded_key,
    alert_certificate: row.excluded_key,
    // host alert keys: one slot per subdir, -1 means "not set"
    host_alert_key: row.subdir === "host" ? String(row.alert_key) : "-1",
    flow_alert_key: row.subdir === "flow" ? String(row.alert_key) : "-1",
  };
  modal_add_check.value.show(payload);
}

// add exclusion
async function add_exclusion(params) {
  params.type = alert_page_to_type();
  params.csrf = props.context.csrf;

  const url = `${http_prefix}/lua/pro/rest/v2/add/alert/exclusion.lua`;
  await ntopng_utility.http_request(url, {
    method:  "post",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify(params),
  });
  table_ref.value?.refresh_table();
}

// delete one exclusion
function show_delete_dialog(row) {
  row_to_delete.value = row;
  delete_title.value  = _i18n("edit_check.exclusion_list");
  const subject = row.excluded_host || row.title || "";

  delete_body.value   = `${_i18n("edit_check.delete_alert_exclusions")} ${subject}`;
  modal_delete_confirm.value.show(delete_body.value, delete_title.value);
}

async function delete_row() {
  const row    = row_to_delete.value;
  const type   = alert_page_to_type();
  const params = { type, csrf: props.context.csrf, subdir: row.subdir };

  if (type === "host") {
    params.alert_addr = row.excluded_key;
    params[row.subdir === "host" ? "host_alert_key" : "flow_alert_key"] = row.alert_key;
  } else if (type === "domain") {
    params.alert_domain = row.excluded_key;
  } else if (type === "certificate") {
    params.alert_certificate = row.excluded_key;
  }

  const url = `${http_prefix}/lua/pro/rest/v2/delete/alert/exclusion.lua`;
  await ntopng_utility.http_request(url, {
    method:  "post",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify(params),
  });
  setTimeout(() => table_ref.value?.refresh_table(), 300);
}

// delete all
async function delete_all() {
  const url = `${http_prefix}/lua/pro/rest/v2/delete/all/alert/exclusions.lua`;

  await ntopng_utility.http_request(url, {
    method:  "post",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify({ type: alert_page_to_type(), csrf: props.context.csrf }),
  });
  table_ref.value?.refresh_table();
}


function on_table_custom_event(event) {
  const handlers = {
    click_button_edit:   (e) => show_edit_dialog(e.row),
    click_button_delete: (e) => show_delete_dialog(e.row),
  };
  if (handlers[event.event_id]) {
    handlers[event.event_id](event);
  }
}

function map_columns(columns) {
  columns.forEach((c) => {
    if (c.data_field === "title") {
      c.render_func = (value) => `${value}`;
    }
    if (c.data_field === "subdir") {
      c.render_func = (value) => _i18n(`check_exclusion.${value}`);
    }
    if (c.data_field === "category_icon") {
      c.render_func = (value, row) =>
        row.category_icon ? `<i class="fa ${row.category_icon}"></i>` : "";
    }
  });
  return columns;
}

onMounted(() => {
  const subdir_tab = ntopng_url_manager.get_url_entry("subdir");
  if (subdir_tab && TABLE_CONFIG_MAP[subdir_tab]) {
    switch_tab(subdir_tab);
  }
})
</script>
