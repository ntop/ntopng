<!-- (C) 2019-26 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <div class="card card-shadow">

      <div class="card-body">
        <!-- Single TableWithConfig instance; :key forces re-mount on tab switch -->
        <TableWithConfig ref="tableRef" :key="activeTab" :table_config_id="currentTableConfigId"
          :get_extra_params_obj="getExtraParams" :f_map_columns="currentMapColumns" :f_sort_rows="columnsSorting"
          @rows_loaded="onRowsLoaded">
          <template v-slot:custom_header>
            <NavbarTabs :tabs="visibleTabs" :active_tab_id="activeTab" @on_click="(tab) => switch_tab(tab.id)" />
 
            <!-- Periodic Activities filters -->
            <template v-if="activeTab === 'periodic_activities'">
              <div class="d-flex align-items-center gap-1" v-if="paScriptOptions.length > 1">
                  {{ _i18n("internals.script") }}:
                <SelectSearch v-model:selected_option="paScriptFilter" theme="bootstrap-5" dropdown_size="small"
                  :options="paScriptOptions" @select_option="onPaFilter" />
              </div>
              
              <div class="d-flex align-items-center gap-1">
                  {{ _i18n("internals.issue") }}:
                <SelectSearch v-model:selected_option="paIssueFilter" theme="bootstrap-5" dropdown_size="small"
                  :options="paIssueOptions" @select_option="onPaFilter" />
              </div>
            </template>

            <!-- Checks filter -->
            <template v-if="activeTab === 'checks'">
              <div class="d-flex align-items-center gap-1" v-if="checkTargetOptions.length > 1">
                  {{ _i18n("internals.check_target") }}:
                <SelectSearch v-model:selected_option="checkTargetFilter" theme="bootstrap-5" dropdown_size="small"
                  :options="checkTargetOptions" @select_option="onCheckTargetFilter" />
              </div>
            </template>
          </template>
        </TableWithConfig>
      </div>

      <!-- Notes footer — only for Periodic Activities tab -->
      <div v-if="activeTab === 'periodic_activities'" class="card-footer p-0">
        <NoteList :note_list="periodicNotes" />
      </div>

    </div><!-- card -->
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import NoteList from "./note-list.vue";
import NtopUtils from "../utilities/ntop-utils.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import formatterUtils from "../utilities/formatter-utils.js";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const ALL_TABS = [
  { id: "hash_tables", label_i18n: "internals.hash_tables", flag: "show_hash_tables" },
  { id: "queues", label_i18n: "internals.queues", flag: "show_queues" },
  { id: "periodic_activities", label_i18n: "internals.periodic_activities", flag: "show_periodic_activities" },
  { id: "checks", label_i18n: "internals.checks", flag: "show_checks" },
];

const visibleTabs = computed(() =>
  ALL_TABS.filter((t) => props.context?.[t.flag] !== false)
);

const activeTab = ref(visibleTabs.value[0]?.id ?? ntopng_url_manager.get_url_entry("tab"));

function switch_tab(tab_name) {
  activeTab.value = tab_name;
  hashTablesFilter.value = htOptions.value[0];
  paScriptFilter.value = paScriptOptions.value[0];
  paIssueFilter.value = paIssueOptions.value[0];
  checkTargetFilter.value = checkTargetOptions.value[0];
  ntopng_url_manager.set_key_to_url("tab", tab_name);

  // Let Vue update the props first, then refresh
  nextTick(() => tableRef.value?.refresh_table());
}

const tableRef = ref(null);

// current table config, managed by active tab
const TABLE_CONFIG_IDS = {
  hash_tables: "internals_hash_tables",
  queues: "internals_queues",
  periodic_activities: "internals_periodic_activities",
  checks: "internals_checks",
};

const currentTableConfigId = computed(() => TABLE_CONFIG_IDS[activeTab.value]);

const currentMapColumns = computed(() => {
  const map = {
    hash_tables: mapHashTableColumns,
    queues: mapQueueColumns,
    periodic_activities: mapPeriodicActivitiesColumns,
    checks: mapChecksColumns,
  };
  return map[activeTab.value];
});

function getExtraParams() {
  const p = { ifid: props.context?.ifid };
  if (activeTab.value === "hash_tables" && hashTablesFilter.value?.value) {
    p.hash_table = hashTablesFilter.value.value;
  }
  if (activeTab.value === "periodic_activities") {
    if (paScriptFilter.value?.value) p.periodic_script = paScriptFilter.value.value;
    if (paIssueFilter.value?.value) p.periodic_script_issue = paIssueFilter.value.value;
  }
  if (activeTab.value === "checks" && checkTargetFilter.value?.value) {
    p.check_target = checkTargetFilter.value.value;
  }
  return p;
}

const ALL_OPTION = { id: "", value: "", label: _i18n("all") };

// Hash Tables
const htOptions = ref([ALL_OPTION]);
const hashTablesFilter = ref(ALL_OPTION);

// Periodic Activities
const paScriptOptions = ref([ALL_OPTION]);
const paScriptFilter = ref(ALL_OPTION);

const paIssueOptions = ref([
  ALL_OPTION,
  { id: "not_executed", value: "not_executed", label: _i18n("internals.periodic_activities_tot_not_executed_descr_short") },
  { id: "is_slow", value: "is_slow", label: _i18n("internals.periodic_activities_tot_running_slow_descr_short") },
  { id: "alerts_drops", value: "alerts_drops", label: _i18n("internals.alerts_drops") },
  { id: "any_issue", value: "any_issue", label: _i18n("internals.any_issue") },
]);
const paIssueFilter = ref(ALL_OPTION);

// Checks
const checkTargetOptions = ref([ALL_OPTION]);
const checkTargetFilter = ref(ALL_OPTION);

function onRowsLoaded(res) {
  const rows = res?.rows ?? [];

  // hash_tables and periodic_activities: one row per unique entity
  if (activeTab.value === "hash_tables" && htOptions.value.length === 1) {
    htOptions.value = [ALL_OPTION, ...rows.filter((r) => r.hash_table).map((r) => ({ id: r.hash_table, value: r.hash_table, label: r.hash_table }))];
  }

  if (activeTab.value === "periodic_activities" && paScriptOptions.value.length === 1) {
    paScriptOptions.value = [ALL_OPTION, ...rows.filter((r) => r.script).map((r) => ({ id: r.script, value: r.script, label: r.script }))];
  }

  // checks: multiple scripts share the same type — deduplicate with Set
  if (activeTab.value === "checks" && checkTargetOptions.value.length === 1) {
    const seen = new Set();
    const opts = [ALL_OPTION];

    rows.forEach((r) => {
      if (r.type && !seen.has(r.type)) {
        seen.add(r.type);
        opts.push({ id: r.type, value: r.type, label: r.type });
      }
    });
    checkTargetOptions.value = opts;
  }
}

function onhashTablesFilter(opt) {
  hashTablesFilter.value = opt;
  tableRef.value?.refresh_table();
}

function onPaFilter(_opt) {
  tableRef.value?.refresh_table();
}

function onCheckTargetFilter(opt) {
  checkTargetFilter.value = opt;
  tableRef.value?.refresh_table();
}

function columnsSorting(col, r0, r1) {
  if (!col) return 0;
  const id = col.id;
  const s = col.sort;

  // numeric columns
  if (["active", "idle", "active_pct", "idle_pct", "free_pct",
    "num_failed_enqueues",
    "periodicity", "max_duration_secs", "last_duration_ms", "busy_pct",
    "tot_not_executed", "tot_running_slow", "ts_writes", "ts_drops",
    "snmp_fat_mibs", "snmp_other_mibs", "last_num_calls",
    "num_filtered", "exec_time_ms"].includes(id)) {
    return sortingFunctions.sortByNumber(r0[id] ?? 0, r1[id] ?? 0, s);
  }

  // string columns
  if (["iface_name", "hash_table", "queue", "script", "state", "name", "type", "hook",
    "availability", "periodicity_label", "max_duration_label", "last_start_ago",
    "last_duration_label"].includes(id)) {
    return sortingFunctions.sortByName(r0[id] ?? "", r1[id] ?? "", s);
  }

  return 0;
}

// Periodic Activities notes
const periodicNotes = computed(() => [
  _i18n("internals.status_description"),
  _i18n("internals.periodic_activities_periodicity_descr"),
  _i18n("internals.periodic_activities_max_duration_secs_descr"),
  _i18n("internals.periodic_activities_last_start_time_descr"),
  _i18n("internals.periodic_activities_tot_not_executed_descr"),
  _i18n("internals.periodic_activities_tot_running_slow_descr"),
  _i18n("internals.periodic_activities_not_shown"),
]);

// map hash table columns
function mapHashTableColumns(columns) {
  const isSystemIface = props.context?.is_sys_iface;

  // Filter out iface_name when not on system interface
  if (!isSystemIface) {
    columns = columns.filter((c) => c.data_field !== "iface_name");
  }

  columns.forEach((c) => {
    if (c.data_field === "iface_name") {
      c.render_func = (_value, row) =>
        `<a href="${http_prefix}/lua/if_stats.lua?ifid=${row.iface_id}">${row.iface_name}</a>`;
    }

    if (c.data_field === "active" || c.data_field === "idle") {
      c.render_func = (value) => (value > 0 ? value.toLocaleString() : "—");
    }

    if (c.data_field === "hash_table") {
      c.render_func = (value, row) => {
        const warn = row.high_idle
          ? `<i class="fas fa-exclamation-triangle text-warning me-1" title="${_i18n("internals.high_idle_entries")}"></i>`
          : "";
        return warn + value;
      };
    }

    if (c.data_field === "active_pct") {
      c.render_func = (_value, row) => {
        if (!row.active && !row.idle) return "—";
        let percentages = [row.active_pct, row.idle_pct, row.free_pct]
        let labels = [_i18n("if_stats_overview.active"), _i18n("flow_checks.idle"), _i18n("flow_checks.free")]

        return NtopUtils.createBreakdown_multi_elem(percentages, labels)
      };
    }
  });
  return columns;
}

function mapQueueColumns(columns) {
  columns.forEach((c) => {
    if (c.data_field === "num_failed_enqueues") {
      c.render_func = (value) =>
        value > 0
          ? `<span class="text-danger fw-semibold">${value.toLocaleString()}</span>`
          : "0";
    }
  });
  return columns;
}

function mapPeriodicActivitiesColumns(columns) {
  columns.forEach((c) => {
    if (c.data_field === "script") {
      c.render_func = (value, row) => {
        const warn =
          row.issues && row.issues.length > 0
            ? `<i class="fas fa-exclamation-triangle text-warning me-1" title="${row.issues.join("&#013;")}"></i>`
            : "";
        return warn + value;
      };
    }

    if (c.data_field === "busy_pct") {
      c.render_func = (_value, row) =>
        NtopUtils.createBreakdown(
          Math.min(100, row.busy_pct || 0),
          Math.min(100, row.available_pct || 0),
          `${_i18n("busy")} ${row.busy_pct}%`,
          `${_i18n("available")} ${row.available_pct}%`
        );
    }

    if (c.data_field === "state") {
      c.render_func = (value) => {
        if (value === "running")
          return `<span class="badge bg-success">${_i18n("running")}</span>`;
        if (value === "queued")
          return `<span class="badge bg-warning text-dark">${_i18n("internals.queued")}</span>`;
        return `<span class="badge bg-secondary">${_i18n("internals.sleeping")}</span>`;
      };
    }

    if (c.data_field === "progress") {
      c.render_func = (value) => (value != null ? value + " %" : "—");
    }

    if (c.data_field === "tot_not_executed" || c.data_field === "tot_running_slow") {
      c.render_func = (value) =>
        value > 0
          ? `<span class="text-warning">${value.toLocaleString()}</span>`
          : "0";
    }

    if (["ts_writes", "ts_drops", "snmp_fat_mibs", "snmp_other_mibs"].includes(c.data_field)) {
      c.render_func = (value) =>
        value != null && value > 0 ? value.toLocaleString() : "—";
    }

    if (["last_start_ago", "last_duration_label", "periodicity_label", "max_duration_label"].includes(c.data_field)) {
      c.render_func = (value) => value || "—";
    }
  });
  return columns;
}

function mapChecksColumns(columns) {
  const formatMs     = formatterUtils.getFormatter("ms");
  const formatNumber = formatterUtils.getFormatter("number");

  columns.forEach((c) => {
    if (c.data_field === "name") {
      // Try i18n key "flow_checks_config.<name>", fall back to raw name
      c.render_func = (value) => {
        return _i18n(`flow_checks_config.${value}`) || value;
      };
    }

    if (c.data_field === "num_filtered") {
      c.render_func = (value) => formatNumber(value ?? 0);
    }

    if (c.data_field === "exec_time_ms") {
      c.render_func = (value) => (value != null ? formatMs(value) : "");
    }

    if (c.data_field === "availability") {
      c.render_func = (value) => {
        if (!value || value === "Community") return value || "Community";
        return `<span class="badge bg-primary">${value}</span>`;
      };
    }
  });
  return columns;
}

onMounted(() => {
  const selected_tab = ntopng_url_manager.get_url_entry("tab");
  console.log(selected_tab)
  switch_tab(selected_tab);
})

</script>

<style scoped>
.internals-progress {
  height: 16px;
  border-radius: 4px;
  background-color: var(--bs-border-color);
  min-width: 120px;
}
</style>
