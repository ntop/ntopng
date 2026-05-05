<!--
  (C) 2024 - ntop.org
  AI Audit Log — shows actions taken by LLM agent and direct user AI interactions.
-->
<template>
  <div class="m-2 mb-3">
    
    <TableWithConfig
      ref="table_ref"
      table_config_id="ai_audit_log"
      :get_extra_params_obj="get_extra_params"
      :f_map_columns="map_columns"
      :f_sort_rows="columns_sorting"
      @rows_loaded="on_rows_loaded"
    >
      <template v-slot:custom_header>
        <!-- Inline dropdown filters -->
        <div class="dropdown d-inline-block" v-for="item in filter_table_array" :key="item.id">
          <span class="no-wrap d-flex align-items-center filters-label">
            <b>{{ item.basic_label }}</b>
          </span>
          <SelectSearch
            v-model:selected_option="item.current_option"
            theme="bootstrap-5"
            dropdown_size="small"
            :options="item.options"
            @select_option="(opt) => add_filter(item.id, opt)"
          />
        </div>
        <!-- Reset button -->
        <div class="d-inline-block">
          <span class="no-wrap d-flex align-items-center filters-label">&nbsp;</span>
          <div class="btn btn-sm btn-primary" type="button" @click="reset_filters">
            {{ _i18n("reset") }}
          </div>
        </div>
        <!-- Time range picker -->
        <div class="d-inline-block">
          <span class="no-wrap d-flex align-items-center filters-label">&nbsp;</span>
          <DateTimeRangePicker
            :id="DATE_PICKER_ID"
            class="ms-1"
            :enable_refresh="true"
            ref="date_time_picker"
            @epoch_change="on_epoch_change"
            :custom_time_interval_list="time_preset_list"
          />
        </div>
      </template>
    </TableWithConfig>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as TableWithConfig }     from "./table-with-config.vue";
import { default as SelectSearch }        from "./select-search.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as sortingFunctions }    from "../utilities/sorting-utils.js";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import formatterUtils from "../utilities/formatter-utils.js";

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

const DATE_PICKER_ID = "ai_audit_date_picker";
const ALL_OPTION     = { value: "", label: _i18n("all") };

const table_ref = ref(null);

// Each filter entry: { id, basic_label, current_option, options[] }
const filter_table_array = ref([
  {
    id: "username",
    basic_label: _i18n("llm.user"),
    current_option: { ...ALL_OPTION },
    options: [{ ...ALL_OPTION }],
  },
  {
    id: "triggered_by",
    basic_label: _i18n("triggered_by"),
    current_option: { ...ALL_OPTION },
    options: [
      { ...ALL_OPTION },
      { value: "llm",  label: _i18n("llm.llm_agent") },
      { value: "user", label: _i18n("llm.direct_user") },
    ],
  },
  {
    id: "tool_name",
    basic_label: _i18n("llm.tool_name"),
    current_option: { ...ALL_OPTION },
    options: [{ ...ALL_OPTION }],
  },
]);

const time_preset_list = [
  { value: "hour",    label: i18n("show_alerts.presets.hour"),    currently_active: false },
  { value: "6_hours", label: i18n("show_alerts.presets.6_hours"), currently_active: false },
  { value: "day",     label: i18n("show_alerts.presets.day"),     currently_active: true  },
  { value: "week",    label: i18n("show_alerts.presets.week"),    currently_active: false },
  { value: "month",   label: i18n("show_alerts.presets.month"),   currently_active: false },
  { value: "custom",  label: i18n("show_alerts.presets.custom"),  currently_active: false, disabled: true },
];

// Build query params from date picker + active filters
function get_extra_params() {
  const params = ntopng_url_manager.get_url_object();
  filter_table_array.value.forEach((f) => {
    if (f.current_option?.value) params[f.id] = f.current_option.value;
  });
  return params;
}

function add_filter(filter_id, opt) {
  const entry = filter_table_array.value.find((f) => f.id === filter_id);
  if (entry) entry.current_option = opt;
  table_ref.value?.refresh_table();
}

function reset_filters() {
  filter_table_array.value.forEach((f) => { f.current_option = { ...ALL_OPTION }; });
  table_ref.value?.refresh_table();
}

function on_epoch_change() {
  table_ref.value?.refresh_table();
}

// Populate username and tool_name dropdowns from rows
function on_rows_loaded(rows) {
  if (!rows || !Array.isArray(rows)) return;
  const username_filter  = filter_table_array.value.find((f) => f.id === "username");
  const tool_name_filter = filter_table_array.value.find((f) => f.id === "tool_name");

  const existing_usernames  = new Set(username_filter.options.slice(1).map((o) => o.value));
  const existing_tool_names = new Set(tool_name_filter.options.slice(1).map((o) => o.value));

  rows.forEach((r) => {
    if (r.username && !existing_usernames.has(r.username)) {
      existing_usernames.add(r.username);
      username_filter.options.push({ value: r.username, label: r.username });
    }
    if (r.tool_name && !existing_tool_names.has(r.tool_name)) {
      existing_tool_names.add(r.tool_name);
      tool_name_filter.options.push({ value: r.tool_name, label: r.tool_name });
    }
  });
}

// Column renderers
async function map_columns(columns) {
  columns.forEach((c) => {

    if (c.id === "tool_name") {
      c.render_func = (val) => {
        if (!val) return "";
        const key = `llm.tool_${val}`;
        const label = _i18n(key);
        // fall back to the raw tool name if no i18n key exists
        return (label && label !== key) ? label : val;
      };
    }
    if (c.id === "timestamp") {
      c.render_func = (val) => {
        if (!val) return "";
        return formatterUtils.formatDateTime(val);
      };
    }
    if (c.id === "triggered_by") {
      c.render_func = (val) =>
        val === "llm"
          ? `<span class="badge bg-primary">${_i18n("llm.llm_agent")}</span>`
          : `<span class="badge bg-secondary">${_i18n("llm.direct_user")}</span>`;
    }
    if (c.id === "content") {
      c.render_func = (val) => {
        if (!val || val === "") return "<em class='text-muted'>—</em>";
        const str   = typeof val === "object" ? JSON.stringify(val, null, 0) : String(val);
        return `<code class="small text-break" title="${str.replace(/"/g, "&quot;")}">${str}</code>`;
      };
    }
  });
  return columns;
}

// Sorting
const SORT_FIELDS = {
  timestamp:    { getter: (r) => r.timestamp,        fn: sortingFunctions.sortByNumber },
  username:     { getter: (r) => r.username,         fn: sortingFunctions.sortByName   },
  triggered_by: { getter: (r) => r.triggered_by,     fn: sortingFunctions.sortByName   },
  tool_name:    { getter: (r) => r.tool_name,        fn: sortingFunctions.sortByName   },
  action_label: { getter: (r) => r.action_label,     fn: sortingFunctions.sortByName   },
  success:      { getter: (r) => r.success ? 1 : 0,  fn: sortingFunctions.sortByNumber },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}

onMounted(() => {
  // if epoch_end is not set, put it as now
  const epoch_end = ntopng_url_manager.get_url_entry("epoch_end");

  if (!epoch_end) {
    ntopng_url_manager.set_key_to_url("epoch_end", Date.now());
  }
})
</script>

<style scoped>
code.small {
  font-size: 0.78em;
  word-break: break-all;
}
</style>
