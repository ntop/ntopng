<!-- (C) 2026 - ntop.org -->
<template>
  <div class="page-edit-check">

    <!-- alerts -->
    <div v-if="error_msg" class="alert alert-danger alert-dismissible mb-3" role="alert">
      {{ error_msg }}
      <button type="button" class="btn-close" @click="error_msg = null"></button>
    </div>
    <div v-if="success_msg" class="alert alert-success alert-dismissible mb-3" role="alert">
      {{ success_msg }}
      <button type="button" class="btn-close" @click="success_msg = null"></button>
    </div>

    <!-- loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
    </div>

    <div v-else-if="load_error" class="alert alert-danger">{{ load_error }}</div>

    <template v-else-if="edit_data">

      <!-- check info header -->
      <div class="alert border mb-3">
        <div class="row align-items-start">
          <div v-if="edit_data.gui?.category_icon" class="col-12 col-sm-2">
            <strong>{{ _i18n('edit_check.category') }}</strong><br>
            <i :class="edit_data.gui.category_icon"></i>
            {{ edit_data.gui.category_label }}
          </div>
          <div class="col-12 col-sm-10">
            <strong>{{ _i18n('edit_check.description') }}</strong><br>
            <span v-html="edit_data.gui.description"></span>
          </div>
        </div>
      </div>

      <!-- form fields -->
      <div v-for="(hook_conf, hook_name) in edit_form" :key="hook_name" class="mb-3">
        <div v-if="Object.keys(edit_form).length > 1" class="d-flex align-items-center gap-2 mb-2">
          <div class="form-check form-switch mb-0">
            <input type="checkbox" class="form-check-input" :id="`hook-enabled-${hook_name}`"
              v-model="hook_conf.enabled" style="cursor:pointer;" />
            <label class="form-check-label fw-semibold" :for="`hook-enabled-${hook_name}`">
              {{ edit_data.hooks[hook_name]?.label || hook_name }}
            </label>
          </div>
        </div>

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

                <!-- Threshold object -->
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

                <!-- Time field: Minutes/Hours/Days -->
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

                <!-- Bytes field: KB/MB/GB -->
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

                <!-- Operator select -->
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

      <!-- footer actions -->
      <div class="mt-4 d-flex gap-2">
        <button class="btn btn-outline-danger me-auto" :disabled="saving" @click="reset_to_defaults">
          <i class="fas fa-undo-alt me-1"></i>{{ _i18n('scripts_list.reset_default') }}
        </button>
        <a :href="props.context.back_url" class="btn btn-secondary">{{ _i18n('cancel') }}</a>
        <button class="btn btn-primary" :disabled="saving" @click="save">
          <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
          {{ _i18n('save') }}
        </button>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({ context: Object });

const loading     = ref(true);
const load_error  = ref(null);
const saving      = ref(false);
const error_msg   = ref(null);
const success_msg = ref(null);
const edit_data   = ref(null);
const edit_form   = reactive({});

const bytes_unit = reactive({});
const time_unit  = reactive({});

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

// field type helpers

function is_bytes_field(field)   { return field.includes("bytes"); }
function is_threshold_field(val) { return val !== null && typeof val === "object" && !Array.isArray(val); }
function is_time_field(field)    { return edit_data.value?.gui?.input_builder === "long_lived" && field === "min_duration"; }
function has_config_fields(h)    { return Object.keys(h.script_conf || {}).length > 0; }

// threshold helpers

function threshold_val(fc)         { return fc.threshold ?? fc.default_value ?? 0; }

function threshold_enabled(fc, hc) { return fc.enabled ?? hc.enabled ?? true; }

function threshold_op(fc, field) {
  return fc.operator ?? fc.field_operator
    ?? edit_data.value?.field_metadata?.[field]?.field_operator ?? "gt";
}

function update_threshold(hook_conf, field, key, value) {
  const cur = hook_conf.script_conf[field];
  hook_conf.script_conf[field] = {
    enabled:   key === "enabled"   ? value : (cur.enabled   ?? hook_conf.enabled ?? true),
    operator:  key === "operator"  ? value : threshold_op(cur, field),
    threshold: key === "threshold" ? value : threshold_val(cur),
  };
  hook_conf.enabled = Object.values(hook_conf.script_conf).some(
    (f) => is_threshold_field(f) && f.enabled !== false
  );
}

// bytes helpers

function best_unit_for(b) { return b >= 1073741824 ? 1073741824 : b >= 1048576 ? 1048576 : 1024; }
function bytes_display_value(raw, hn, f) { return Math.round(raw / (bytes_unit[hn + "." + f] || 1024)); }
function set_bytes_unit(hn, f, m)        { bytes_unit[hn + "." + f] = m; }
function set_bytes_value(hn, f, v, hc)  { hc.script_conf[f] = (parseInt(v) || 0) * (bytes_unit[hn + "." + f] || 1024); }

// time helpers

function best_time_unit_for(s) { return s >= 86400 ? 86400 : s >= 3600 ? 3600 : 60; }
function time_display_value(raw, hn, f) { return Math.round(raw / (time_unit[hn + "." + f] || 60)); }
function time_max(hn, f) { return TIME_UNITS.find((u) => u.mult === (time_unit[hn + "." + f] || 60))?.max ?? 59; }
function set_time_unit(hn, f, m)        { time_unit[hn + "." + f] = m; }
function set_time_value(hn, f, v, hc)  { hc.script_conf[f] = (parseInt(v) || 0) * (time_unit[hn + "." + f] || 60); }

// form population

function populate_form(data) {
  for (const k of Object.keys(bytes_unit)) delete bytes_unit[k];
  for (const k of Object.keys(time_unit))  delete time_unit[k];
  for (const k of Object.keys(edit_form))  delete edit_form[k];
  for (const [hook, conf] of Object.entries(data.hooks || {})) {
    edit_form[hook] = {
      enabled: conf.enabled,
      script_conf: JSON.parse(JSON.stringify(conf.script_conf || {})),
    };
    for (const [field, val] of Object.entries(conf.script_conf || {})) {
      if (is_bytes_field(field) && typeof val === "number")
        bytes_unit[hook + "." + field] = best_unit_for(val);
      if (data.gui?.input_builder === "long_lived" && field === "min_duration" && typeof val === "number")
        time_unit[hook + "." + field] = best_time_unit_for(val);
    }
  }
}

async function fetch_config(factory = false) {
const url = `${http_prefix}/lua/rest/v2/get/checks/check_config.lua`
+ `?check_subdir=${encodeURIComponent(props.context.check_subdir)}`
+ `&script_key=${encodeURIComponent(props.context.script_key)}`
    + (factory ? "&factory=true" : "");
  const data = await ntopng_utility.http_request(url);
  if (!data) throw new Error("empty");
  return data;
}

async function reset_to_defaults() {
  load_error.value = null;
  loading.value = true;
  try {
    const data = await fetch_config(true);
    edit_data.value = data;
    populate_form(data);
  } catch {
    load_error.value = _i18n("request_failed_message");
  } finally {
    loading.value = false;
  }
}

async function save() {
  error_msg.value = null;
  saving.value = true;
  try {
    const rsp = await ntopng_utility.http_post_request(
      `${http_prefix}/lua/rest/v2/set/checks/check_config.lua`,
      {
        check_subdir: props.context.check_subdir,
        script_key:   props.context.script_key,
        JSON:         JSON.stringify(edit_form),
        csrf:         props.context.page_csrf,
      }
    );
    if (rsp === null) {
      error_msg.value = _i18n("request_failed_message");
      return;
    }
    success_msg.value = _i18n("changes_applied");
  } catch {
    error_msg.value = _i18n("request_failed_message");
  } finally {
    saving.value = false;
  }
}

onMounted(async () => {
  try {
    const data = await fetch_config();
    edit_data.value = data;
    populate_form(data);
  } catch {
    load_error.value = _i18n("request_failed_message");
  } finally {
    loading.value = false;
  }
});
</script>
