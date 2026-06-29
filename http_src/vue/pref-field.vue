<!--
  (C) 2014-26 - ntop.org

  Renders a single preference entry based on its type descriptor.
  Props:
    entry      - schema entry from GET /lua/rest/v2/get/ntopng/prefs_schema.lua
    modelValue - current string value (v-model)
    visible    - controlled externally for to_switch logic

  Validation:
    entry.attrs maps directly to HTML attributes (min, max, maxlength, pattern, …).
    entry.validator (optional string) names a validator from ntopng-validators-utils.js
    that is called on every input event; the field shows is-invalid + error message.

  Supported types:
    toggle       -> Bootstrap form-switch
    input        -> text / number / password (entry.input_type)
    input + tformat="hd" -> number input + Hours/Days unit selector (stores seconds)
    select       -> Bootstrap form-select
    button_group -> Bootstrap btn-group (mutually exclusive)
    resolution   -> alias for button_group
    info         -> read-only monospace
-->
<template>
  <div v-show="visible" :id="'pref-row-' + entry.key" class="pref-row" :class="{ 'pref-row--highlight': highlight }">

    <!-- Label / description -->
    <div class="pref-label-col">
      <label :for="'pref-' + entry.key" class="pref-title">{{ entry.title }}</label>
      <div v-if="entry.description" class="pref-desc" v-html="entry.description"></div>
    </div>

    <!-- Control -->
    <div class="pref-ctrl-col">

      <!-- Toggle -->
      <div v-if="entry.type === 'toggle'" class="form-check form-switch mb-0">
        <input
          class="form-check-input"
          type="checkbox"
          role="switch"
          :id="'pref-' + entry.key"
          :checked="effectiveValue === onValue"
          :disabled="entry.disabled"
          style="width:2.25em; height:1.15em; cursor:pointer"
          @change="onToggleChange($event.target.checked)"
        />
      </div>

      <!-- Time selector: unit buttons LEFT of number input -->
      <div v-else-if="entry.type === 'input' && entry.tformat" class="pref-input-wrap">
        <div class="input-group">
          <button
            v-for="u in timeUnits"
            :key="u.key"
            type="button"
            :class="['btn btn-sm', timeUnit === u.key ? 'btn-primary' : 'btn-outline-secondary']"
            :disabled="entry.disabled"
            @click="onTimeUnitChange(u.key)"
          >{{ u.label }}</button>
          <input
            class="form-control"
            :class="{ 'is-invalid': validation_error }"
            type="number"
            :id="'pref-' + entry.key"
            :value="timeDisplayValue"
            :disabled="entry.disabled"
            :min="timeUnitSec > 0 ? Math.ceil((parseInt(entry.attrs && entry.attrs.min) || 0) / timeUnitSec) : 0"
            @input="onTimeInput($event.target.value)"
            @blur="onTimeBlur($event.target.value)"
          />
        </div>
        <div v-if="validation_error" class="invalid-feedback d-block">
          {{ validation_error }}
        </div>
      </div>

      <!-- Text / Number / Password -->
      <div v-else-if="entry.type === 'input'" class="pref-input-wrap">
        <div :class="entry.unit || entry.test_endpoint ? 'input-group' : ''">
          <input
            class="form-control"
            :class="{ 'is-invalid': validation_error }"
            :type="entry.input_type === 'password' ? 'password' : (entry.input_type || 'text')"
            :id="'pref-' + entry.key"
            :value="effectiveValue"
            :disabled="entry.disabled"
            v-bind="entry.attrs || {}"
            @input="onInput($event.target.value)"
            @blur="onBlur($event.target.value)"
          />
          <span v-if="entry.unit" class="input-group-text">{{ entry.unit }}</span>
          <button
            v-if="entry.test_endpoint"
            type="button"
            class="btn btn-sm btn-outline-secondary"
            :disabled="!effectiveValue || test_loading"
            @click="testConnectivity"
          >
            <span v-if="test_loading" class="spinner-border spinner-border-sm me-1" role="status"></span>
            {{ test_loading ? _i18n('prefs.vue_prefs.test_btn_loading') : _i18n('prefs.vue_prefs.test_btn') }}
          </button>
        </div>
        <div v-if="test_result" :class="['mt-1 small', test_result.ok ? 'text-success' : 'text-danger']">
          <i :class="test_result.ok ? 'fas fa-check-circle' : 'fas fa-times-circle'" class="me-1"></i>
          {{ test_result.msg }}
        </div>
        <div v-if="validation_error" class="invalid-feedback d-block">
          {{ validation_error }}
        </div>
      </div>

      <!-- Select -->
      <select
        v-else-if="entry.type === 'select'"
        class="form-select pref-select"
        :id="'pref-' + entry.key"
        :value="effectiveValue"
        :disabled="entry.disabled"
        @change="$emit('update:modelValue', $event.target.value)"
      >
        <option
          v-for="opt in (entry.options || [])"
          :key="opt.value"
          :value="opt.value"
        >{{ opt.label }}</option>
      </select>

      <!-- Button group (multi-option selector / resolution) -->
      <div
        v-else-if="entry.type === 'button_group' || entry.type === 'resolution'"
        class="btn-group"
        role="group"
      >
        <button
          v-for="opt in (entry.options || [])"
          :key="opt.value"
          type="button"
          :disabled="entry.disabled"
          :class="[
            'btn btn-sm',
            effectiveValue === opt.value
              ? 'btn-primary'
              : 'btn-outline-secondary'
          ]"
          @click="$emit('update:modelValue', opt.value)"
        >{{ opt.label }}</button>
      </div>

      <!-- Info (read-only) -->
      <span v-else-if="entry.type === 'info'" class="text-muted font-monospace small">
        {{ effectiveValue }}
      </span>

    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
  entry:         { type: Object,  required: true },
  modelValue:    { type: String,  default: ''   },
  visible:       { type: Boolean, default: true },
  highlight:     { type: Boolean, default: false },
  // key->value map of sibling entries in the same section, for compound tests
  siblingValues: { type: Object,  default: () => ({}) },
});

const emit = defineEmits(['update:modelValue', 'validation-error']);

function _i18n(key) {
  return (typeof window.i18n === 'function' && window.i18n(key)) || key;
}

const validation_error = ref('');
const test_loading     = ref(false);
const test_result      = ref(null); // { ok: bool, msg: string } | null

// on/off value overrides (for inverted toggles)
const onValue  = computed(() => props.entry.on_value  ?? '1');
const offValue = computed(() => props.entry.off_value ?? '0');

// Use modelValue when set; fall back to schema default
const effectiveValue = computed(() =>
  props.modelValue !== '' ? props.modelValue : (props.entry.default ?? '')
);

// Time selector (tformat="hd")
// tformat characters -> multiplier in seconds
const TFORMAT_UNITS = computed(() => ({
  s: { key: 's', label: _i18n('prefs.vue_prefs.time_secs'),  sec: 1     },
  m: { key: 'm', label: _i18n('prefs.vue_prefs.time_mins'),  sec: 60    },
  h: { key: 'h', label: _i18n('prefs.vue_prefs.time_hours'), sec: 3600  },
  d: { key: 'd', label: _i18n('prefs.vue_prefs.time_days'),  sec: 86400 },
}));

const timeUnits = computed(() => {
  if (!props.entry.tformat) return [];
  return props.entry.tformat.split('').map(c => TFORMAT_UNITS.value[c]).filter(Boolean);
});

// pick best unit: largest unit that divides the value evenly
function bestUnit(seconds) {
  const units = [...timeUnits.value].reverse(); // largest first
  for (const u of units) {
    if (seconds % u.sec === 0) return u.key;
  }
  return timeUnits.value[0]?.key ?? 'h';
}

const _seconds = computed(() => parseInt(effectiveValue.value) || 0);
const timeUnit = ref(bestUnit(_seconds.value));
watch(() => effectiveValue.value, (v) => {
  timeUnit.value = bestUnit(parseInt(v) || 0);
}, { immediate: true });

const timeUnitSec = computed(() => TFORMAT_UNITS.value[timeUnit.value]?.sec ?? 1);
const timeDisplayValue = computed(() => {
  const s = _seconds.value;
  return s > 0 ? Math.floor(s / timeUnitSec.value) : s;
});

function onTimeUnitChange(newUnit) {
  const display = timeDisplayValue.value;
  timeUnit.value = newUnit;
  const newSec = display * (TFORMAT_UNITS.value[newUnit]?.sec ?? 1);
  emit('update:modelValue', String(newSec));
}

function onTimeInput(displayVal) {
  const n = parseInt(displayVal);
  if (!isNaN(n) && n > 0) {
    emit('update:modelValue', String(n * timeUnitSec.value));
  }
}

function onTimeBlur(displayVal) {
  const n = parseInt(displayVal);
  if (isNaN(n) || n <= 0) {
    validation_error.value = _i18n('prefs.vue_prefs.validation_must_be_positive');
    emit('validation-error', validation_error.value);
  } else {
    validation_error.value = '';
    emit('validation-error', '');
  }
}

// Validation
function validate(value) {
  if (!value && props.entry.attrs?.required === 'true') {
    return _i18n('prefs.vue_prefs.validation_required');
  }
  if (!value) return '';

  const attrs = props.entry.attrs || {};

  if (props.entry.input_type === 'number' || attrs.type === 'number') {
    const n = parseFloat(value);
    if (isNaN(n)) return _i18n('prefs.vue_prefs.validation_must_be_number');
    if (attrs.min !== undefined && n < parseFloat(attrs.min))
      return _i18n('prefs.vue_prefs.validation_min').replace('%{min}', attrs.min);
    if (attrs.max !== undefined && n > parseFloat(attrs.max))
      return _i18n('prefs.vue_prefs.validation_max').replace('%{max}', attrs.max);
  }

  if (attrs.pattern) {
    try {
      if (!new RegExp(`^(?:${attrs.pattern})$`).test(value))
        return _i18n('prefs.vue_prefs.validation_invalid_format');
    } catch (_) { /* ignore malformed pattern */ }
  }

  if (attrs.maxlength && value.length > parseInt(attrs.maxlength)) {
    return _i18n('prefs.vue_prefs.validation_maxlength').replace('%{max}', attrs.maxlength);
  }

  const validatorName = props.entry.validator;
  if (validatorName && window.NtopUtils) {
    const u = window.NtopUtils;
    if (validatorName === 'ipAddress') {
      if (!u.is_good_ipv4(value) && !u.is_good_ipv6(value))
        return _i18n('prefs.vue_prefs.validation_invalid_ip');
    } else if (validatorName === 'ipv4') {
      if (!u.is_good_ipv4(value)) return _i18n('prefs.vue_prefs.validation_invalid_ipv4');
    } else if (validatorName === 'mac') {
      if (!u.is_mac_address(value)) return _i18n('prefs.vue_prefs.validation_invalid_mac');
    } else if (validatorName === 'network') {
      if (!u.is_network_mask(value, true)) return _i18n('prefs.vue_prefs.validation_invalid_network');
    }
  }

  return '';
}

function onInput(value) {
  const err = validate(value);
  validation_error.value = err;
  emit('validation-error', err);
  if (!err) emit('update:modelValue', value);
}

function onBlur(value) {
  const err = validate(value);
  validation_error.value = err;
  emit('validation-error', err);
}

async function testConnectivity() {
  if (!props.entry.test_endpoint || !effectiveValue.value) return;
  test_loading.value = true;
  test_result.value  = null;
  try {
    // Always send the current field value as "url" and the entry key for provider detection
    const params = { url: effectiveValue.value, llm_key: props.entry.key };
    // Pull any extra sibling keys declared in entry.test_params
    for (const [paramName, siblingKey] of Object.entries(props.entry.test_params || {})) {
      params[paramName] = props.siblingValues[siblingKey] ?? '';
    }
    const qs  = new URLSearchParams(params);
    const res = await fetch(`${props.entry.test_endpoint}?${qs}`);
    const data = await res.json();
    const ok = data?.rc === 0;
    test_result.value = {
      ok,
      msg: data?.rsp?.message || _i18n(ok ? 'prefs.vue_prefs.connection_successful' : 'prefs.vue_prefs.connection_failed'),
    };
  } catch (_) {
    test_result.value = { ok: false, msg: _i18n('prefs.vue_prefs.request_failed') };
  } finally {
    test_loading.value = false;
  }
}

function onToggleChange(checked) {
  emit('update:modelValue', checked ? onValue.value : offValue.value);
}
</script>

<style scoped>
.pref-row {
  display: flex;
  align-items: center;
  gap: 1.25rem;
  padding: 0.875rem 1.25rem;
  border-bottom: 1px solid var(--border-color, #dee2e6);
  background: var(--bg-surface, #fff);
}
.pref-row:last-child {
  border-bottom: none;
}
.pref-row--highlight {
  background: rgba(255, 143, 0, 0.08);
  border-left: 3px solid var(--ntop-orange, #FF8F00);
  padding-left: calc(1.25rem - 3px);
  transition: background 0.3s, border-left-color 0.3s;
}

/* Label side */
.pref-label-col {
  flex: 1;
  min-width: 0;
}
.pref-title {
  display: block;
  font-size: 0.875rem;
  font-weight: 400;
  color: var(--ntop-text-color, #111);
  line-height: 1.3;
  margin-bottom: 0;
  cursor: default;
}
.pref-desc {
  font-size: 0.78rem;
  color: var(--ntop-muted-text-color, #6c757d);
  margin-top: 0.2rem;
  line-height: 1.45;
}

/* Control side */
.pref-ctrl-col {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  min-width: 200px;
  max-width: 320px;
  width: 100%;
}
.pref-input-wrap {
  width: 100%;
}
.form-control,
.pref-select {
  font-size: 0.875rem;
  width: 100%;
}
/* Keep input-group in one row — override any width that forces wrapping */
.pref-input-wrap .input-group {
  display: flex;
  flex-wrap: nowrap;
  align-items: stretch;
}
.pref-input-wrap .input-group .form-control {
  flex: 1 1 0;
  width: 0;         /* let flex size it, not the 100% above */
  min-width: 4rem;
}
</style>
