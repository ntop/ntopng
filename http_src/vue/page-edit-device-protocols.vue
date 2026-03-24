<!--
  (C) 2026 - ntop.org
-->

<template>
  <div class="page-edit-device-protocols m-2">

    <!-- nEdge warning: policing disabled -->
    <div
      v-if="isNedge && !deviceProtocolsPolicingEnabled"
      class="alert alert-warning alert-dismissible mt-2 mb-3"
    >
      <b>{{ _i18n('warning') }}</b>:
      <span v-html="nedgePolicingWarning"></span>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>

    <div class="card card-shadow">

      <!-- Save result alert -->
      <transition name="fade-alert">
        <div v-if="saveResult" :class="['alert mx-3 mt-3 mb-0 d-flex justify-content-between align-items-start', saveResult.ok ? 'alert-success' : 'alert-danger']">
          <span>{{ saveResult.message }}</span>
          <button type="button" class="btn-close ms-2" @click="saveResult = null" aria-label="Close"></button>
        </div>
      </transition>

      <!-- Table with filters in custom_header slot -->
      <div class="px-3 pb-3">
      <TableWithConfig
        ref="table_ref"
        table_config_id="device_protocols"
        :get_extra_params_obj="getExtraParams"
        :f_map_columns="mapColumns"
        :f_map_config="mapConfig"
        :f_sort_rows="sortRows"
        :csrf="csrf"
        @custom_event="onTableEvent"
        @rows_loaded="onRowsLoaded"
      >
        <template v-slot:custom_header>
          <div class="d-flex flex-wrap gap-3 align-items-end mb-1">

            <!-- Device type selector -->
            <div>
              <label class="form-label mb-1 small fw-semibold">{{ _i18n('details.device_type') }}</label>
              <select
                class="form-select form-select-sm"
                style="width:200px"
                v-model="selectedDeviceType"
                @change="onDeviceTypeChange"
              >
                <option v-for="dt in deviceTypes" :key="dt.id" :value="dt.id">{{ dt.label }}</option>
              </select>
            </div>

            <!-- Protocol search -->
            <div class="position-relative">
              <label class="form-label mb-1 small fw-semibold">{{ _i18n('nedge.search_protocols') }}</label>
              <div class="input-group input-group-sm">
                <input
                  type="text"
                  class="form-control"
                  style="width:220px"
                  v-model="protoSearch"
                  :placeholder="_i18n('nedge.search_protocols')"
                  @input="onProtoSearchInput"
                  @blur="clearProtoSuggestionsDelayed"
                />
                <button v-if="protoSearch" class="btn btn-outline-secondary btn-sm" @click="clearProtoFilter">
                  <i class="fas fa-times"></i>
                </button>
              </div>
              <ul v-if="protoSuggestions.length" class="proto-suggestions list-group position-absolute w-100" style="z-index:1050">
                <li
                  v-for="s in protoSuggestions"
                  :key="s.key"
                  class="list-group-item list-group-item-action py-1 px-2 small"
                  @mousedown.prevent="selectProtoSuggestion(s)"
                >
                  {{ s.name }}
                </li>
              </ul>
            </div>

            <!-- Category filter -->
            <div>
              <label class="form-label mb-1 small fw-semibold">{{ _i18n('category') }}</label>
              <select class="form-select form-select-sm" style="width:160px" v-model="selectedCategory" @change="onFilterChange">
                <option value="">{{ _i18n('all') }}</option>
                <option v-for="cat in categories" :key="cat" :value="cat">{{ cat }}</option>
              </select>
            </div>

            <!-- Policy filter -->
            <div>
              <label class="form-label mb-1 small fw-semibold">{{ _i18n('nedge.filter_policies') }}</label>
              <select class="form-select form-select-sm" style="width:140px" v-model="selectedPolicyFilter" @change="onFilterChange">
                <option value="">{{ _i18n('all') }}</option>
                <option v-for="action in actions" :key="action.id" :value="action.id">{{ action.text }}</option>
              </select>
            </div>

          </div>
        </template>
      </TableWithConfig>
      </div>

      <!-- Card footer: action buttons -->
      <div class="card-footer d-flex justify-content-end gap-2">
        <button class="btn btn-secondary" @click="modal_reset.show()" :disabled="saving">
          <i class="fas fa-undo me-1"></i>
          {{ _i18n('users.reset_to_defaults') }}
        </button>
        <button class="btn btn-primary" @click="saveChanges" :disabled="!isDirty || saving">
          <span v-if="saving" class="spinner-border spinner-border-sm me-1" role="status"></span>
          <i v-else class="fas fa-save me-1"></i>
          {{ _i18n('save_settings') }}
        </button>
      </div>

    </div>

    <!-- Notes -->
    <NoteList :note_list="notes" class="mt-3">
      <li class="list-unstyled mt-1 text-secondary small">
        <span v-for="action in actions" :key="action.id" class="me-3">
          <i :class="action.icon_class"></i> {{ action.text }}
        </span>
      </li>
    </NoteList>

    <!-- Reset confirmation modal -->
    <ModalDeleteConfirm
      ref="modal_reset"
      :title="_i18n('users.reset_to_defaults')"
      :body="_i18n('users.reset_to_defaults_confirm').replace(/%\{devtype\}/g, selectedDeviceTypeLabel)"
      @delete="confirmReset"
    />

  </div>
</template>

<script setup>
import { ref, computed, reactive } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as NoteList } from "./note-list.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);

const props = defineProps({ context: Object });

const deviceTypes                    = props.context?.device_types ?? [];
const isNedge                        = props.context?.is_nedge ?? false;
const deviceProtocolsPolicingEnabled = props.context?.device_protocols_policing_enabled ?? true;
const nedgeSettingsUrl               = props.context?.nedge_settings_url ?? "";
const csrf                           = props.context?.csrf ?? "";
const actions                        = props.context?.actions ?? [];

const nedgePolicingWarning = computed(() => {
  const link = `<a href="${nedgeSettingsUrl}">${_i18n("nedge.enable_device_protocols_policies")}</a>`;
  return _i18n("nedge.device_protocols_blocked_warning").replace(/%\{device_protocols_policies\}/g, link);
});

const notes = computed(() => {
  if (isNedge) {
    return [
      _i18n("nedge.device_protocol_policy_has_higher_priority"),
      _i18n("nedge.protocol_policy_has_higher_priority"),
    ];
  }
  return [_i18n("device_protocols_description")];
});

// State
const table_ref          = ref(null);
const modal_reset        = ref(null);
const saving             = ref(false);
const isDirty            = ref(false);
const saveResult         = ref(null);
const selectedDeviceType = ref(props.context?.device_type ?? "0");

// used to hide success message 
let saveTimer = null;

function triggerSaveResult(result) {
  saveResult.value = result;

  if (saveTimer) clearTimeout(saveTimer);

  saveTimer = setTimeout(() => {
    saveResult.value = null;
  }, 3000);
}

// Filters
const selectedCategory     = ref("");
const selectedPolicyFilter = ref("");
const protoSearch          = ref("");
const protoSuggestions     = ref([]);
const categories           = ref([]);

// Loaded rows (captured from rows_loaded event)
const allRows = ref([]);

// Pending changes: { [proto_id]: { client, server } }
const pendingChanges = reactive({});

const selectedDeviceTypeLabel = computed(() => {
  const dt = deviceTypes.find(d => String(d.id) === String(selectedDeviceType.value));
  return dt ? dt.label : "";
});

function getExtraParams() {
  const params = { device_type: selectedDeviceType.value };
  if (selectedCategory.value)     params.category      = selectedCategory.value;
  if (selectedPolicyFilter.value) params.policy_filter = selectedPolicyFilter.value;
  return params;
}

// Disable the table's built-in search box since we provide our own
function mapConfig(config) {
  config.enable_search = false;
  return config;
}

async function mapColumns(columns) {
  columns.forEach((col) => {
    if (col.id === "client_policy" || col.id === "server_policy") {
      const side = col.id === "client_policy" ? "client" : "server";
      col.render_v_func = (_col, row, vue_obj) => {
        return vue_obj.h(
          "div",
          { class: "d-flex justify-content-center gap-2" },
          actions.map((action) => {
            const current = pendingChanges[row.id]?.[side] ?? row[col.data_field];
            return vue_obj.h(
              "label",
              { class: "action-radio", title: action.text, style: "cursor:pointer;" },
              [
                vue_obj.h("input", {
                  type: "radio",
                  name: `${side}_${row.id}`,
                  value: action.id,
                  checked: current === action.id,
                  style: "margin-right:2px;",
                  onChange: (e) => {
                    e.stopPropagation();
                    vue_obj.emit("custom_event", {
                      event_id: "policy_change",
                      row,
                      side,
                      action_id: action.id,
                    });
                  },
                }),
                vue_obj.h("i", { class: `${action.icon_class} ms-1` }),
              ]
            );
          })
        );
      };
    }
  });
  return columns;
}

function sortRows(col, r0, r1) {
  if (!col || col.sort === 0) return 0;
  const field = col.data?.data_field ?? col.id;
  const va = (r0[field] || "").toLowerCase();
  const vb = (r1[field] || "").toLowerCase();
  const cmp = va < vb ? -1 : va > vb ? 1 : 0;
  return col.sort === 1 ? cmp : -cmp;
}

function onTableEvent(event) {
  if (event.event_id === "policy_change") {
    const { row, side, action_id } = event;
    if (!pendingChanges[row.id]) {
      pendingChanges[row.id] = {
        client: row.client_policy,
        server: row.server_policy,
      };
    }
    pendingChanges[row.id][side] = action_id;
    isDirty.value = true;
  }
}

function onRowsLoaded(res) {
  allRows.value = res?.rows ?? [];
  Object.keys(pendingChanges).forEach(k => delete pendingChanges[k]);
  isDirty.value = false;
  saveResult.value = null;

  // Populate categories from unfiltered loads
  if (!selectedCategory.value) {
    categories.value = [...new Set(allRows.value.map(r => r.category).filter(Boolean))].sort();
  }
}

function onDeviceTypeChange() {
  selectedCategory.value     = "";
  selectedPolicyFilter.value = "";
  protoSearch.value          = "";
  protoSuggestions.value     = [];
  categories.value           = [];
  table_ref.value?.search_value?.("");
  table_ref.value?.refresh_table?.();
}

function onFilterChange() {
  table_ref.value?.refresh_table?.();
}

let searchTimer = null;

function onProtoSearchInput() {
  clearTimeout(searchTimer);
  if (!protoSearch.value || protoSearch.value.length < 2) {
    protoSuggestions.value = [];
    table_ref.value?.search_value?.("");
    return;
  }
  searchTimer = setTimeout(async () => {
    table_ref.value?.search_value?.(protoSearch.value);
    try {
      const url  = `${http_prefix}/lua/find_app.lua?query=${encodeURIComponent(protoSearch.value)}&skip_critical=true`;
      const data = await ntopng_utility.http_request(url);
      protoSuggestions.value = data?.rsp?.results ?? [];
    } catch (_) {
      protoSuggestions.value = [];
    }
  }, 200);
}

function selectProtoSuggestion(s) {
  protoSearch.value      = s.name;
  protoSuggestions.value = [];
  table_ref.value?.search_value?.(s.name);
}

function clearProtoSuggestionsDelayed() {
  setTimeout(() => { protoSuggestions.value = []; }, 200);
}

function clearProtoFilter() {
  protoSearch.value      = "";
  protoSuggestions.value = [];
  table_ref.value?.search_value?.("");
}

async function saveChanges() {
  saving.value  = true;
  saveResult.value = null;
  try {
    const policies = allRows.value.map(p => ({
      proto_id:      p.id,
      client_action: pendingChanges[p.id]?.client ?? p.client_policy,
      server_action: pendingChanges[p.id]?.server ?? p.server_policy,
    }));

    await ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/set/device/protocol_policies.lua`, {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    new URLSearchParams({
        payload: JSON.stringify({ device_type: selectedDeviceType.value, policies }),
        csrf,
      }).toString(),
    });

    isDirty.value    = false;
    triggerSaveResult({ ok: true, message: _i18n("saved") });
  } catch (_) {
    triggerSaveResult({ ok: false, message: _i18n("request_failed_message") });
  } finally {
    saving.value = false;
  }
}

async function confirmReset() {
  saving.value     = true;
  saveResult.value = null;
  try {
    await ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/set/device/reset_policies.lua`, {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    new URLSearchParams({ device_type: selectedDeviceType.value, csrf }).toString(),
    });
    table_ref.value?.refresh_table?.();
    triggerSaveResult({ ok: true, message: _i18n("users.reset_to_defaults") + ": " + _i18n("saved") });
  } catch (_) {
    triggerSaveResult({ ok: false, message: _i18n("request_failed_message") });
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.action-radio {
  cursor: pointer;
  font-size: 1rem;
}

.proto-suggestions {
  top: 100%;
  left: 0;
  max-height: 200px;
  overflow-y: auto;
  border: 1px solid rgba(0, 0, 0, 0.15);
  border-radius: 0.375rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
</style>
