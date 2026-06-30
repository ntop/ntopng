<!-- (C) 2013-26 - ntop.org -->
<template>
  <div class="m-2 mb-3">

    <!-- Generation card -->
    <div v-show="activeTab === 'playbooks'" class="ap-gen-card mb-3">
      <div class="ap-gen-header">
        <div class="d-flex align-items-center gap-2">
          <i class="fas fa-magic ap-accent-icon"></i>
          <span class="fw-semibold">{{ _i18n('llm.analyst_pipeline.generate_playbook') }}</span>
        </div>
        <button v-if="generatedPipeline" class="btn btn-sm btn-outline-secondary" @click="resetGenerate">
          <i class="fas fa-arrow-left me-1"></i>{{ _i18n('new') }}
        </button>
      </div>
      <div class="ap-gen-body">

        <!-- Step 1: pipeline input -->
        <div v-if="!generatedPipeline">
          <label class="ap-label">{{ _i18n('llm.analyst_pipeline.describe_investigation') }}</label>
          <div class="ap-chips mb-2">
            <span class="ap-chip" v-for="ex in exampleInvestigations" :key="ex" @click="nlInput = ex">{{ ex }}</span>
          </div>
          <div class="ap-textarea-wrap mb-3">
            <textarea v-model="nlInput" class="form-control form-control-sm ap-textarea" rows="3"
              :disabled="generating"
              @keydown.enter.exact.prevent="!generating && nlInput.trim() && selectedProvider && generatePipeline()"
              placeholder="e.g. Investigate lateral movement: which internal hosts contacted unusual ports or many destinations in the last 24 hours?">
            </textarea>
            <span class="ap-enter-hint"><kbd class="ap-kbd">↵</kbd> to generate</span>
          </div>
          <div class="d-flex align-items-end gap-3 flex-wrap">
            <div>
              <label class="ap-label">{{ _i18n('prefs.llm_providers') }}</label>
              <LlmProviderSelector
                :providers="providers"
                :selected_provider="selectedProvider"
                :loading="loadingProviders"
                :disabled="generating"
                @select="(p) => selectedProvider = p"
              />
            </div>
            <button class="btn btn-sm btn-primary" @click="generatePipeline"
              :disabled="generating || !nlInput.trim() || !selectedProvider">
              <span v-if="generating" class="spinner-border spinner-border-sm me-1"></span>
              <i v-else class="fas fa-bolt me-1"></i>
              {{ generating ? _i18n('llm.analyst_pipeline.generating') : _i18n('llm.analyst_pipeline.generate') }}
            </button>
          </div>
          <!-- Generation progress -->
          <div v-if="generationProgress.length && (generating || generationProgress.some(e => e.status === 'stage_warning' || e.status === 'error'))"
            class="ap-gen-progress mt-3">
            <div v-for="(ev, idx) in generationProgress" :key="idx"
              :class="['ap-gp-row', 'ap-gp-' + ev.status]">
              <span class="ap-gp-icon">
                <i v-if="ev.status === 'generating'"   class="fas fa-circle-notch fa-spin"></i>
                <i v-else-if="ev.status === 'validating'"  class="fas fa-check-circle"></i>
                <i v-else-if="ev.status === 'fixing'"       class="fas fa-wrench fa-spin"></i>
                <i v-else-if="ev.status === 'stage_warning'" class="fas fa-exclamation-triangle"></i>
                <i v-else-if="ev.status === 'done'"         class="fas fa-check-double"></i>
                <i v-else-if="ev.status === 'error'"        class="fas fa-times-circle"></i>
                <i v-else class="fas fa-circle"></i>
              </span>
              <span class="ap-gp-msg">{{ ev.message }}</span>
              <span v-if="ev.stage && ev.total_stages" class="ap-gp-stage-badge">
                {{ ev.stage_index }}/{{ ev.total_stages }}
              </span>
            </div>
          </div>

          <div v-if="generationError" class="ap-error mt-2">
            <i class="fas fa-exclamation-circle me-1"></i>{{ generationError }}
          </div>
        </div>

        <!-- Step 2: Review generated pipeline -->
        <div v-if="generatedPipeline">
          <div class="d-flex align-items-center gap-2 mb-3">
            <div class="ap-ok-icon"><i class="fas fa-check"></i></div>
            <div>
              <div class="fw-semibold">
                {{ _i18n('llm.analyst_pipeline.pipeline_generated') }}
                <span v-if="generationTime" class="text-muted fw-normal small ms-2">{{ generationTime }}s</span>
              </div>
              <div class="text-muted small">{{ _i18n('llm.analyst_pipeline.review_before_save') }}</div>
            </div>
          </div>
          <div class="row g-2 mb-3">
            <div class="col-12 col-md-6">
              <label class="ap-label">{{ _i18n('name') }}</label>
              <input v-model="generatedPipeline.name" class="form-control form-control-sm" />
            </div>
            <div class="col-12 col-md-6">
              <label class="ap-label">{{ _i18n('description') }}</label>
              <input v-model="generatedPipeline.description" class="form-control form-control-sm" />
            </div>
          </div>
          <div class="ap-info-box mb-3" v-if="generatedPipeline.explanation">
            <i class="fas fa-info-circle me-2 ap-accent-icon"></i>{{ generatedPipeline.explanation }}
          </div>

          <!-- Stages section -->
          <div class="ap-section-header mb-2">
            <span class="ap-section-title">{{ _i18n('llm.analyst_pipeline.stages') }}</span>
            <span class="ap-count-badge">{{ (generatedPipeline.stages || []).length }}</span>
          </div>

          <!-- Stage preview card -->
          <div v-for="(s, idx) in (generatedPipeline.stages || [])" :key="s.id" class="ap-stage-card mb-2">
            <div class="ap-stage-card-head">
              <div class="ap-stage-index">{{ idx + 1 }}</div>
              <div class="ap-stage-card-meta">
                <span class="ap-stage-card-id">{{ s.id }}</span>
                <span class="ap-stage-card-title">{{ s.title }}</span>
              </div>
              <span class="ap-stage-card-pos">{{ idx + 1 }}/{{ generatedPipeline.stages.length }}</span>
            </div>
            <div v-if="s.description" class="ap-stage-card-desc">{{ s.description }}</div>
            <pre class="ap-sql-preview">{{ s.sql_template }}</pre>
            <!-- Column schema -->
            <div v-if="s.columns && s.columns.length" class="ap-col-schema">
              <span class="ap-col-schema-label">Output columns:</span>
              <span v-for="col in s.columns" :key="col.name" class="ap-col-tag">
                {{ col.name }} <em class="ap-col-type">{{ col.type }}</em>
              </span>
            </div>
          </div>

          <div class="mt-3 d-flex gap-2">
            <button class="btn btn-sm btn-success" @click="savePipeline" :disabled="saving">
              <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
              <i v-else class="fas fa-save me-1"></i>{{ _i18n('save') }}
            </button>
            <button class="btn btn-sm btn-outline-secondary" @click="resetGenerate">{{ _i18n('cancel') }}</button>
          </div>
          <div v-if="saveError" class="ap-error mt-2">
            <i class="fas fa-exclamation-circle me-1"></i>{{ saveError }}
          </div>
        </div>

      </div>
    </div>

    <!-- Tab: Playbooks list -->
    <div v-show="activeTab === 'playbooks'">
      <TableWithConfig
        ref="table_pipelines"
        table_config_id="analyst_pipelines"
        :csrf="props.context?.csrf"
        :get_extra_params_obj="get_extra_params_obj"
        @custom_event="onTableEvent"
      >
        <template v-slot:custom_header>
          <NavbarTabs :tabs="tabs" :active_tab_id="activeTab" @on_click="(t) => activeTab = t.id" />
        </template>
      </TableWithConfig>
    </div>

    <!-- Tab: Pipeline Executor -->
    <div v-show="activeTab === 'executor'">
      <div class="mb-3">
        <NavbarTabs :tabs="tabs" :active_tab_id="activeTab" @on_click="(t) => activeTab = t.id" />
      </div>

      <div>
        <!-- No playbook selected -->
        <div v-if="!activePlaybook" class="text-center text-muted p-5">
          <i class="fas fa-project-diagram fa-3x mb-3 d-block opacity-25"></i>
          <div>{{ _i18n('llm.analyst_pipeline.select_or_create') }}</div>
        </div>

        <!-- Active playbook -->
        <div v-else>

          <!-- Explanation banner -->
          <div v-if="activePlaybook.definition && activePlaybook.definition.explanation"
            class="ap-info-box ap-info-box-warn mb-3">
            <i class="fas fa-lightbulb me-2" style="color: var(--ntop-orange)"></i>
            {{ activePlaybook.definition.explanation }}
          </div>

          <!-- Param filters + run button -->
          <div class="card my-3">
            <div class="card-body py-2">
              <div class="d-flex align-items-end gap-3 flex-wrap">

                <template v-for="pd in (activePlaybook.definition && activePlaybook.definition.params) || []" :key="pd.name">

                  <template v-if="pd.type === 'epoch_start'">
                    <div>
                      <label class="ap-label">{{ _i18n('time_range') }}</label>
                      <DateTimeRangePicker
                        id="ap-datetime-picker"
                        :enable_refresh="false"
                        @epoch_change="onEpochChange"
                      />
                    </div>
                  </template>
                  <template v-else-if="pd.type === 'epoch_end'"></template>

                  <template v-else-if="pd.type === 'role'">
                    <div>
                      <label class="ap-label">{{ pd.label || 'IP Role' }}</label>
                      <select class="form-select form-select-sm" v-model="runParams[pd.name]" style="min-width:90px">
                        <option v-for="opt in (pd.options || ['src','dst'])" :key="opt" :value="opt">{{ opt }}</option>
                      </select>
                    </div>
                  </template>

                  <template v-else-if="pd.type === 'threshold'">
                    <div>
                      <label class="ap-label">{{ pd.label || pd.name }}</label>
                      <input type="number" class="form-control form-control-sm" v-model.number="runParams[pd.name]"
                        style="width:100px" />
                    </div>
                  </template>

                  <template v-else-if="pd.type === 'ip'">
                    <div class="ap-ip-field">
                      <label class="ap-label d-flex align-items-center gap-1">
                        {{ pd.label || pd.name }}
                        <span class="ap-hint" :title="_i18n('llm.analyst_pipeline.multi_ip_hint') || 'Comma or space separated. Multiple IPs are OR-combined.'">
                          <i class="fas fa-info-circle"></i>
                        </span>
                      </label>
                      <input type="text"
                        class="form-control form-control-sm"
                        :class="{ 'is-invalid': !isValidIpInput(runParams[pd.name]) }"
                        v-model="runParams[pd.name]"
                        placeholder="1.2.3.4, 5.6.7.8"
                        style="min-width:220px"
                        @keydown.enter.exact.prevent="!running && runPlaybook()" />
                      <div v-if="ipChipsFor(pd.name).length > 1" class="ap-ip-chips">
                        <span v-for="(ip, i) in ipChipsFor(pd.name)" :key="i" class="ap-ip-chip">{{ ip }}</span>
                        <span class="ap-ip-chips-or">OR-combined</span>
                      </div>
                    </div>
                  </template>

                  <template v-else>
                    <div>
                      <label class="ap-label">{{ pd.label || pd.name }}</label>
                      <input type="text" class="form-control form-control-sm" v-model="runParams[pd.name]"
                        :placeholder="pd.type" style="min-width:140px"
                        @keydown.enter.exact.prevent="!running && runPlaybook()" />
                    </div>
                  </template>

                </template>

                <button class="btn btn-sm btn-primary" @click="runPlaybook" :disabled="running"
                  title="Run playbook (Enter)">
                  <span v-if="running" class="spinner-border spinner-border-sm me-1"></span>
                  <i v-else class="fas fa-play me-1"></i>
                  {{ running ? _i18n('llm.analyst_pipeline.running') : _i18n('llm.analyst_pipeline.run_playbook') }}
                </button>

                <button class="btn btn-sm btn-outline-danger ms-auto" @click="confirmDelete">
                  <i class="fas fa-trash me-1"></i>{{ _i18n('delete') }}
                </button>
              </div>
            </div>
          </div>

          <!-- 2-column viewer: pipeline stages (left) + results (right) -->
          <div class="row g-3">

            <!-- Left: stage pipeline -->
            <div class="col-12 col-md-3">
              <div class="card h-100">
                <div class="card-header fw-semibold small">
                  <i class="fas fa-stream me-1 opacity-50"></i>
                  {{ _i18n('llm.analyst_pipeline.stages') }}
                </div>
                <div class="card-body p-2">
                  <div v-for="(stage, idx) in (activePlaybook.definition && activePlaybook.definition.stages) || []"
                    :key="stage.id" class="ap-node-wrap">
                    <div v-if="idx > 0" class="ap-connector"></div>
                    <!-- Stage row: square indicator + text -->
                    <div class="ap-node"
                      :class="nodeClass(stage.id)"
                      @click="selectedStageId = stage.id"
                      :title="stage.description || stage.title">
                      <!-- Status square -->
                      <div class="ap-sq" :class="sqClass(stage.id)">
                        <span v-if="stageStatus(stage.id) === 'running'" class="spinner-border spinner-border-sm" style="width:10px;height:10px;border-width:1.5px"></span>
                        <i v-else-if="stageStatus(stage.id) === 'done'" class="fas fa-check" style="font-size:9px"></i>
                        <i v-else-if="stageStatus(stage.id) === 'error'" class="fas fa-times" style="font-size:9px"></i>
                        <span v-else class="ap-sq-num">{{ idx + 1 }}</span>
                        <!-- done dot -->
                        <div v-if="stageStatus(stage.id) === 'done'" class="ap-done-dot"></div>
                      </div>
                      <!-- Name (free-form, wraps naturally) -->
                      <div class="ap-node-text">
                        <div class="ap-node-title">{{ stage.title }}</div>
                        <div class="ap-node-id">{{ stage.id }}</div>
                      </div>
                      <!-- Row count badge -->
                      <div v-if="stageResults[stage.id]" class="ap-row-count">
                        {{ stageResults[stage.id].row_count }}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right: results panel -->
            <div class="col-12 col-md-9">
              <div class="card h-100">
                <div class="card-header d-flex align-items-center gap-2">
                  <span class="fw-semibold small">
                    {{ selectedStageResult ? selectedStageResult.title : _i18n('llm.analyst_pipeline.results') }}
                  </span>
                  <span v-if="selectedStageResult" class="badge bg-secondary ms-1">
                    {{ selectedStageResult.row_count }} {{ _i18n('rows') }}
                  </span>
                  <span v-if="selectedStageResult && selectedStageResult.hook_fired"
                    class="badge bg-warning text-dark ms-1">
                    <i class="fas fa-bell me-1"></i>{{ selectedStageResult.hook_message }}
                  </span>
                  <span v-if="runError" class="text-danger small ms-auto">
                    <i class="fas fa-exclamation-triangle me-1"></i>{{ runError }}
                  </span>
                </div>
                <div class="card-body p-0" style="overflow:auto; max-height:500px;">
                  <div v-if="!selectedStageResult && !running" class="p-4 text-center text-muted small">
                    <i class="fas fa-play-circle fa-2x mb-2 d-block opacity-25"></i>
                    {{ _i18n('llm.analyst_pipeline.run_to_see_results') }}
                    <div class="mt-1" style="font-size:0.72rem">Press <kbd class="ap-kbd">↵ Enter</kbd> to execute</div>
                  </div>
                  <div v-if="running && !selectedStageResult" class="p-4 text-center text-muted small">
                    <span class="spinner-border spinner-border-sm me-2"></span>
                    {{ _i18n('llm.analyst_pipeline.running') }}…
                  </div>
                  <table v-if="selectedStageResult && selectedStageResult.rows && selectedStageResult.rows.length > 0"
                    class="table table-sm table-hover mb-0 small ap-result-table">
                    <thead class="table-light">
                      <tr>
                        <th v-for="col in resultColumns" :key="col.name"
                          :class="{ 'text-end': col.type === 'number' || col.type === 'bytes' }">
                          {{ col.label }}
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="(row, ri) in selectedStageResult.rows" :key="ri">
                        <td v-for="col in resultColumns" :key="col.name"
                          :class="{ 'text-end': isNumericCol(col),
                                    'ap-cell-ip': col.type === 'ip',
                                    'ap-cell-ts': col.type === 'timestamp',
                                    'ap-cell-num': isNumericCol(col) }">
                          <code v-if="col.type === 'ip'" class="ap-ip">{{ row[col.name] ?? '' }}</code>
                          <span v-else-if="isNumericCol(col)">{{ formatCell(row, col) }}</span>
                          <span v-else>{{ row[col.name] ?? '' }}</span>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                  <div v-else-if="selectedStageResult && selectedStageResult.row_count === 0"
                    class="p-3 text-center text-muted small">
                    {{ _i18n('no_results') }}
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>

    <!-- Delete confirm modal -->
    <div class="modal fade" id="ap-delete-modal" tabindex="-1">
      <div class="modal-dialog modal-sm">
        <div class="modal-content">
          <div class="modal-header">
            <h6 class="modal-title">{{ _i18n('delete') }}</h6>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body small">
            {{ _i18n('llm.analyst_pipeline.confirm_delete') }} <strong>{{ activePlaybook && activePlaybook.name }}</strong>?
          </div>
          <div class="modal-footer">
            <button class="btn btn-sm btn-secondary" data-bs-dismiss="modal">{{ _i18n('cancel') }}</button>
            <button class="btn btn-sm btn-danger" @click="deletePlaybook" :disabled="deleting">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-1"></span>
              {{ _i18n('delete') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Definition viewer modal -->
    <div class="modal fade" id="ap-definition-modal" tabindex="-1">
      <div class="modal-dialog modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h6 class="modal-title">
              <i class="fas fa-code me-2"></i>{{ _i18n('llm.analyst_pipeline.view_definition') }}
              <span v-if="viewDefinitionPlaybook" class="text-muted fw-normal ms-2 small">{{ viewDefinitionPlaybook.name }}</span>
            </h6>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body p-0" v-if="viewDefinitionPlaybook">
            <div v-for="(stage, idx) in (viewDefinitionPlaybook.definition && viewDefinitionPlaybook.definition.stages) || []"
              :key="stage.id" class="ap-def-stage">
              <!-- Stage header -->
              <div class="ap-def-stage-head">
                <div class="ap-stage-index ap-stage-index-sm">{{ idx + 1 }}</div>
                <div>
                  <div class="d-flex align-items-center gap-2">
                    <span class="fw-semibold small">{{ stage.title }}</span>
                    <span class="ap-id-pill">{{ stage.id }}</span>
                  </div>
                  <div v-if="stage.description" class="text-muted" style="font-size:0.78rem">{{ stage.description }}</div>
                </div>
              </div>
              <!-- SQL -->
              <pre class="ap-sql-block mb-0"><code class="hljs" v-html="highlightSql(stage.sql_template)"></code></pre>
              <!-- Output columns -->
              <div v-if="stage.columns && stage.columns.length" class="ap-col-schema ap-col-schema-modal">
                <span class="ap-col-schema-label">Output columns:</span>
                <span v-for="col in stage.columns" :key="col.name" class="ap-col-tag">
                  {{ col.name }} <em class="ap-col-type">{{ col.type }}</em>
                </span>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-sm btn-secondary" data-bs-dismiss="modal">{{ _i18n('close') }}</button>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as LlmProviderSelector  } from "./llm-provider-selector.vue";
import { default as NavbarTabs           } from "./components/navbar-tabs.vue";
import { default as TableWithConfig      } from "./table-with-config.vue";
import { highlightSql                   } from "./composables/useLlmChat.js";

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

// Tabs
const tabs = [
  { id: "playbooks", label_i18n: "llm.analyst_pipeline.playbooks_tab" },
  { id: "executor",  label_i18n: "llm.analyst_pipeline.executor_tab"  },
];
const activeTab = ref("playbooks");

const table_pipelines = ref(null);

function get_extra_params_obj() {
  return { ifid: props.context?.ifid ?? 0 };
}

// Provider state 
const providers        = ref([]);
const loadingProviders = ref(true);
const selectedProvider = ref("");

// Generation state
const nlInput            = ref("");
const generating         = ref(false);
const generatedPipeline  = ref(null);
const generationError    = ref("");
const generationTime     = ref(null);
const generationProgress = ref([]);   // array of {status, message, stage?, error?}
const saving             = ref(false);
const saveError          = ref("");

// Active playbook executor
const activePlaybook    = ref(null);
const loadingPlaybook   = ref(false);

// Run state
const runParams       = ref({});
const running         = ref(false);
const runError        = ref("");
const stageResults    = ref({});
const stageStatuses   = ref({});
const selectedStageId = ref("");

const deleting               = ref(false);
const viewDefinitionPlaybook = ref(null);

// Epoch from DateTimeRangePicker
const epochStart = ref(Math.floor(Date.now() / 1000) - 86400);
const epochEnd   = ref(Math.floor(Date.now() / 1000));

const exampleInvestigations = [
  "Investigate DNS exfiltration from internal hosts",
  "Track lateral movement: hosts scanning many destinations",
  "VPN user traffic analysis and destinations visited",
  "Identify top bandwidth consumers in the last 24h",
];

const selectedStageResult = computed(() => {
  if (!selectedStageId.value) return null;
  return stageResults.value[selectedStageId.value] || null;
});

const resultColumns = computed(() => {
  const r = selectedStageResult.value;
  if (!r) return [];
  if (r.columns && r.columns.length > 0) return r.columns;
  if (!r.rows || r.rows.length === 0) return [];
  return Object.keys(r.rows[0]).map(k => ({ name: k, label: k, type: "string" }));
});

// Multi-IP input helpers
const IP_SPLIT_RE = /[\s,;]+/;
const IPV4_RE = /^(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)$/;
const IPV6_RE = /^[0-9a-fA-F:]+$/;

function splitIps(raw) {
  if (raw == null) return [];
  if (Array.isArray(raw)) return raw.map(s => String(s).trim()).filter(Boolean);
  return String(raw).split(IP_SPLIT_RE).map(s => s.trim()).filter(Boolean);
}

function ipChipsFor(name) {
  return splitIps(runParams.value[name]);
}

function isValidIpInput(raw) {
  const ips = splitIps(raw);
  if (ips.length === 0) return true;
  return ips.every(ip => IPV4_RE.test(ip) || (IPV6_RE.test(ip) && ip.includes(":")));
}

function formatCell(row, col) {
  const v = row[col.name];
  if (v == null) return "";
  return String(v);
}

function isNumericCol(col) {
  const t = (col?.type || "").toLowerCase();
  return t === "number" || t === "bytes" || t === "packets" || t === "flows" || t === "count"
      || t === "asn" || t === "id" || t === "port" || t === "vlan";
}

// URL persistence
function getUrlParam(name) {
  return new URLSearchParams(window.location.search).get(name);
}

function syncUrl() {
  const params = new URLSearchParams(window.location.search);
  params.set("tab", activeTab.value);
  if (activeTab.value === "executor" && activePlaybook.value?.pipeline_id) {
    params.set("pipeline_id", activePlaybook.value.pipeline_id);
  } else {
    params.delete("pipeline_id");
  }
  const newUrl = `${window.location.pathname}?${params.toString()}`;
  window.history.replaceState(null, "", newUrl);
}

watch(activeTab, syncUrl);
watch(() => activePlaybook.value?.pipeline_id, syncUrl);

onMounted(async () => {
  await loadProviders();
  // Restore tab and playbook from URL
  const tab = getUrlParam("tab");
  if (tab === "executor" || tab === "playbooks") activeTab.value = tab;
  const pid = getUrlParam("pipeline_id");
  if (pid) await loadPlaybook(pid);
});

async function loadProviders() {
  loadingProviders.value = true;

  try {
    const list = await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/get/llm/providers.lua`
    ) ?? [];
    providers.value = Array.isArray(list) ? list : [];
    if (providers.value.length > 0) selectedProvider.value = providers.value[0].provider;
  } catch (e) {
    console.error("providers fetch failed", e);
  } finally {
    loadingProviders.value = false;
  }
}

async function loadPlaybook(pipelineId) {
  if (!pipelineId) { activePlaybook.value = null; return; }
  loadingPlaybook.value = true;
  try {
    const rsp = await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/get/analyst_pipeline/get.lua?pipeline_id=${encodeURIComponent(pipelineId)}`
    );
    if (rsp) {
      activePlaybook.value = rsp;
      runParams.value = {};
      stageResults.value = {};
      stageStatuses.value = {};
      selectedStageId.value = "";
      runError.value = "";
      const paramDefs = rsp.definition?.params || [];
      paramDefs.forEach(pd => {
        if (pd.type === "epoch_start") runParams.value[pd.name] = epochStart.value;
        else if (pd.type === "epoch_end") runParams.value[pd.name] = epochEnd.value;
        else if (pd.default !== undefined) runParams.value[pd.name] = pd.default;
      });
    }
  } finally {
    loadingPlaybook.value = false;
  }
}

function onEpochChange(ev) {
  epochStart.value = ev.epoch_begin ?? ev.epoch_start;
  epochEnd.value   = ev.epoch_end;
  const paramDefs = activePlaybook.value?.definition?.params || [];
  paramDefs.forEach(pd => {
    if (pd.type === "epoch_start") runParams.value[pd.name] = epochStart.value;
    if (pd.type === "epoch_end")   runParams.value[pd.name] = epochEnd.value;
  });
}

// Table event
function onTableEvent(event) {
  const row = event.row;
  if (event.event_id === "open_pipeline") {
    if (row?.pipeline_id) { loadPlaybook(row.pipeline_id); activeTab.value = "executor"; }
  } else if (event.event_id === "view_definition") {
    if (row?.pipeline_id) loadDefinitionModal(row.pipeline_id, row.name);
  } else if (event.event_id === "delete_pipeline") {
    if (row?.pipeline_id) {
      activePlaybook.value = { pipeline_id: row.pipeline_id, name: row.name };
      confirmDelete();
    }
  }
}

function resetGenerate() {
  generatedPipeline.value  = null;
  generationError.value    = "";
  generationTime.value     = null;
  generationProgress.value = [];
  nlInput.value            = "";
  saveError.value          = "";
}

async function generatePipeline() {
  if (!nlInput.value.trim() || !selectedProvider.value) return;
  generating.value         = true;
  generationError.value    = "";
  generatedPipeline.value  = null;
  generationTime.value     = null;
  generationProgress.value = [];
  const t0 = Date.now();
  try {
    const body = JSON.stringify({
      provider:             selectedProvider.value,
      pipeline_description: nlInput.value.trim(),
      ifid:                 props.context?.ifid ?? 0,
      csrf:                 props.context?.csrf,
    });
    const resp = await fetch(
      `${http_prefix}/lua/pro/rest/v2/post/analyst_pipeline/generate.lua`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body }
    );
    if (!resp.ok) {
      generationError.value = "HTTP " + resp.status;
      return;
    }
    const reader  = resp.body.getReader();
    const decoder = new TextDecoder();
    let   buf     = "";
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      const lines = buf.split("\n");
      buf = lines.pop();       // keep incomplete last line
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        let ev;
        try { ev = JSON.parse(trimmed); } catch { continue; }

        if (ev.status === "done") {
          generatedPipeline.value = ev.pipeline;
          generationTime.value    = ((Date.now() - t0) / 1000).toFixed(1);
          generationProgress.value.push({ status: "done", message: "Pipeline ready" });
        } else if (ev.status === "error") {
          generationError.value = ev.message || _i18n("error");
          generationProgress.value.push({ status: "error", message: ev.message });
        } else {
          // generating / validating / fixing / stage_warning
          generationProgress.value.push(ev);
        }
      }
    }
  } catch (e) {
    generationError.value = "Generation failed: " + (e.message || "unknown error");
  } finally {
    generating.value = false;
  }
}

async function savePipeline() {
  if (!generatedPipeline.value) return;
  saving.value    = true;
  saveError.value = "";
  try {
    const selectedProviderObj = providers.value.find(p => p.provider === selectedProvider.value);
    const body = JSON.stringify({
      pipeline_name:        generatedPipeline.value.name,
      pipeline_description: generatedPipeline.value.description,
      definition:           JSON.stringify(generatedPipeline.value),
      provider:             selectedProvider.value,
      model:                selectedProviderObj?.model ?? "",
      ifid:                 props.context?.ifid ?? 0,
      csrf:                 props.context?.csrf,
    });
    const rsp = await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/post/analyst_pipeline/save.lua`,
      { method: "POST", headers: { "Content-Type": "application/json" }, body },
      true, false, true
    );
    if (rsp?.pipeline_id) {
      table_pipelines.value?.refresh_table?.();
      resetGenerate();
      await loadPlaybook(rsp.pipeline_id);
      activeTab.value = "executor";
    } else {
      saveError.value = rsp?.error || _i18n("error");
    }
  } catch (e) {
    saveError.value = e.message;
  } finally {
    saving.value = false;
  }
}

// NDJSON Stream
async function runPlaybook() {
  if (!activePlaybook.value || running.value) return;
  running.value       = true;
  runError.value      = "";
  stageResults.value  = {};
  stageStatuses.value = {};
  selectedStageId.value = "";

  const paramDefs = activePlaybook.value?.definition?.params || [];
  paramDefs.forEach(pd => {
    if (pd.type === "epoch_start") runParams.value[pd.name] = epochStart.value;
    if (pd.type === "epoch_end")   runParams.value[pd.name] = epochEnd.value;
  });

  try {
    const res = await fetch(`${http_prefix}/lua/pro/rest/v2/post/analyst_pipeline/run.lua`, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify({
        pipeline_id: activePlaybook.value.pipeline_id,
        params:      JSON.stringify(runParams.value),
        ifid:        props.context?.ifid ?? 0,
        csrf:        props.context?.csrf,
      }),
    });

    if (!res.ok) { runError.value = `HTTP ${res.status}`; return; }

    const reader  = res.body.getReader();
    const decoder = new TextDecoder();
    let   buffer  = "";

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop();
      for (const line of lines) {
        if (!line.trim()) continue;
        try { handleStreamChunk(JSON.parse(line)); } catch (_) {}
      }
    }
    if (buffer.trim()) {
      try { handleStreamChunk(JSON.parse(buffer)); } catch (_) {}
    }
  } catch (e) {
    runError.value = e.message;
  } finally {
    running.value = false;
  }
}

function handleStreamChunk(chunk) {
  if (chunk.status === "starting") {
    stageStatuses.value[chunk.stage_id] = "running";
    selectedStageId.value = chunk.stage_id;
  } else if (chunk.status === "done") {
    stageStatuses.value[chunk.stage_id] = "done";
    stageResults.value[chunk.stage_id] = {
      title:        chunk.title,
      rows:         chunk.rows        || [],
      row_count:    chunk.row_count   || 0,
      columns:      chunk.columns     || [],
      hook_fired:   chunk.hook_fired  || false,
      hook_message: chunk.hook_message || "",
    };
    selectedStageId.value = chunk.stage_id;
  } else if (chunk.status === "error") {
    stageStatuses.value[chunk.stage_id] = "error";
    runError.value = chunk.message || _i18n("error");
  } else if (chunk.status === "complete") {
    const stages = activePlaybook.value?.definition?.stages || [];
    for (let i = stages.length - 1; i >= 0; i--) {
      if (stageResults.value[stages[i].id]) { selectedStageId.value = stages[i].id; break; }
    }
  }
}

function stageStatus(stageId) {
  return stageStatuses.value[stageId] || "idle";
}

function sqClass(stageId) {
  const s = stageStatus(stageId);
  return {
    "ap-sq-idle":    s === "idle",
    "ap-sq-running": s === "running",
    "ap-sq-done":    s === "done",
    "ap-sq-error":   s === "error",
  };
}

function nodeClass(stageId) {
  return {
    "ap-node-selected": selectedStageId.value === stageId,
  };
}

async function loadDefinitionModal(pipelineId, name) {
  viewDefinitionPlaybook.value = { name, definition: null };
  const modal = new bootstrap.Modal(document.getElementById("ap-definition-modal"));
  modal.show();
  try {
    const rsp = await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/get/analyst_pipeline/get.lua?pipeline_id=${encodeURIComponent(pipelineId)}`
    );
    if (rsp) viewDefinitionPlaybook.value = rsp;
  } catch (e) {
    console.error("load definition failed", e);
  }
}

// Delete
function confirmDelete() {
  new bootstrap.Modal(document.getElementById("ap-delete-modal")).show();
}

async function deletePlaybook() {
  if (!activePlaybook.value?.pipeline_id) return;
  deleting.value = true;
  try {
    await ntopng_utility.http_request(
      `${http_prefix}/lua/pro/rest/v2/delete/analyst_pipeline/delete.lua`,
      {
        method:  "POST",
        headers: { "Content-Type": "application/json" },
        body:    JSON.stringify({ pipeline_id: activePlaybook.value.pipeline_id, csrf: props.context?.csrf }),
      },
      true, false, true
    );
    bootstrap.Modal.getInstance(document.getElementById("ap-delete-modal"))?.hide();
    activePlaybook.value = null;
    table_pipelines.value?.refresh_table?.();
    activeTab.value = "playbooks";
  } finally {
    deleting.value = false;
  }
}
</script>

<style scoped>
@import "highlight.js/styles/github.css";

.ap-accent-icon { color: var(--ntop-orange); }

.ap-gen-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-top: 2px solid var(--ntop-orange);
  border-radius: 10px;
  box-shadow: 0 1px 4px rgba(0,0,0,.05);
}

.ap-gen-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  background: var(--bg-elevated);
  border-bottom: 1px solid var(--border-subtle);
  font-size: 0.85rem;
}

.ap-gen-body {
  padding: 14px 16px;
}

.ap-label {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  display: block;
  margin-bottom: 4px;
  color: var(--ntop-muted-text-color);
}

.ap-textarea-wrap {
  position: relative;
}

.ap-textarea {
  padding-bottom: 24px !important;
  resize: vertical;
}

.ap-enter-hint {
  position: absolute;
  bottom: 6px;
  right: 10px;
  font-size: 0.65rem;
  color: var(--ntop-muted-text-color);
  pointer-events: none;
  user-select: none;
}

.ap-kbd {
  background: var(--bg-elevated);
  border: 1px solid var(--border-color);
  border-radius: 3px;
  padding: 1px 5px;
  font-size: 0.65rem;
  color: var(--ntop-text-color);
  font-family: ui-monospace, monospace;
}

.ap-chips { display: flex; flex-wrap: wrap; gap: 6px; }

.ap-chip {
  font-size: 0.73rem;
  padding: 3px 10px;
  border-radius: 999px;
  background: var(--bg-elevated);
  color: var(--ntop-text-color);
  cursor: pointer;
  border: 1px solid var(--border-color);
  transition: background-color 0.15s, border-color 0.15s, color 0.15s;
  user-select: none;
}

.ap-chip:hover {
  background: var(--ntop-orange);
  border-color: var(--ntop-orange);
  color: #fff;
}

.ap-info-box {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  background: var(--bg-elevated);
  border: 1px solid var(--border-subtle);
  border-left: 3px solid var(--ntop-orange);
  color: var(--ntop-text-color);
  font-size: 0.82rem;
  padding: 9px 12px;
  border-radius: 6px;
  line-height: 1.5;
}

.ap-info-box-warn {
  border-left-color: var(--ntop-orange);
}

.ap-ok-icon {
  width: 30px; height: 30px;
  border-radius: 50%;
  background: linear-gradient(135deg, #28a745, #1e7e34);
  color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.85rem;
  box-shadow: 0 2px 6px rgba(40,167,69,.3);
  flex-shrink: 0;
}

.ap-section-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-bottom: 6px;
  border-bottom: 1px solid var(--border-subtle);
}

.ap-section-title {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ntop-muted-text-color);
}

.ap-count-badge {
  background: var(--ntop-orange);
  color: #fff;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 1px 8px;
  border-radius: 999px;
}

.ap-stage-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 7px;
  overflow: hidden;
  transition: border-color 0.15s;
}

.ap-stage-card:hover { border-color: var(--ntop-orange); }

.ap-stage-card-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 12px;
  background: var(--bg-elevated);
  border-bottom: 1px solid var(--border-subtle);
}

/* Numbered circle index */
.ap-stage-index {
  width: 22px; height: 22px;
  border-radius: 50%;
  background: var(--ntop-orange);
  color: #fff;
  font-size: 0.7rem;
  font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}

.ap-stage-index-sm {
  width: 20px; height: 20px;
  font-size: 0.65rem;
}

.ap-stage-card-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  min-width: 0;
}

.ap-stage-card-id {
  font-family: ui-monospace, monospace;
  font-size: 0.65rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  padding: 1px 6px;
  border-radius: 4px;
  background: var(--bg-sunken);
  border: 1px solid var(--border-subtle);
  color: var(--ntop-muted-text-color);
  white-space: nowrap;
  flex-shrink: 0;
}

.ap-stage-card-title {
  font-weight: 600;
  font-size: 0.84rem;
  color: var(--ntop-text-color);
  flex: 1;
  min-width: 0;
}

.ap-stage-card-pos {
  font-size: 0.68rem;
  color: var(--ntop-muted-text-color);
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  padding: 1px 7px;
  border-radius: 999px;
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}

.ap-stage-card-desc {
  font-size: 0.78rem;
  color: var(--ntop-muted-text-color);
  padding: 6px 12px 0;
  line-height: 1.4;
}

.ap-sql-preview {
  display: block;
  font-size: 0.71rem;
  color: var(--ntop-muted-text-color);
  background: var(--bg-sunken);
  border-top: 1px solid var(--border-subtle);
  padding: 8px 12px;
  white-space: pre-wrap;
  word-break: break-all;
  font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
  margin: 0;
  line-height: 1.45;
}

.ap-col-schema {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 5px;
  padding: 7px 12px;
  border-top: 1px solid var(--border-subtle);
  background: var(--bg-elevated);
}

.ap-col-schema-modal {
  border-top: none;
  margin-top: 8px;
  padding: 0;
  background: transparent;
}

.ap-col-schema-label {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ntop-muted-text-color);
  margin-right: 4px;
  white-space: nowrap;
}

.ap-col-tag {
  font-family: ui-monospace, monospace;
  font-size: 0.7rem;
  padding: 2px 8px;
  border-radius: 4px;
  background: var(--bg-sunken);
  color: var(--ntop-text-color);
  border: 1px solid var(--border-subtle);
}

.ap-col-type {
  font-style: normal;
  color: var(--ntop-muted-text-color);
  margin-left: 4px;
  font-size: 0.65rem;
}

.ap-id-pill {
  font-family: ui-monospace, monospace;
  font-size: 0.65rem;
  font-weight: 600;
  padding: 1px 7px;
  border-radius: 4px;
  background: var(--bg-sunken);
  border: 1px solid var(--border-subtle);
  color: var(--ntop-muted-text-color);
}

.ap-def-stage {
  padding: 14px 16px;
  border-bottom: 1px solid var(--border-subtle);
}
.ap-def-stage:last-child { border-bottom: none; }

.ap-def-stage-head {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-bottom: 10px;
}

.ap-node-wrap {
  display: flex;
  flex-direction: column;
  align-items: stretch;
}

.ap-connector {
  width: 2px;
  height: 14px;
  margin: 0 11px;
  background: var(--border-color);
  border-radius: 1px;
  align-self: flex-start;
}

.ap-node {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 6px 8px;
  border-radius: 7px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: background-color 0.15s, border-color 0.15s;
}

.ap-node:hover {
  background: var(--bg-elevated);
  border-color: var(--border-color);
}

.ap-node-selected {
  background: var(--bg-elevated) !important;
  border-color: var(--ntop-orange) !important;
}

.ap-sq {
  width: 24px; height: 24px;
  border-radius: 6px;
  flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  position: relative;
  border: 1.5px solid transparent;
  transition: all 0.2s;
}

.ap-sq-num {
  font-size: 0.65rem;
  font-weight: 700;
  color: var(--ntop-muted-text-color);
}

.ap-sq-idle {
  background: var(--bg-elevated);
  border-color: var(--border-color);
}

.ap-sq-running {
  background: rgba(255,143,0,.12);
  border-color: var(--ntop-orange);
  color: var(--ntop-orange);
  animation: ap-halo 1.4s ease-in-out infinite;
}

@keyframes ap-halo {
  0%   { box-shadow: 0 0 0 0   rgba(255,143,0,.5); }
  50%  { box-shadow: 0 0 0 5px rgba(255,143,0,.18); }
  100% { box-shadow: 0 0 0 0   rgba(255,143,0,0); }
}

.ap-sq-done {
  background: rgba(40,167,69,.12);
  border-color: #28a745;
  color: #28a745;
}

.ap-done-dot {
  position: absolute;
  top: -3px; left: -3px;
  width: 7px; height: 7px;
  border-radius: 50%;
  background: #28a745;
  border: 1.5px solid var(--bg-surface);
  box-shadow: 0 0 4px rgba(40,167,69,.6);
}

.ap-sq-error {
  background: rgba(220,53,69,.12);
  border-color: #dc3545;
  color: #dc3545;
}

.ap-node-text {
  flex: 1;
  min-width: 0;
}

.ap-node-title {
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--ntop-text-color);
  line-height: 1.25;
  white-space: normal;
  word-break: break-word;
}

.ap-node-id {
  font-family: ui-monospace, monospace;
  font-size: 0.62rem;
  color: var(--ntop-muted-text-color);
  margin-top: 1px;
}

.ap-row-count {
  font-size: 0.68rem;
  font-weight: 700;
  color: var(--ntop-orange);
  background: rgba(255,143,0,.1);
  padding: 1px 6px;
  border-radius: 999px;
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}

:deep(.card) {
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  box-shadow: 0 1px 2px rgba(0,0,0,.04);
}

:deep(.card-header) {
  background: var(--bg-elevated);
  border-bottom: 1px solid var(--border-subtle);
  color: var(--ntop-text-color);
  font-size: 0.85rem;
  padding: 0.6rem 0.9rem;
}

:deep(.bg-light) {
  background: var(--bg-elevated) !important;
  color: var(--ntop-text-color) !important;
}

.ap-result-table {
  color: var(--ntop-text-color);
  margin: 0;
}

.ap-result-table th,
.ap-result-table td {
  white-space: nowrap;
  font-size: 0.78rem;
  border-color: var(--border-subtle) !important;
}

.ap-result-table :deep(thead.table-light) th,
.ap-result-table :deep(thead) th {
  background: var(--bg-elevated) !important;
  color: var(--ntop-text-color) !important;
  border-bottom: 1px solid var(--border-color) !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-transform: uppercase;
  font-size: 0.7rem;
}

.ap-result-table tbody tr:hover {
  background: var(--bg-elevated) !important;
}

code.ap-ip {
  background: var(--bg-sunken);
  border: 1px solid var(--border-subtle);
  color: var(--ntop-text-color);
  padding: 1px 6px;
  border-radius: 4px;
  font-size: 0.74rem;
}

.ap-cell-num {
  font-variant-numeric: tabular-nums;
  font-family: ui-monospace, monospace;
  font-size: 0.76rem;
}

.ap-sql-block {
  font-size: 0.74rem;
  background: var(--bg-sunken);
  border: 1px solid var(--border-subtle);
  border-radius: 6px;
  padding: 10px 12px;
  white-space: pre-wrap;
  word-break: break-all;
  color: var(--ntop-text-color);
  margin: 0;
  font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}

.hljs {
  background: transparent !important;
  color: var(--ntop-text-color) !important;
}

:root[data-theme='dark'] .hljs-keyword,
:root[data-theme='dark'] .hljs-built_in  { color: #ff9d4d !important; }
:root[data-theme='dark'] .hljs-string,
:root[data-theme='dark'] .hljs-number    { color: #9ecbff !important; }
:root[data-theme='dark'] .hljs-comment   { color: #8b949e !important; font-style: italic; }
:root[data-theme='dark'] .hljs-title,
:root[data-theme='dark'] .hljs-name      { color: #d2a8ff !important; }

.ap-gen-progress {
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  padding: 8px 10px;
  background: var(--bg-sunken);
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 0.78rem;
  font-family: var(--bs-font-monospace, monospace);
}
.ap-gp-row {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 3px 0;
  border-radius: 4px;
  color: var(--ntop-muted-text-color);
}
.ap-gp-icon { width: 14px; flex-shrink: 0; text-align: center; }
.ap-gp-msg  { flex: 1; }
.ap-gp-stage-badge {
  font-size: 0.68rem;
  background: var(--bg-elevated);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  padding: 1px 6px;
  white-space: nowrap;
  color: var(--ntop-muted-text-color);
}
.ap-gp-generating .ap-gp-icon { color: var(--ntop-orange); }
.ap-gp-validating  .ap-gp-icon { color: #28a745; }
.ap-gp-fixing      .ap-gp-icon { color: #ffc107; }
.ap-gp-stage_warning .ap-gp-icon { color: #fd7e14; }
.ap-gp-stage_warning { color: #fd7e14; }
.ap-gp-done        .ap-gp-icon { color: #28a745; }
.ap-gp-done        { color: var(--ntop-text-color); font-weight: 500; }
.ap-gp-error       .ap-gp-icon { color: #dc3545; }
.ap-gp-error       { color: #dc3545; }

.ap-error {
  font-size: 0.8rem;
  color: #dc3545;
  background: rgba(220,53,69,.08);
  border-left: 3px solid #dc3545;
  padding: 6px 10px;
  border-radius: 4px;
}

:deep(.modal-content) {
  background: var(--bg-surface);
  color: var(--ntop-text-color);
  border: 1px solid var(--border-color);
}

:deep(.modal-header),
:deep(.modal-footer) {
  border-color: var(--border-subtle);
  background: var(--bg-elevated);
}

:deep(.border-bottom) { border-color: var(--border-subtle) !important; }
:deep(.text-muted)    { color: var(--ntop-muted-text-color) !important; }

.ap-ip-field { display: flex; flex-direction: column; gap: 4px; }
.ap-hint { color: var(--ntop-muted-text-color); cursor: help; font-size: 0.7rem; }

.ap-ip-chips {
  display: flex; flex-wrap: wrap; gap: 4px; align-items: center; margin-top: 2px;
}

.ap-ip-chip {
  font-family: ui-monospace, monospace;
  font-size: 0.7rem;
  padding: 1px 7px;
  border-radius: 999px;
  background: var(--bg-sunken);
  color: var(--ntop-text-color);
  border: 1px solid var(--border-subtle);
}

.ap-ip-chips-or {
  font-size: 0.65rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ntop-orange);
  padding-left: 4px;
}

.form-control.is-invalid {
  border-color: #dc3545 !important;
  box-shadow: 0 0 0 2px rgba(220,53,69,.15) !important;
}
</style>
