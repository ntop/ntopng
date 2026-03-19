<!--
  (C) 2019-26 - ntop.org
-->
<template>
  <div class="page-edit-configset">

    <!-- alert banners -->
    <div v-if="error_msg" class="alert alert-danger alert-dismissible mb-3" role="alert">
      {{ error_msg }}
      <button type="button" class="btn-close" data-bs-dismiss="alert" @click="error_msg = null"></button>
    </div>
    <div v-if="success_msg" class="alert alert-success alert-dismissible mb-3" role="alert">
      {{ success_msg }}
      <button type="button" class="btn-close" data-bs-dismiss="alert" @click="success_msg = null"></button>
    </div>

    <!-- Checks Table -->
    <TableWithConfig ref="table_ref" table_config_id="edit_configset" :get_extra_params_obj="getExtraParams"
      :f_map_columns="mapColumns" :f_sort_rows="columns_sorting" @custom_event="on_table_event"
      @rows_loaded="on_rows_loaded">
      <template v-slot:custom_header>
        <NavbarTabs :tabs="tabs_with_counts" :active_tab_id="active_status"
          @on_click="(tab) => set_status(tab.id)" />
      </template>

    </TableWithConfig>
    
    <!-- Reset to factory and disable all checks -->
    <div class="card-footer mt-3">
        <button type="button" ref="delete_all_rules" @click="show_disable_modal = true" class="btn btn-danger">
          <i class="fas fa-toggle-off"></i>
          {{ _i18n("checks.disable_all") }}
        </button>
        <button v-if="props.context.check_subdir === 'all'" type="button" ref="restore_checks" @click="show_reset_modal = true" class="btn btn-primary ms-1">
          <i class="fa-solid fa-eraser"></i>
          {{ _i18n("restore_checks") }}
        </button>
      </div>

    <!-- notes -->
    <div class="notes bg-light border rounded p-3 mt-3 small">
      <strong>{{ _i18n('notes') }}</strong>
      <ul class="mb-0 mt-1">
        <li>{{ _i18n('checks.categories') }}</li>
        <li>
          {{ _i18n('interface') }}:
          <i class="fa fa-ethernet"></i> {{ _i18n('scripts_list.note_packet_interface') }} —
          <i class="fa fa-bezier-curve"></i> {{ _i18n('scripts_list.note_zmq_interface') }}
        </li>
      </ul>
    </div>

    <!-- edit-check modal -->
    <ModalEditCheck ref="modal_edit_check" :page_csrf="props.context.page_csrf" @saved="on_check_saved" />

    <!-- disable-all modal -->
    <div v-if="show_disable_modal" class="modal d-block" tabindex="-1" >
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ _i18n('checks.disable_all_checks') }}</h5>
            <button type="button" class="btn-close" @click="show_disable_modal = false"></button>
          </div>
          <div class="modal-body">
            <div class="alert alert-danger mb-0">{{ _i18n('checks.disable_all_message') }}</div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="show_disable_modal = false">{{ _i18n('cancel') }}</button>
            <button class="btn btn-danger" :disabled="batch_loading" @click="disable_all_visible">
              <span v-if="batch_loading" class="spinner-border spinner-border-sm me-1"></span>
              {{ _i18n('checks.disable_all') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- factory-reset modal -->
    <div v-if="show_reset_modal" class="modal d-block" tabindex="-1">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ _i18n('checks.factory_reset_all_checks') }}</h5>
            <button type="button" class="btn-close" @click="show_reset_modal = false"></button>
          </div>
          <div class="modal-body">
            <div class="alert alert-danger mb-0">{{ _i18n('checks.factory_reset_all_message') }}</div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="show_reset_modal = false">{{ _i18n('cancel') }}</button>
            <button class="btn btn-primary" :disabled="batch_loading" @click="factory_reset">
              <span v-if="batch_loading" class="spinner-border spinner-border-sm me-1"></span>
              {{ _i18n('factory_reset') }}
            </button>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, reactive, computed } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as ModalEditCheck } from "./modal-edit-check.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({ context: Object });

const table_ref = ref(null);
const modal_edit_check = ref(null);
const active_status = ref("all");
const all_rows = ref([]);
const tab_counts = reactive({});
const batch_loading = ref(false);
const error_msg = ref(null);
const success_msg = ref(null);
const show_disable_modal = ref(false);
const show_reset_modal = ref(false);

// Check status
const STATUS_TABS = [
  { id: "all",      label_i18n: "all" },
  { id: "enabled",  label_i18n: "enabled" },
  { id: "disabled", label_i18n: "disabled" },
];

const tabs_with_counts = computed(() =>
  STATUS_TABS.map((t) => ({ ...t, count: tab_counts[t.id] ?? null }))
);

function getExtraParams() {
  return {
    check_subdir: props.context.check_subdir,
    ifid: props.context.ifid,
    status: active_status.value,
  };
}

async function mapColumns(columns) {
  columns.forEach((c) => {
    if (c.id === "subdir" && props.context.check_subdir !== "all") {
      c.visible = false;
    }
    if (c.id === "category") {
      c.render_func = (_data, row) => {
        const icon = row.category_icon ? `<i class="${row.category_icon}"></i> ` : "";
        const label = row.category_key ? _i18n(row.category_key) : "";
        return `${icon}${label}`;
      };
    }
    if (c.id === "severity") {
      c.render_func = (_data, row) => {
        const icon = row.severity_icon ? `<i class="${row.severity_icon}"></i> ` : "";
        const label = row.severity_key ? _i18n(row.severity_key) : "";
        return `${icon}${label}`;
      };
    }
    // Actions: disable edit button for non-editable checks
    if (c.id === "actions") {
      const visible_dict = {
        edit: (row) => row.is_editable,
      };

      c.button_def_array.forEach((b) => {
        b.f_map_class = (current_class, row) => {

          //if (!visible_dict[b.id]?.(row)) current_class.push("disabled");
          if (!row.is_editable) {
            console.log(`Disabling: ${row.key}`)
            current_class.push("disabled");
            
          }
          return current_class;
        };
      });
    }

    if (c.id === "enabled") {
      c.render_v_func = (_col, row, vue_obj) => {
        return vue_obj.h("div", { class: "form-check form-switch d-flex justify-content-center mb-0" }, [
          vue_obj.h("input", {
            type: "checkbox", class: "form-check-input",
            checked: row.is_enabled === true, style: "cursor:pointer;",
            onChange: (e) => {
              e.stopPropagation();
              vue_obj.emit("custom_event", { event_id: "toggle_check", row, enabled: e.target.checked });
            },
          }),
        ]);
      };
    }
  });
  return columns;
}

// sorting function for each column
const SORT_FIELDS = {
  title: { getter: (r) => r.title, fn: sortingFunctions.sortByName },
  subdir: { getter: (r) => r.subdir, fn: sortingFunctions.sortByName },
  category: { getter: (r) => r.category_key, fn: sortingFunctions.sortByName },
  severity: { getter: (r) => r.severity_key, fn: sortingFunctions.sortByName },
  description: { getter: (r) => r.description, fn: sortingFunctions.sortByName },
  enabled: { getter: (r) => r.is_enabled ? 1 : 0, fn: sortingFunctions.sortByNumber },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}

// rows_loaded 
function on_rows_loaded(res) {
  const rows = res?.rows || [];
  all_rows.value = rows;

  if (active_status.value === "all") {
    const enabled = rows.filter((r) => r.is_enabled).length;

    tab_counts.all = rows.length;
    tab_counts.enabled = enabled;
    tab_counts.disabled = rows.length - enabled;
  } else {
    tab_counts[active_status.value] = rows.length;
  }
}

// Check status tabs
function set_status(id) {
  active_status.value = id;
  table_ref.value?.refresh_table?.();
}

// table events
async function on_table_event(event) {
  if (event.event_id === "toggle_check") {
    await toggle_behavioural_check(event.row, event.enabled);
  } else if (event.event_id === "edit_check") {
    modal_edit_check.value.show(event.row);
  }
}

function on_check_saved() {
  table_ref.value?.refresh_table?.();
  success_msg.value = _i18n("changes_applied");
}

// Toggle one check
async function toggle_behavioural_check(row, enable) {
  error_msg.value = null;

  try {
    const rsp = await ntopng_utility.http_post_request(
      `${http_prefix}/lua/rest/v2/toggle/checks/batch.lua`,
      {
        check_subdir: row.subdir,
        script_keys: row.key,
        enabled: String(enable),
        csrf: props.context.page_csrf,
      }
    );
    const result = rsp?.results?.[0];

    if (result?.success) {
      table_ref.value?.refresh_table?.();
    } else {
      error_msg.value = result?.error || _i18n("request_failed_message");
    }

  } catch {
    error_msg.value = _i18n("request_failed_message");
  }
}

// batch disable visible
async function disable_all_visible() {
  show_disable_modal.value = false;
  batch_loading.value = true;
  error_msg.value = null;

  const by_subdir = {};
  for (const row of all_rows.value) {
    if (!row.is_enabled) continue;
    by_subdir[row.subdir] = by_subdir[row.subdir] || [];
    by_subdir[row.subdir].push(row.key);
  }

  let any_fail = false;
  for (const [sd, keys] of Object.entries(by_subdir)) {
    if (keys.length === 0) continue;
    try {
      const rsp = await ntopng_utility.http_post_request(
        `${http_prefix}/lua/rest/v2/toggle/checks/batch.lua`,
        {
          check_subdir: sd,
          script_keys: keys.join(","),
          enabled: "false",
          csrf: props.context.page_csrf,
        }
      );
      if (rsp?.results?.some((r) => !r.success)) any_fail = true;
    } catch {
      any_fail = true;
    }
  }

  batch_loading.value = false;
  table_ref.value?.refresh_table?.();
  if (any_fail) {
    error_msg.value = _i18n("request_failed_message");
  } else {
    success_msg.value = _i18n("changes_applied");
  }
}

// ────────────────────────────────────────────────────────────────
async function factory_reset() {
  show_reset_modal.value = false;
  batch_loading.value = true;
  error_msg.value = null;
  try {
    await ntopng_utility.http_post_request(
      `${http_prefix}/lua/rest/v2/reset/checks/config.lua`,
      { csrf: props.context.page_csrf }
    );
    table_ref.value?.refresh_table?.();
    success_msg.value = _i18n("changes_applied");
  } catch {
    error_msg.value = _i18n("request_failed_message");
  } finally {
    batch_loading.value = false;
  }
}
</script>
