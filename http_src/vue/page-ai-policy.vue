<!-- (C) 2013-26 - ntop.org -->
<!-- AI Policy Generator — Natural language description -> LLM -> SQL policy JSON -->
<template>
  <div class="ai-policy-page">

    <!-- Header bar -->
    <div class="ap-filter-card mb-3">
      <div class="ap-header-row">
        <div class="d-flex align-items-center gap-2">
          <div class="ap-header-icon">
            <i class="fas fa-shield-alt"></i>
          </div>
          <div>
            <div class="ap-page-title">AI Security Policy Generator</div>
            <div class="ap-page-subtitle">
              Describe a network security policy in plain language and let the AI generate the corresponding SQL query.
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Provider warning -->
    <div v-if="!loadingProviders && providers.length === 0"
         class="ap-warning-banner mb-3">
      <i class="fas fa-exclamation-triangle me-2"></i>
      No LLM provider configured. Natural language policy creation requires an LLM provider.
      <a :href="settingsUrl" class="ap-warning-link ms-auto">Configure LLM <i class="fas fa-arrow-right ms-1"></i></a>
    </div>

    <!-- Generator card -->
    <div class="ap-creator-card">
      <div class="ap-creator-header">
        <i class="fas fa-magic me-2 ap-orange"></i>
        <span class="fw-semibold">Generate Policy from Natural Language</span>
        <button v-if="creatorStep === 'result'" class="ap-secondary-btn btn-sm ms-auto" @click="reset">
          <i class="fas fa-arrow-left me-1"></i> New
        </button>
      </div>
      <div class="ap-creator-body">

        <!-- Step 1: describe policy in natural language -->
        <div v-if="creatorStep === 'input'">
          <label class="ap-field-label">Describe your policy</label>
          <p class="ap-field-hint">
            Tell the AI what traffic to monitor and what constitutes a violation.
            Be specific about hosts, ports, protocols, time windows, or traffic volumes.
          </p>

          <!-- Preset policy examples -->
          <div class="ap-chips mb-3">
            <span class="ap-chip"
                  v-for="ex in examples" :key="ex" @click="nlInput = ex">
              {{ ex }}
            </span>
          </div>

          <textarea v-model="nlInput" class="ap-textarea"
            rows="4" :disabled="generating"
            placeholder="e.g. Alert if any traffic other than SSH (port 22) or PostgreSQL (port 5432) reaches our database server at 10.0.0.5…">
          </textarea>

          <!-- Provider selector -->
          <div class="mt-3 d-flex align-items-end gap-3 flex-wrap">
            <div>
              <label class="ap-field-label">LLM Provider</label>
              <select class="ap-select" v-model="selectedProvider" :disabled="generating">
                <option v-for="p in providers" :key="p.provider" :value="p.provider">
                  {{ p.provider }} — {{ p.model }}
                </option>
              </select>
            </div>
            <button class="ap-primary-btn" @click="generatePolicy"
              :disabled="generating || !nlInput.trim() || !selectedProvider">
              <span v-if="generating" class="spinner-border spinner-border-sm me-1"></span>
              <i v-else class="fas fa-magic me-1"></i>
              {{ generating ? 'Generating…' : 'Generate' }}
            </button>
          </div>
          <div v-if="generationError" class="ap-error-banner mt-3">
            <i class="fas fa-exclamation-circle me-1"></i>{{ generationError }}
          </div>
        </div>

        <!-- Step 2: show generated policy -->
        <div v-if="creatorStep === 'result' && proposedPolicy">
          <div class="ap-confirm-header mb-3">
            <div class="ap-confirm-icon">
              <i class="fas fa-check"></i>
            </div>
            <div>
              <div class="fw-semibold">Policy generated</div>
              <div class="ap-field-hint mb-0">Review the generated SQL query and fields below.</div>
            </div>
          </div>

          <div class="row g-3">
            <div class="col-md-8">
              <label class="ap-field-label">Policy Name</label>
              <input type="text" class="ap-input" v-model="proposedPolicy.ai_policy_name" maxlength="60" />
            </div>
            <div class="col-md-4">
              <label class="ap-field-label">Run Every</label>
              <SelectSearch
                :options="periodicityOptions"
                :selected_option="selectedPeriodicity"
                theme="bootstrap-5"
                @select_option="onPeriodicitySelect"
              />
            </div>
            <div class="col-12">
              <label class="ap-field-label">Description</label>
              <input type="text" class="ap-input" v-model="proposedPolicy.policy_description" />
            </div>
            <div class="col-12">
              <label class="ap-field-label d-flex align-items-center gap-2">
                SQL Query
                <span class="ap-badge ap-badge-info">Non-empty result = violation</span>
              </label>
              <textarea class="ap-textarea ap-textarea-mono"
                v-model="proposedPolicy.sql_query" rows="6"></textarea>
            </div>
            <div class="col-12">
              <label class="ap-field-label">Explanation</label>
              <div class="ap-explanation-box">{{ proposedPolicy.explanation || '—' }}</div>
            </div>
            <div class="col-12 d-flex align-items-center gap-2 flex-wrap">
              <button class="ap-primary-btn" @click="savePolicy" :disabled="saving || saveSuccess">
                <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
                <i v-else-if="saveSuccess" class="fas fa-check me-1"></i>
                <i v-else class="fas fa-save me-1"></i>
                {{ saving ? 'Saving…' : saveSuccess ? 'Saved' : 'Save Policy' }}
              </button>
              <div v-if="saveError" class="ap-error-banner">
                <i class="fas fa-exclamation-circle me-1"></i>{{ saveError }}
              </div>
              <div v-if="saveSuccess" class="ap-success-banner">
                <i class="fas fa-check-circle me-1"></i>Policy saved successfully.
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as SelectSearch } from "./select-search.vue";

const props = defineProps({ context: Object });

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

// Sample policy preset examples
const examples = [
  "No SSH traffic for host 192.168.2.38 between 1am and 9am",
  "Alert when any host downloads more than 5 GB",
  "Detect any connection to VPN gateway 192.168.2.153 on ports other than 51820 (WireGuard) and 22 (SSH)",
  "Alert on more than 100 unique destination ports contacted from a single internal host in 1 hour (port scan)",
];

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

// LLM policy generation
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

    if (rsp?.sql_query) {
      proposedPolicy.value  = { ...rsp };
      selectedPeriodicity.value = periodicityOptions.find(o => o.value === rsp.periodicity) ?? periodicityOptions[2];
      creatorStep.value    = "result";

    } else if (rsp?.error) {
      generationError.value = rsp.error;

    } else {
      generationError.value = "Unexpected response from LLM. Please try again.";
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
      sql_query:          pol.sql_query,
      periodicity:        selectedPeriodicity.value.value,
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
.ai-policy-page {
  --ap-orange:        var(--ntop-orange, #FF8F00);
  --ap-orange-subtle: rgba(255, 143, 0, 0.10);
  --ap-orange-border: rgba(255, 143, 0, 0.30);
  --ap-border:        var(--chat-border, rgba(0, 0, 0, 0.10));
  --ap-card-bg:       var(--bs-body-bg, #ffffff);
  --ap-header-bg:     var(--navbar-tab-container-bg, #f1f3f5);
  --ap-muted:         var(--ntop-muted-text-color, #37474F);
  --ap-text:          var(--ntop-text-color, #111111);
  --ap-input-bg:      #ffffff;
  --ap-input-border:  rgba(0, 0, 0, 0.15);
  --ap-danger:        #dc3545;
  --ap-danger-subtle: rgba(220, 53, 69, 0.08);

  max-width: 1200px;
  margin: 0 auto;
  padding: 1.25rem 1rem;
}

:root[data-theme='dark'] .ai-policy-page {
  --ap-border:       rgba(255, 255, 255, 0.08);
  --ap-card-bg:      #1a2736;
  --ap-header-bg:    #111c24;
  --ap-muted:        #A7A6A6;
  --ap-text:         #E2E2E2;
  --ap-input-bg:     #162028;
  --ap-input-border: rgba(255, 255, 255, 0.10);
}

.ap-filter-card {
  background: var(--ap-card-bg);
  border: 1px solid var(--ap-border);
  border-radius: 12px;
  padding: 0.9rem 1.1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, .05);
}

.ap-header-row {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
}

.ap-header-icon {
  width: 36px;
  height: 36px;
  border-radius: 9px;
  background: var(--ap-orange-subtle);
  border: 1px solid var(--ap-orange-border);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--ap-orange);
  font-size: 0.95rem;
  flex-shrink: 0;
}

.ap-page-title {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--ap-text);
  line-height: 1.2;
}

.ap-page-subtitle {
  font-size: 0.72rem;
  color: var(--ap-muted);
  margin-top: 1px;
  max-width: 540px;
}

.ap-warning-banner {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: rgba(255, 193, 7, 0.10);
  border: 1px solid rgba(255, 193, 7, 0.30);
  border-radius: 9px;
  padding: 0.6rem 0.9rem;
  font-size: 0.83rem;
  color: var(--ap-text);
}

.ap-warning-link {
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--ap-orange);
  text-decoration: none;
  white-space: nowrap;
}
.ap-warning-link:hover { text-decoration: underline; }

.ap-creator-card {
  background: var(--ap-card-bg);
  border: 1px solid var(--ap-orange-border);
  border-radius: 12px;
  box-shadow: 0 0 0 3px var(--ap-orange-subtle), 0 2px 8px rgba(0,0,0,.06);
  overflow: hidden;
}

.ap-creator-header {
  display: flex;
  align-items: center;
  padding: 0.65rem 1rem;
  background: var(--ap-header-bg);
  border-bottom: 1px solid var(--ap-border);
  font-size: 0.85rem;
}

.ap-creator-body {
  padding: 1rem 1.1rem;
}

.ap-orange { color: var(--ap-orange); }

.ap-field-label {
  display: block;
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ap-muted);
  margin-bottom: 4px;
}

.ap-field-hint {
  font-size: 0.78rem;
  color: var(--ap-muted);
  margin-bottom: 0.5rem;
  line-height: 1.5;
}

.ap-textarea,
.ap-input,
.ap-select {
  width: 100%;
  background: var(--ap-input-bg);
  border: 1px solid var(--ap-input-border);
  border-radius: 8px;
  padding: 0.4rem 0.65rem;
  font-size: 0.82rem;
  color: var(--ap-text);
  transition: border-color 0.12s, box-shadow 0.12s;
  appearance: auto;
}

.ap-textarea { resize: vertical; }

.ap-textarea-mono {
  font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
  font-size: 0.76rem;
}

.ap-textarea:focus,
.ap-input:focus,
.ap-select:focus {
  outline: none;
  border-color: var(--ap-orange);
  box-shadow: 0 0 0 3px var(--ap-orange-subtle);
}

.ap-textarea:disabled,
.ap-input:disabled,
.ap-select:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.ap-explanation-box {
  background: var(--ap-header-bg);
  border: 1px solid var(--ap-border);
  border-radius: 8px;
  padding: 0.55rem 0.7rem;
  font-size: 0.82rem;
  color: var(--ap-muted);
  line-height: 1.55;
}

.ap-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.3rem;
}

.ap-chip {
  display: inline-block;
  padding: 0.2rem 0.55rem;
  font-size: 0.73rem;
  border: 1px solid var(--ap-border);
  border-radius: 6px;
  color: var(--ap-muted);
  cursor: pointer;
  user-select: none;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
  line-height: 1.4;
}
.ap-chip:hover {
  background: var(--ap-orange-subtle);
  border-color: var(--ap-orange);
  color: var(--ap-orange);
}

.ap-badge {
  font-size: 0.65rem;
  font-weight: 600;
  padding: 0.2rem 0.5rem;
  border-radius: 5px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.ap-badge-info {
  background: rgba(13, 110, 253, 0.10);
  color: #0d6efd;
  border: 1px solid rgba(13, 110, 253, 0.20);
}

.ap-primary-btn {
  display: inline-flex;
  align-items: center;
  font-size: 0.8rem;
  font-weight: 600;
  padding: 0.35rem 0.85rem;
  border-radius: 7px;
  border: none;
  background: var(--ap-orange);
  color: #fff;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.12s, box-shadow 0.12s;
}
.ap-primary-btn:hover:not(:disabled) {
  background: var(--ntop-orange-dark, #C56000);
  box-shadow: 0 2px 8px rgba(255,143,0,.35);
}
.ap-primary-btn:disabled { opacity: 0.55; cursor: not-allowed; }

.ap-secondary-btn {
  display: inline-flex;
  align-items: center;
  font-size: 0.8rem;
  font-weight: 500;
  padding: 0.35rem 0.85rem;
  border-radius: 7px;
  border: 1px solid var(--ap-border);
  background: transparent;
  color: var(--ap-muted);
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
}
.ap-secondary-btn:hover:not(:disabled) {
  background: var(--ap-header-bg);
  border-color: var(--ap-muted);
  color: var(--ap-text);
}
.ap-secondary-btn:disabled { opacity: 0.55; cursor: not-allowed; }

.ap-confirm-header {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
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
  margin-top: 2px;
}

.ap-success-banner {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: rgba(25, 135, 84, 0.08);
  border: 1px solid rgba(25, 135, 84, 0.20);
  border-radius: 8px;
  padding: 0.5rem 0.75rem;
  font-size: 0.78rem;
  color: #198754;
}

.ap-error-banner {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  background: rgba(220, 53, 69, 0.08);
  border: 1px solid rgba(220, 53, 69, 0.20);
  border-radius: 8px;
  padding: 0.5rem 0.75rem;
  font-size: 0.78rem;
  color: var(--ap-danger);
}
</style>
