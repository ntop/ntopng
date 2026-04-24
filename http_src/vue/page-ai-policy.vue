<!-- (C) 2013-26 - ntop.org -->
<!-- AI Policy Generator — Natural language description -> LLM -> SQL policy JSON -->
<template>
  <div class="m-2 mb-3">

    <ModalDeleteAiPolicy ref="modal_delete" @delete="confirm_delete_policy" />
    <ModalEditAiPolicy   ref="modal_edit"   @edit="on_edit_policy" />

    <!-- Provider warning -->
    <div v-if="!loadingProviders && providers.length === 0" class="ap-warning-banner mb-3">
      <i class="fas fa-exclamation-triangle me-2"></i>
      {{ _i18n('llm.no_provider_configured') }}
      <a :href="settingsUrl" class="ap-warning-link ms-auto">{{ _i18n('llm.add_llm') }} <i class="fas fa-arrow-right ms-1"></i></a>
    </div>

    <!-- Generator card -->
    <div class="card mb-3">
      <div class="card-header d-flex align-items-center">
        <i class="fas fa-magic me-2 ap-orange"></i>
        <span class="fw-semibold">{{ _i18n('llm.generate_policy') }}</span>
        <button v-if="creatorStep === 'result'" class="btn btn-sm btn-outline-secondary ms-auto" @click="reset">
          <i class="fas fa-arrow-left me-1"></i> {{ _i18n('new') }}
        </button>
      </div>
      <div class="card-body">

        <!-- Step 1: input -->
        <div v-if="creatorStep === 'input'">
          <label class="ap-field-label">{{ _i18n('llm.describe_policy') }}</label>
          <p class="ap-field-hint">
            {{ _i18n('llm.policy_explanation') }}
          </p>

          <div class="ap-chips mb-3">
            <span class="ap-chip" v-for="ex in examples" :key="ex" @click="nlInput = ex">{{ ex }}</span>
          </div>

          <textarea v-model="nlInput" class="form-control form-control-sm" rows="4" :disabled="generating"
            placeholder="e.g. Alert if any traffic other than SSH (port 22) or PostgreSQL (port 5432) reaches our database server at 10.0.0.5…">
          </textarea>

          <div class="mt-3 d-flex align-items-end gap-3 flex-wrap">
            <div>
              <label class="ap-field-label">{{ _i18n('prefs.llm_providers') }}</label>
              <LlmProviderSelector
                :providers="providers"
                :selected_provider="selectedProvider"
                :loading="loadingProviders"
                :disabled="generating"
                @select="(p) => selectedProvider = p"
              />
            </div>
            <div class="d-flex flex-column">
              <label class="ap-field-label">&nbsp;</label>
              <button class="btn btn-sm btn-primary" @click="generatePolicy"
                :disabled="generating || !nlInput.trim() || !selectedProvider">
                <span v-if="generating" class="spinner-border spinner-border-sm me-1"></span>
                <i v-else class="fas fa-magic me-1"></i>
                {{ generating ? 'Generating...' : 'Generate' }}
              </button>
            </div>
          </div>
          <div v-if="generationError" class="ap-error-banner mt-3">
            <i class="fas fa-exclamation-circle me-1"></i>{{ generationError }}
          </div>
        </div>

        <!-- Step 2: review result -->
        <div v-if="creatorStep === 'result' && proposedPolicy">
          <div class="d-flex align-items-center gap-2 mb-3">
            <div class="ap-confirm-icon"><i class="fas fa-check"></i></div>
            <div>
              <div class="fw-semibold">{{ _i18n('llm.policy_generated') }}</div>
              <div class="text-muted small mb-0">{{ _i18n('llm.review_query') }}.</div>
            </div>
          </div>

          <div class="row g-3">
            <div class="col-md-8">
              <label class="ap-field-label">{{ _i18n('llm.policy_name') }}</label>
              <input type="text" class="form-control form-control-sm" v-model="proposedPolicy.ai_policy_name" maxlength="60" />
            </div>
            <div class="col-md-4">
              <label class="ap-field-label">{{ _i18n('llm.policy_frequency') }}</label>
              <SelectSearch :options="periodicityOptions" :selected_option="selectedPeriodicity"
                theme="bootstrap-5" @select_option="onPeriodicitySelect" />
            </div>
            <div class="col-12">
              <label class="ap-field-label">{{ _i18n('description') }}</label>
              <input type="text" class="form-control form-control-sm" v-model="proposedPolicy.policy_description" />
            </div>
            <div class="col-12">
              <label class="ap-field-label">{{ _i18n('llm.alert_message') }}</label>
              <input type="text" class="form-control form-control-sm" v-model="proposedPolicy.alert_description"
                placeholder="Shown in the alert table when a violation fires" maxlength="120" />
            </div>
            <div class="col-12">
              <label class="ap-field-label d-flex align-items-center gap-2">
                {{ _i18n('llm.sql_query') }}
                <span class="ap-badge ap-badge-info">{{ _i18n('llm.result_explanation') }}</span>
                <span v-if="proposedPolicy.criticality" :class="criticalityBadgeClass(proposedPolicy.criticality)">
                  {{ proposedPolicy.criticality }}
                </span>
              </label>
              <textarea class="form-control form-control-sm font-monospace"
                style="font-size:0.76rem" v-model="proposedPolicy.sql_query" rows="6"></textarea>
            </div>
            <div class="col-12">
              <label class="ap-field-label">{{ _i18n('llm.explanation') }}</label>
              <div class="ap-explanation-box">{{ proposedPolicy.explanation || '—' }}</div>
            </div>
            <div class="col-12 d-flex align-items-center gap-2 flex-wrap">
              <button class="btn btn-sm btn-primary" @click="savePolicy" :disabled="saving || saveSuccess">
                <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
                <i v-else-if="saveSuccess" class="fas fa-check me-1"></i>
                <i v-else class="fas fa-save me-1"></i>
                {{ saving ? 'Saving...' : saveSuccess ? 'Saved' : 'Save Policy' }}
              </button>
              <div v-if="saveError" class="ap-error-banner">
                <i class="fas fa-exclamation-circle me-1"></i>{{ saveError }}
              </div>
              <div v-if="saveSuccess" class="ap-success-banner">
                <i class="fas fa-check-circle me-1"></i>{{ _i18n('llm.policy_saved') }}
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- Policies table -->
    <TableWithConfig
      ref="table_policies"
      table_config_id="ai_policies_list"
      :csrf="props.context?.csrf"
      :f_map_columns="map_table_columns"
      :get_extra_params_obj="get_extra_params_obj"
      @custom_event="on_table_event"
    >
      <template v-slot:custom_header>
        <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array" :key="item.id">
          <span class="no-wrap d-flex align-items-center filters-label"><b>{{ item.basic_label }}</b></span>
          <SelectSearch
            v-model:selected_option="item.current_option"
            theme="bootstrap-5"
            dropdown_size="small"
            :options="item.options"
            @select_option="add_table_filter(item, $event)"
          />
        </div>
        <div class="d-flex flex-column me-3">
          <span class="filters-label">&nbsp;</span>
          <button class="btn btn-sm btn-primary" @click="reset_filters">{{ _i18n('reset') }}</button>
        </div>
      </template>
    </TableWithConfig>

  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as SelectSearch }        from "./select-search.vue";
import { default as TableWithConfig }     from "./table-with-config.vue";
import { default as ModalDeleteAiPolicy } from "./modal-delete-ai-policy.vue";
import { default as ModalEditAiPolicy }   from "./modal-edit-ai-policy.vue";
import { default as LlmProviderSelector } from "./llm-provider-selector.vue";

const props = defineProps({ context: Object });
const _i18n = (t) => i18n(t);

const loadingProviders = ref(true);
const generating       = ref(false);
const saving           = ref(false);

const providers        = ref([]);
const selectedProvider = ref(null);

const creatorStep      = ref("input");   // "input" | "result"
const nlInput          = ref("");
const proposedPolicy   = ref(null);
const generationError  = ref("");
const saveError        = ref("");
const saveSuccess      = ref(false);

const periodicityOptions = [
  { label: "Every minute",   value: "min"    },
  { label: "Every 5 minutes", value: "5min"  },
  { label: "Hourly",         value: "hourly" },
  { label: "Daily",          value: "daily"  },
];
const selectedPeriodicity = ref(periodicityOptions[2]);

const settingsUrl = `${http_prefix}/lua/admin/prefs.lua?tab=ai`;

const examples = [
  "No SSH traffic for host 192.168.2.38 between 1am and 9am",
  "Alert when any host downloads more than 5 GB",
  "More than 100 unique destination ports contacted from a single internal host in 1 hour (port scan)",
];

const table_policies  = ref(null);
const modal_delete    = ref(null);
const modal_edit      = ref(null);
const policy_to_act   = ref(null);

const PERIODICITY_FILTER_OPTIONS = [
  { label: "All frequencies", value: ""       },
  { label: "Every minute",    value: "min"    },
  { label: "Every 5 min",     value: "5min"   },
  { label: "Hourly",          value: "hourly" },
  { label: "Daily",           value: "daily"  },
];

const filter_table_array = ref([
  {
    id:             "periodicity",
    basic_label:    "Frequency",
    current_option: PERIODICITY_FILTER_OPTIONS[0],
    options:        PERIODICITY_FILTER_OPTIONS,
  },
]);

function get_extra_params_obj() {
  const params = { ifid: props.context?.ifid };
  const pf = filter_table_array.value.find(f => f.id === "periodicity");
  if (pf?.current_option?.value) {
    params.periodicity = pf.current_option.value;
  }
  return params;
}

function add_table_filter(item, opt) {
  item.current_option = opt;
  table_policies.value?.refresh_table();
}

function reset_filters() {
  filter_table_array.value.forEach(f => { f.current_option = f.options[0]; });
  table_policies.value?.refresh_table();
}

function on_table_event(event) {
  if (event.event_id === "click_button_delete_policy") {
    policy_to_act.value = event.row;
    modal_delete.value.show(event.row);

  } else if (event.event_id === "click_button_edit_policy") {
    policy_to_act.value = event.row;
    modal_edit.value.show_edit(event.row);
  }
}

const PERIODICITY_LABELS = { min: "1 min", "5min": "5 min", hourly: "Hourly", daily: "Daily" };
const PERIODICITY_COLORS = { min: "info",  "5min": "primary", hourly: "warning", daily: "secondary" };

function map_table_columns(columns) {
  const renders = {
    periodicity: (v) => {
      const label = PERIODICITY_LABELS[v] || v || "—";
      const color = PERIODICITY_COLORS[v] || "secondary";
      return `<span class="badge bg-${color} text-dark">${label}</span>`;
    },
    is_active: (v) => v
      ? `<span class="badge bg-success">Active</span>`
      : `<span class="badge bg-secondary">Inactive</span>`,
    created_at: (v) => v ? new Date(v * 1000).toLocaleString() : "—",
  };
  columns.forEach(c => {
    if (renders[c.data_field]) {
      c.render_func = (value) => renders[c.data_field](value);
    }
  });
  return columns;
}

async function confirm_delete_policy() {
  const row = policy_to_act.value;
  if (!row) return;
  try {
    const body = JSON.stringify({ policy_id: row.id, csrf: props.context?.csrf });
    await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/delete/ai_policy/delete.lua`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body },
      true, false, true
    );
    table_policies.value?.refresh_table();
  } catch (e) {
    console.error("delete policy failed", e);
  } finally {
    policy_to_act.value = null;
  }
}

async function on_edit_policy(data) {
  try {
    const body = JSON.stringify({
      policy_id:          data.id,
      ai_policy_name:     data.name,
      policy_description: data.description,
      alert_description:  data.alert_description_gui || "",
      sql_query:          data.sql_query,
      periodicity:        data.periodicity,
      explanation:        data.explanation || "",
      csrf:               props.context?.csrf,
    });

    await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/post/ai_policy/update.lua`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body },
      true, false, true
    );
    
    table_policies.value?.refresh_table();
  } catch (e) {
    console.error("update policy failed", e);
  } finally {
    policy_to_act.value = null;
  }
}

function reset() {
  creatorStep.value     = "input";
  proposedPolicy.value  = null;
  generationError.value = "";
  saveError.value       = "";
  saveSuccess.value     = false;
}

function onPeriodicitySelect(opt) {
  selectedPeriodicity.value = opt;
}

function criticalityBadgeClass(level) {
  return {
    low:    "ap-badge ap-badge-crit-low",
    medium: "ap-badge ap-badge-crit-medium",
    high:   "ap-badge ap-badge-crit-high",
  }[level] ?? "ap-badge ap-badge-crit-medium";
}

async function loadProviders() {
  loadingProviders.value = true;
  try {
    const url  = `${http_prefix}/lua/pro/rest/v2/get/llm/providers.lua`;
    const list = await ntopng_utility.http_request(url) ?? [];
    providers.value = Array.isArray(list) ? list : [];
    if (providers.value.length > 0) selectedProvider.value = providers.value[0].provider;

  } catch (e) {
    console.error("providers fetch failed", e);
  } finally {
    loadingProviders.value = false;
  }
}

async function generatePolicy() {
  if (!nlInput.value.trim() || !selectedProvider.value) return;
  generating.value = true;
  generationError.value = "";

  try {
    const body = JSON.stringify({
      provider:           selectedProvider.value,
      policy_description: nlInput.value.trim(),
      csrf:               props.context?.csrf,
    });

    const rsp = await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/post/ai_policy/generate.lua`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body },
      true, false, true
    );

    // there already is a similar policy, skip creation
    if (!rsp?.created) {
      generationError.value = rsp.duplicate_policy
    }
    else if (rsp?.sql_query) {
      proposedPolicy.value = { ...rsp };
      selectedPeriodicity.value = periodicityOptions.find(o => o.value === rsp.periodicity) ?? periodicityOptions[2];
      creatorStep.value    = "result";
    } else if (rsp?.error) {
      generationError.value = rsp.error;
    } else {
      generationError.value = _i18n('llm.unexpected_response');
    }
  } catch (e) {
    generationError.value = "Generation failed: " + (e.message || "unknown error");
  } finally {
    generating.value = false;
  }
}

async function savePolicy() {
  if (!proposedPolicy.value) return;
  saving.value      = true;
  saveError.value   = "";
  saveSuccess.value = false;
  try {
    const pol  = proposedPolicy.value;

    const body = JSON.stringify({
      ai_policy_name:     pol.ai_policy_name,
      policy_description: pol.policy_description,
      alert_description:  pol.alert_description  || "",
      sql_query:          pol.sql_query,
      periodicity:        selectedPeriodicity.value.value, //selectedPeriodicity.value = {label: "Daily", value: "daily"}
      explanation:        pol.explanation || "",
      csrf:               props.context?.csrf,
    });

    const rsp = await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/post/ai_policy/upsert.lua`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body },
      true, false, true
    );
    
    if (rsp?.success) {
      saveSuccess.value = true;
      table_policies.value?.refresh_table();
      reset();
    } else {
      saveError.value = rsp?.error || "Save failed. Please try again.";
    }
  } catch (e) {
    saveError.value = "Save failed: " + (e.message || "unknown error");
  } finally {
    saving.value = false;
  }
}

onMounted(loadProviders);
</script>

<style scoped>
.ap-orange { color: var(--ntop-orange, #FF8F00); }

.ap-warning-banner {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: rgba(255, 193, 7, 0.10);
  border: 1px solid rgba(255, 193, 7, 0.30);
  border-radius: 8px;
  padding: 0.6rem 0.9rem;
  font-size: 0.83rem;
}
.ap-warning-link {
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--ntop-orange, #FF8F00);
  text-decoration: none;
  white-space: nowrap;
}
.ap-warning-link:hover { text-decoration: underline; }

.ap-field-label {
  display: block;
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ntop-muted-text-color, #6c757d);
  margin-bottom: 4px;
}
.ap-field-hint {
  font-size: 0.78rem;
  color: var(--ntop-muted-text-color, #6c757d);
  margin-bottom: 0.5rem;
  line-height: 1.5;
}

.ap-confirm-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: rgba(25, 135, 84, 0.10);
  border: 1px solid rgba(25, 135, 84, 0.25);
  color: #198754;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.88rem;
  flex-shrink: 0;
}

.ap-explanation-box {
  background: var(--bs-tertiary-bg, #f8f9fa);
  border: 1px solid var(--bs-border-color, #dee2e6);
  border-radius: 6px;
  padding: 0.55rem 0.7rem;
  font-size: 0.82rem;
  color: var(--ntop-muted-text-color, #6c757d);
  line-height: 1.55;
}

.ap-chips { display: flex; flex-wrap: wrap; gap: 0.3rem; }
.ap-chip {
  display: inline-block;
  padding: 0.2rem 0.55rem;
  font-size: 0.73rem;
  border: 1px solid var(--bs-border-color, #dee2e6);
  border-radius: 6px;
  color: var(--ntop-muted-text-color, #6c757d);
  cursor: pointer;
  user-select: none;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
  line-height: 1.4;
}
.ap-chip:hover {
  background: rgba(255, 143, 0, 0.08);
  border-color: var(--ntop-orange, #FF8F00);
  color: var(--ntop-orange, #FF8F00);
}

.ap-badge {
  font-size: 0.65rem;
  font-weight: 600;
  padding: 0.2rem 0.5rem;
  border-radius: 5px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}
.ap-badge-info { background: rgba(13,110,253,.10); color: #0d6efd; border: 1px solid rgba(13,110,253,.20); }
.ap-badge-crit-low    { background: rgba(25,135,84,.12);  color: #198754; border: 1px solid rgba(25,135,84,.28);  font-weight:500; text-transform:none; letter-spacing:0; }
.ap-badge-crit-medium { background: rgba(255,193,7,.15);  color: #856404; border: 1px solid rgba(255,193,7,.35);  font-weight:500; text-transform:none; letter-spacing:0; }
.ap-badge-crit-high   { background: rgba(220,53,69,.12);  color: #dc3545; border: 1px solid rgba(220,53,69,.28);  font-weight:500; text-transform:none; letter-spacing:0; }

.ap-success-banner {
  display: flex; align-items: center; gap: 0.4rem;
  background: rgba(25,135,84,.08); border: 1px solid rgba(25,135,84,.20);
  border-radius: 8px; padding: 0.5rem 0.75rem; font-size: 0.78rem; color: #198754;
}
.ap-error-banner {
  display: flex; align-items: center; gap: 0.4rem;
  background: rgba(220,53,69,.08); border: 1px solid rgba(220,53,69,.20);
  border-radius: 8px; padding: 0.5rem 0.75rem; font-size: 0.78rem; color: #dc3545;
}

.filters-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ntop-muted-text-color, #6c757d);
  margin-bottom: 3px;
}
</style>
