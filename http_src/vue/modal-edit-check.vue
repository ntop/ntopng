<!-- (C) 2026 - ntop.org -->
<template>
  <modal ref="modal_id" @showed="showed()">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <div v-if="loading" class="text-center py-5">
        <div class="spinner-border text-primary"></div>
      </div>

      <div v-else-if="load_error" class="alert alert-danger mb-0">{{ load_error }}</div>

      <template v-else>
        <p v-if="edit_data?.gui?.description" class="text-muted small mb-3"
          v-html="edit_data.gui.description"></p>

        <!-- one section per hook -->
        <div v-for="(hook_conf, hook_name) in edit_form" :key="hook_name" class="mb-3">
          <div v-if="Object.keys(edit_form).length > 1" class="d-flex align-items-center gap-2 mb-2">
            <div class="form-check form-switch mb-0">
              <input type="checkbox" class="form-check-input" :id="`hook-enabled-${hook_name}`"
                v-model="hook_conf.enabled" style="cursor:pointer;" />
              <label class="form-check-label" :for="`hook-enabled-${hook_name}`">
                {{ edit_data.hooks[hook_name]?.label || hook_name }}
              </label>
            </div>
          </div>

          <!-- only render body if there are configurable fields -->
          <div v-if="has_config_fields(hook_conf)"
            :class="{ 'opacity-50 pe-none': Object.keys(edit_form).length > 1 && !hook_conf.enabled }">
            <div class="row g-2">
              <!-- severity selector -->
              <div v-if="'severity' in hook_conf.script_conf" class="col-sm-6">
                <label class="form-label small fw-semibold">{{ _i18n('severity') }}</label>
                <select class="form-select form-select-sm" v-model="hook_conf.script_conf.severity.severity_id">
                  <option v-for="sev in edit_data.severities" :key="sev.id" :value="sev.id">
                    {{ sev.label }}
                  </option>
                </select>
              </div>
              <!-- other script_conf fields -->
              <template v-for="(_val, field) in hook_conf.script_conf" :key="field">
                <div v-if="field !== 'severity'"
                  :class="is_threshold_field(hook_conf.script_conf[field]) || is_bytes_field(field) || is_time_field(field) || Array.isArray(hook_conf.script_conf[field]) || typeof hook_conf.script_conf[field] === 'string' ? 'col-12' : 'col-sm-6'">

                  <!-- label: threshold uses field_metadata title; array uses input_title; time fields have no outer label; others use i18n -->
                  <label v-if="!is_time_field(field)" class="form-label small fw-semibold text-capitalize">
                    <template v-if="is_threshold_field(hook_conf.script_conf[field])">
                      {{ edit_data?.field_metadata?.[field]?.title || _i18n(field) || field }}
                    </template>
                    <template v-else-if="Array.isArray(hook_conf.script_conf[field]) && edit_data?.gui?.input_title">
                      {{ edit_data.gui.input_title }}
                    </template>
                    <template v-else>
                      {{ _i18n(field) || field }}
                    </template>
                  </label>

                  <!-- Threshold object (multi_threshold_cross): enabled toggle + operator + number + unit -->
                  <div v-if="is_threshold_field(hook_conf.script_conf[field])" class="d-flex align-items-center gap-2">
                    <div class="form-check form-switch mb-0">
                      <input type="checkbox" class="form-check-input"
                        :checked="threshold_enabled(hook_conf.script_conf[field], hook_conf)"
                        @change="update_threshold(hook_conf, field, 'enabled', $event.target.checked)"
                        style="cursor:pointer;" />
                    </div>
                    <select class="form-select form-select-sm" style="width:auto;"
                      :value="threshold_op(hook_conf.script_conf[field], field)"
                      @change="update_threshold(hook_conf, field, 'operator', $event.target.value)">
                      <option value="gt">&gt;</option>
                      <option value="lt">&lt;</option>
                    </select>
                    <input type="number" class="form-control form-control-sm" style="width:120px;"
                      :value="threshold_val(hook_conf.script_conf[field])"
                      :min="edit_data?.field_metadata?.[field]?.field_min"
                      :max="edit_data?.field_metadata?.[field]?.field_max"
                      @input="update_threshold(hook_conf, field, 'threshold', parseInt($event.target.value) || 0)" />
                    <span v-if="edit_data?.field_metadata?.[field]?.fields_unit" class="text-muted small text-nowrap">
                      {{ edit_data.field_metadata[field].fields_unit }}
                    </span>
                  </div>

                  <!-- Time field (long_lived: min_duration): Minutes/Hours/Days selector + number input -->
                  <div v-else-if="is_time_field(field)" class="d-flex align-items-center gap-2">
                    <div class="btn-group btn-group-sm" role="group">
                      <button v-for="u in TIME_UNITS" :key="u.mult" type="button"
                        :class="['btn', time_unit[hook_name + '.' + field] === u.mult ? 'btn-primary' : 'btn-secondary']"
                        @click="set_time_unit(hook_name, field, u.mult)">
                        {{ _i18n(u.label_i18n) }}
                      </button>
                    </div>
                    <input type="number" class="form-control form-control-sm" style="width:120px;" min="1"
                      :max="time_max(hook_name, field)"
                      :value="time_display_value(hook_conf.script_conf[field], hook_name, field)"
                      @input="e => set_time_value(hook_name, field, e.target.value, hook_conf)" />
                  </div>

                  <!-- Bytes field: KB/MB/GB selector + number input -->
                  <div v-else-if="is_bytes_field(field)" class="d-flex align-items-center gap-2">
                    <div class="btn-group btn-group-sm" role="group">
                      <button v-for="u in BYTE_UNITS" :key="u.label" type="button"
                        :class="['btn', bytes_unit[hook_name + '.' + field] === u.mult ? 'btn-primary' : 'btn-secondary']"
                        @click="set_bytes_unit(hook_name, field, u.mult)">
                        {{ u.label }}
                      </button>
                    </div>
                    <input type="number" class="form-control form-control-sm" style="width:120px;" min="1"
                      :value="bytes_display_value(hook_conf.script_conf[field], hook_name, field)"
                      @input="e => set_bytes_value(hook_name, field, e.target.value, hook_conf)" />
                  </div>

                  <!-- Array: one entry per line textarea -->
                  <template v-else-if="Array.isArray(hook_conf.script_conf[field])">
                    <textarea class="form-control form-control-sm font-monospace" rows="5"
                      :value="hook_conf.script_conf[field].join('\n')"
                      @change="e => hook_conf.script_conf[field] = e.target.value.split(/[\n,]/).map(s => s.trim()).filter(s => s !== '')"
                      placeholder="One entry per line"></textarea>
                    <div v-if="edit_data?.gui?.input_description" class="form-text text-muted small mt-1">
                      {{ edit_data.gui.input_description }}
                    </div>
                  </template>

                  <!-- Operator: gt / lt select -->
                  <select v-else-if="field === 'operator'" class="form-select form-select-sm"
                    v-model="hook_conf.script_conf[field]">
                    <option value="gt">&gt; (above threshold)</option>
                    <option value="lt">&lt; (below threshold)</option>
                  </select>

                  <!-- Number -->
                  <input v-else-if="typeof hook_conf.script_conf[field] === 'number'" type="number"
                    class="form-control form-control-sm" v-model.number="hook_conf.script_conf[field]" />

                  <!-- String / other -->
                  <input v-else type="text" class="form-control form-control-sm"
                    v-model="hook_conf.script_conf[field]" />
                </div>
              </template>
            </div>
          </div>
        </div>

        <div v-if="save_error" class="alert alert-danger mt-2 mb-0">{{ save_error }}</div>
      </template>
    </template>
    <template v-slot:footer>
      <button class="btn btn-sm btn-outline-secondary me-auto" :disabled="saving || loading"
        @click="reset_to_defaults">
        <i class="fas fa-undo-alt me-1"></i>{{ _i18n('scripts_list.reset_default') }}
      </button>
      <button class="btn btn-secondary" @click="modal_id.close()">{{ _i18n('cancel') }}</button>
      <button class="btn btn-primary" :disabled="saving || loading || !!load_error" @click="save">
        <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
        {{ _i18n('save') }}
      </button>
    </template>
  </modal>
</template>

<script setup>
import { ref, reactive } from "vue";
import { default as modal } from "./modal.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({ page_csrf: String });
const emit = defineEmits(["saved"]);

const modal_id = ref(null);
const title = ref("");
const loading = ref(false);
const load_error = ref(null);
const saving = ref(false);
const save_error = ref(null);
const edit_data = ref(null);
const edit_form = reactive({});

// Bytes unit state: key = "hookName.fieldName", value = multiplier
const bytes_unit = reactive({});
// Time unit state: key = "hookName.fieldName", value = multiplier (seconds)
const time_unit = reactive({});

const BYTE_UNITS = [
  { label: "KB", mult: 1024 },
  { label: "MB", mult: 1048576 },
  { label: "GB", mult: 1073741824 },
];

const TIME_UNITS = [
  { label_i18n: "metrics.minutes", mult: 60,    max: 59  },
  { label_i18n: "metrics.hours",   mult: 3600,  max: 23  },
  { label_i18n: "metrics.days",    mult: 86400, max: 365 },
];

let current_row = null;

const showed = () => {};

// field type helpers

function is_bytes_field(field) {
  return field.includes("bytes");
}

// threshold object: non-null object multi_threshold_cross fields
function is_threshold_field(val) {
  return val !== null && typeof val === "object" && !Array.isArray(val);
}

// threshold field helpers

function threshold_val(field_conf) {
  // stored format uses 'threshold'; default_value format uses 'default_value'
  return field_conf.threshold ?? field_conf.default_value ?? 0;
}

function threshold_op(field_conf, field) {
  return field_conf.operator
    ?? field_conf.field_operator
    ?? edit_data.value?.field_metadata?.[field]?.field_operator
    ?? "gt";
}

function threshold_enabled(field_conf, hook_conf) {
  return field_conf.enabled ?? hook_conf.enabled ?? true;
}

function update_threshold(hook_conf, field, key, value) {
  const cur = hook_conf.script_conf[field];
  // normalise to the saved format {enabled, operator, threshold}
  hook_conf.script_conf[field] = {
    enabled:   key === "enabled"   ? value : (cur.enabled ?? hook_conf.enabled ?? true),
    operator:  key === "operator"  ? value : threshold_op(cur, field),
    threshold: key === "threshold" ? value : threshold_val(cur),
  };
  // keep hook-level enabled in sync: true if at least one field is enabled
  hook_conf.enabled = Object.values(hook_conf.script_conf).some(
    (f) => is_threshold_field(f) && (f.enabled !== false)
  );
}

// bytes field helpers

function best_unit_for(bytes) {
  if (bytes >= 1073741824) return 1073741824;
  if (bytes >= 1048576) return 1048576;
  return 1024;
}

function bytes_display_value(raw, hook_name, field) {
  const mult = bytes_unit[hook_name + "." + field] || 1024;
  return Math.round(raw / mult);
}

function set_bytes_unit(hook_name, field, mult) {
  bytes_unit[hook_name + "." + field] = mult;
}

function set_bytes_value(hook_name, field, input_val, hook_conf) {
  const mult = bytes_unit[hook_name + "." + field] || 1024;
  hook_conf.script_conf[field] = (parseInt(input_val) || 0) * mult;
}

//  time field helpers (long_lived: min_duration in seconds) 

function is_time_field(field) {
  return edit_data.value?.gui?.input_builder === "long_lived" && field === "min_duration";
}

function best_time_unit_for(seconds) {
  if (seconds >= 86400) return 86400;
  if (seconds >= 3600) return 3600;
  return 60;
}

function time_display_value(raw, hook_name, field) {
  const mult = time_unit[hook_name + "." + field] || 60;
  return Math.round(raw / mult);
}

function time_max(hook_name, field) {
  const mult = time_unit[hook_name + "." + field] || 60;
  return TIME_UNITS.find((u) => u.mult === mult)?.max ?? 59;
}

function set_time_unit(hook_name, field, mult) {
  time_unit[hook_name + "." + field] = mult;
}

function set_time_value(hook_name, field, input_val, hook_conf) {
  const mult = time_unit[hook_name + "." + field] || 60;
  hook_conf.script_conf[field] = (parseInt(input_val) || 0) * mult;
}

// form population

function has_config_fields(hook_conf) {
  return Object.keys(hook_conf.script_conf || {}).length > 0;
}

function populate_form(data) {
  for (const k of Object.keys(bytes_unit)) delete bytes_unit[k];
  for (const k of Object.keys(time_unit)) delete time_unit[k];
  for (const k of Object.keys(edit_form)) delete edit_form[k];
  for (const [hook, conf] of Object.entries(data.hooks || {})) {
    edit_form[hook] = {
      enabled: conf.enabled,
      script_conf: JSON.parse(JSON.stringify(conf.script_conf || {})),
    };
    for (const [field, val] of Object.entries(conf.script_conf || {})) {
      if (is_bytes_field(field) && typeof val === "number") {
        bytes_unit[hook + "." + field] = best_unit_for(val);
      }
      if (data.gui?.input_builder === "long_lived" && field === "min_duration" && typeof val === "number") {
        time_unit[hook + "." + field] = best_time_unit_for(val);
      }
    }
  }
}


async function fetch_config(row, factory = false) {
  const url =
    `${http_prefix}/lua/rest/v2/get/checks/check_config.lua` +
    `?check_subdir=${encodeURIComponent(row.subdir)}` +
    `&script_key=${encodeURIComponent(row.key)}` +
    (factory ? "&factory=true" : "");
    
  const data = await ntopng_utility.http_request(url);
  if (!data) throw new Error("empty");
  return data;
}

const show = async (row) => {
  current_row = row;
  title.value = row.title || "…";
  load_error.value = null;
  save_error.value = null;
  loading.value = true;
  edit_data.value = null;
  for (const k of Object.keys(edit_form)) delete edit_form[k];
  modal_id.value.show();

  try {
    const data = await fetch_config(row);
    edit_data.value = data;
    populate_form(data);
  } catch {
    load_error.value = _i18n("request_failed_message");
  } finally {
    loading.value = false;
  }
};

const reset_to_defaults = async () => {
  if (!current_row) return;
  load_error.value = null;
  loading.value = true;
  try {
    const data = await fetch_config(current_row, true);
    edit_data.value = data;
    populate_form(data);
  } catch {
    load_error.value = _i18n("request_failed_message");
  } finally {
    loading.value = false;
  }
};

const save = async () => {
  if (!current_row) return;
  save_error.value = null;
  saving.value = true;
  try {
    const rsp = await ntopng_utility.http_post_request(
      `${http_prefix}/lua/rest/v2/set/checks/check_config.lua`,
      {
        check_subdir: current_row.subdir,
        script_key: current_row.key,
        JSON: JSON.stringify(edit_form),
        csrf: props.page_csrf,
      }
    );
    if (rsp === null) {
      save_error.value = _i18n("request_failed_message");
      return;
    }
    modal_id.value.close();
    emit("saved");
  } catch {
    save_error.value = _i18n("request_failed_message");
  } finally {
    saving.value = false;
  }
};

defineExpose({ show });
</script>
