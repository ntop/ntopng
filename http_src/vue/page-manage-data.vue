<!--
  (C) 2026 - ntop.org
-->

<template>
  <div class="page-manage-data">
    <div class="card card-shadow">

      <div class="card-header">
        <NavbarTabs :tabs="tabs" :active_tab_id="activeTab" @on_click="(tab) => (activeTab = tab.id)" />
      </div>

      <!-- Export tab -->
      <div v-if="activeTab === 'export'">
        <div class="card-body">

          <!-- Manage data selector -->
          <div class="mb-3">
            <label class="d-block mb-2">{{ _i18n('manage_data.select_export_type') }}</label>
            <div class="d-flex flex-wrap gap-4">
              <div class="form-check">
                <input class="form-check-input" type="radio" id="exp_all" v-model="exportMode" value="all" />
                <label class="form-check-label" for="exp_all">{{ _i18n('manage_data.all_hosts') }}</label>
              </div>
              <div class="form-check">
                <input class="form-check-input" type="radio" id="exp_local" v-model="exportMode" value="local" />
                <label class="form-check-label" for="exp_local">{{ _i18n('manage_data.local_hosts') }}</label>
              </div>
              <div class="form-check">
                <input class="form-check-input" type="radio" id="exp_remote" v-model="exportMode" value="remote" />
                <label class="form-check-label" for="exp_remote">{{ _i18n('manage_data.remote_hosts') }}</label>
              </div>
              <div class="form-check">
                <input class="form-check-input" type="radio" id="exp_single" v-model="exportMode" value="filtered" />
                <label class="form-check-label" for="exp_single">{{ _i18n('manage_data.single') }}</label>
              </div>
            </div>
          </div>

          <!-- Host IP / VLAN. Disabled unless mode=filtered -->
          <div class="row g-3">
            <div class="col-auto">
              <label for="export_host" class="form-label">{{ _i18n('manage_data.specify_ip_mac') }}</label>
              <div class="position-relative">
                <input
                  id="export_host"
                  v-model="exportHost"
                  type="text"
                  class="form-control"
                  style="width:240px"
                  :placeholder="_i18n('manage_data.ip_or_mac_address')"
                  :disabled="exportMode !== 'filtered'"
                  autocomplete="off"
                  @input="fetchSuggestions('export')"
                  @blur="clearSuggestionsDelayed('export')"
                />
                <ul v-if="exportSuggestions.length" class="host-suggestions list-group position-absolute w-100" style="z-index:1050">
                  <li
                    v-for="s in exportSuggestions"
                    :key="s.ip"
                    class="list-group-item list-group-item-action py-1 px-2 small"
                    @mousedown.prevent="selectSuggestion('export', s)"
                  >
                    {{ s.name || s.ip }}
                  </li>
                </ul>
              </div>
            </div>
            <div class="col-auto">
              <label for="export_vlan" class="form-label">{{ _i18n('manage_data.specify_vlan') }}</label>
              <input
                id="export_vlan"
                v-model="exportVlan"
                type="number"
                min="1"
                max="65535"
                class="form-control"
                style="width:120px"
                :placeholder="_i18n('vlan')"
                :disabled="exportMode !== 'filtered'"
              />
            </div>
          </div>

        </div>
        <div class="card-footer text-end">
          <button class="btn btn-secondary" @click="doExport">
            <i class="fas fa-file-export me-1"></i>
            {{ _i18n('export_data.export_json_data') }}
          </button>
        </div>
      </div>

      <!-- Delete / Purge section -->
      <div v-if="activeTab === 'delete'">
        <div class="card-body">

          <div class="row g-3">
            <div class="col-md-4 col-sm-12">
              <label for="delete_host" class="form-label fw-semibold">
                {{ _i18n('manage_data.specify_ip_mac') }}
              </label>
              <div class="position-relative">
                <input
                  id="delete_host"
                  v-model="deleteHost"
                  type="text"
                  :class="['form-control', deleteHostError ? 'is-invalid' : '']"
                  :placeholder="_i18n('manage_data.ip_or_mac_address')"
                  autocomplete="off"
                  @input="fetchSuggestions('delete')"
                  @blur="clearSuggestionsDelayed('delete')"
                />
                <ul v-if="deleteSuggestions.length" class="host-suggestions list-group position-absolute w-100" style="z-index:1050">
                  <li
                    v-for="s in deleteSuggestions"
                    :key="s.ip"
                    class="list-group-item list-group-item-action py-1 px-2 small"
                    @mousedown.prevent="selectSuggestion('delete', s)"
                  >
                    {{ s.name || s.ip }}
                  </li>
                </ul>
                <div v-if="deleteHostError" class="invalid-feedback">
                  {{ _i18n('manage_data.mac_or_ip_required') }}
                </div>
              </div>
            </div>
            <div class="col-md-2 col-sm-12">
              <label for="delete_vlan" class="form-label fw-semibold">{{ _i18n('vlan') }}</label>
              <input
                id="delete_vlan"
                v-model="deleteVlan"
                type="number"
                min="1"
                max="65535"
                class="form-control"
                :placeholder="_i18n('vlan')"
              />
            </div>
          </div>

          <div v-if="deleteResult" :class="['alert mt-3 mb-0 d-flex justify-content-between align-items-start', deleteResult.ok ? 'alert-success' : 'alert-danger']">
            <span v-html="deleteResult.message"></span>
            <button type="button" class="btn-close ms-2" @click="deleteResult = null" aria-label="Close"></button>
          </div>

        </div>
        <div class="card-footer d-flex justify-content-end gap-2">
          <button class="btn btn-danger" @click="openDeleteModal" :disabled="deleting">
            <i class="fas fa-trash me-1"></i>
            {{ _i18n('manage_data.delete') }}
          </button>
          <button
            v-if="!deleteActiveIfRequested && !isEdge"
            class="btn btn-danger"
            @click="modal_delete_active_if.show()"
            :disabled="deleting"
          >
            <i class="fas fa-trash me-1"></i>
            {{ _i18n('manage_data.delete_active_interface') }}
          </button>
        </div>
      </div>

    </div><!-- /card -->

    <!-- Notes for active tab -->
    <NoteList v-if=Notes.length :note_list="Notes"></NoteList>

    <!-- Delete host confirmation modal -->
    <ModalDeleteConfirm
      ref="modal_delete_host"
      :title="_i18n('manage_data.delete')"
      :body="deleteConfirmBody"
      @delete="confirmDelete"
    />

    <!-- Delete active interface confirmation modal -->
    <ModalDeleteConfirm
      ref="modal_delete_active_if"
      :title="_i18n('manage_data.delete_active_interface')"
      :body="deleteActiveIfBody"
      @delete="confirmDeleteActiveIf"
    />

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as NoteList } from "./note-list.vue";

const props = defineProps({ context: Object });
const _i18n = (t) => i18n(t);

const ifid                     = props.context?.ifid ?? "";
const ifname                   = props.context?.ifname ?? "";
const product                  = props.context?.product ?? "";
const deleteActiveIfRequested  = props.context?.delete_active_interface_requested ?? false;
const isEdge                   = props.context?.is_edge ?? false;
const hasClickhouse            = props.context?.has_clickhouse ?? false;

// Tab state
const activeTab = ref("export");

// Export tab state
const exportMode        = ref("all");
const exportHost        = ref("");
const exportVlan        = ref("");
const exportSuggestions = ref([]);

// Delete tab state
const deleteHost        = ref("");
const deleteVlan        = ref("");
const deleteSuggestions = ref([]);
const deleteHostError   = ref(false);
const deleting          = ref(false);
const deleteResult      = ref(null);

// Modal refs
const modal_delete_host      = ref(null);
const modal_delete_active_if = ref(null);

const tabs = [
  { id: "export", label_i18n: "manage_data.export" },
  { id: "delete", label_i18n: "manage_data.delete" },
];

const Notes = computed(() => {
  if (activeTab.value === "export") {
    return [
      _i18n("export_data.note_maximum_number"),
      _i18n("export_data.note_active_hosts"),
    ];
  }
  if (activeTab.value === "delete") {
    const notes = [
      _i18n("delete_data.note_persistent_data"),
      _i18n("manage_data.system_interface_note"),
    ];
    if (hasClickhouse) notes.push(_i18n("delete_data.node_nindex_flows"));
    return notes;
  }
  return [];
});

const deleteHostDisplay = computed(() => {
  const v = deleteVlan.value ? `@${deleteVlan.value}` : "";
  return `${deleteHost.value}${v}`;
});

const deleteConfirmBody = computed(() =>
  _i18n("delete_data.delete_confirmation").replace(/%\{host\}/g, deleteHostDisplay.value)
);

const deleteActiveIfBody = computed(() =>
  _i18n("delete_data.delete_active_interface_confirmation")
    .replace(/%\{ifname\}/g, ifname)
    .replace(/%\{product\}/g, product)
);


async function fetchSuggestions(tab) {
  const query = tab === "export" ? exportHost.value : deleteHost.value;
  if (!query || query.length < 2) {
    if (tab === "export") exportSuggestions.value = [];
    else deleteSuggestions.value = [];
    return;
  }
  try {
    const url = `${http_prefix}/lua/rest/v2/get/host/find.lua?query=${encodeURIComponent(query)}&hosts_only=true`;
    const data = await ntopng_utility.http_request(url);
    const results = data?.results ?? [];

    if (tab === "export") exportSuggestions.value = results;
    else deleteSuggestions.value = results;
  } catch (_) {
    /* ignore autocomplete errors */
  }
}

function selectSuggestion(tab, item) {
  const parts = (item.ip || "").split("@");
  if (tab === "export") {
    exportHost.value = parts[0] || "";
    exportVlan.value = parts[1] || "";
    exportSuggestions.value = [];
  } else {
    deleteHost.value = parts[0] || "";
    deleteVlan.value = parts[1] || "";
    deleteSuggestions.value = [];
  }
}

function clearSuggestionsDelayed(tab) {
  setTimeout(() => {
    if (tab === "export") exportSuggestions.value = [];
    else deleteSuggestions.value = [];
  }, 200);
}

function doExport() {
  const params = new URLSearchParams({ ifid, mode: exportMode.value });
  if (exportMode.value === "filtered") {
    if (exportHost.value) params.set("host", exportHost.value);
    if (exportVlan.value) params.set("vlan", exportVlan.value);
  }
  window.location.href = `${http_prefix}/lua/do_export_data.lua?${params.toString()}`;
}

// Delete host

function openDeleteModal() {
  deleteHostError.value = false;
  if (!deleteHost.value.trim()) {
    deleteHostError.value = true;
    return;
  }
  modal_delete_host.value.show();
}

async function confirmDelete() {
  deleting.value = true;
  deleteResult.value = null;
  try {
    const body = new URLSearchParams({
      ifid,
      host: deleteHost.value.trim(),
      vlan: deleteVlan.value || "0",
      csrf: props.context?.csrf ?? "",
    });
    await ntopng_utility.http_request(`${http_prefix}/lua/rest/v2/delete/host/data.lua`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });
    deleteResult.value = {
      ok: true,
      message: _i18n("delete_data.delete_ok").replace(/%\{host\}/g, deleteHostDisplay.value),
    };
    deleteHost.value = "";
    deleteVlan.value = "";
  } catch (_) {
    deleteResult.value = {
      ok: false,
      message: _i18n("delete_data.delete_failed").replace(/%\{host\}/g, deleteHostDisplay.value),
    };
  } finally {
    deleting.value = false;
  }
}

// Delete active interface action

async function confirmDeleteActiveIf() {
  deleting.value = true;
  try {
    const body = new URLSearchParams({
      ifid,
      delete_active_if_data: "",
      csrf: props.context?.csrf ?? "",
    });
    await ntopng_utility.http_request(`${http_prefix}/lua/manage_data.lua`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });
    deleteResult.value = {
      ok: true,
      message: _i18n("delete_data.delete_active_interface_data_ok")
        .replace(/%\{ifname\}/g, ifname)
        .replace(/%\{product\}/g, product),
    };
    activeTab.value = "delete";
  } catch (_) {
    deleteResult.value = { ok: false, message: _i18n("request_failed_message") };
  } finally {
    deleting.value = false;
  }
}
</script>

<style scoped>
.host-suggestions {
  top: 100%;
  left: 0;
  max-height: 200px;
  overflow-y: auto;
  border: 1px solid rgba(0, 0, 0, 0.15);
  border-radius: 0.375rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
</style>
