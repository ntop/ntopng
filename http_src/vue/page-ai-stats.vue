<template>
  <div class="ai-stats-page p-3">

    <!-- Filters -->
    <div class="ai-filter-card mb-3">
      <div class="ai-filter-row">

        <!-- Time range selectors -->
        <div class="ai-filter-group">
          <label class="ai-filter-label">
            <i class="fas fa-clock me-1"></i>{{ _i18n('llm.time_range')}}
          </label>
          <div class="d-flex gap-1">
            <button v-for="r in timeRanges" :key="r.value" class="ai-range-pill"
              :class="{ active: selectedRange === r.value }" @click="selectedRange = r.value; applyFilters()">
              {{ _i18n(r.label) }}
            </button>
          </div>
        </div>

        <div class="ai-filter-divider"></div>

        <!-- Provider -->
        <div class="ai-filter-group">
          <label class="ai-filter-label">{{ _i18n('llm.provider') }}</label>
          <select class="ai-select" v-model="selectedProvider" @change="applyFilters">
            <option value="">{{ _i18n('llm.all_providers') }}</option>
            <option v-for="p in availableProviders" :key="p" :value="p">{{ providerLabel(p) }}</option>
          </select>
        </div>

        <!-- Model -->
        <div class="ai-filter-group">
          <label class="ai-filter-label">{{ _i18n('llm.model') }}</label>
          <select class="ai-select" v-model="selectedModel" @change="applyFilters">
            <option value="">{{ _i18n('llm.all_models') }}</option>
            <option v-for="m in filteredModels" :key="m.model + m.provider" :value="m.model">{{ m.model }}</option>
          </select>
        </div>

        <!-- User (admin only) -->
        <div class="ai-filter-group" v-if="context.is_admin">
          <label class="ai-filter-label">{{ _i18n('llm.user') }}</label>
          <select class="ai-select" v-model="selectedUser" @change="applyFilters">
            <option value="">{{ _i18n('llm.all_users') }}</option>
            <option v-for="u in availableUsers" :key="u" :value="u">{{ u }}</option>
          </select>
        </div>

        <!-- Back to chat + refresh -->
        <div class="d-flex align-items-end gap-2 ms-auto">
          <a v-if="context.chat_url" :href="context.chat_url" class="ai-back-btn">
            <i class="fas fa-comment-alt me-1"></i>{{ _i18n('llm.back_to_chat')}}
          </a>
          <button class="ai-refresh-btn" @click="applyFilters" :title="_i18n('refresh')" :disabled="loading">
            <i class="fas fa-sync-alt" :class="{ 'fa-spin': loading }"></i>
          </button>
        </div>

      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading && !hasData" class="d-flex justify-content-center align-items-center py-5">
      <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">{{ _i18n('loading')}}</span>
      </div>
    </div>

    <!-- Empty state -->
    <div v-else-if="!loading && !hasData" class="text-center py-5">
      <i class="fas fa-database fa-3x mb-3 opacity-25"></i>
      <p class="text-muted mb-0">{{ _i18n('llm.no_usage_data') }}</p>
    </div>

    <!-- Content -->
    <template v-else>

      <!-- KPI badges -->
      <div class="row g-3 mb-3">

        <div class="col-6 col-xl-3">
          <div class="ai-kpi-orange rounded-3 p-3">
            <BadgeComponent id="kpi-calls" :params="kpiCallsParams" :get_component_data="kpiCallsGetter"
              :set_component_attr="noopSetAttr" :filters="badgeFilters" :hideLoading="true" />
          </div>
        </div>

        <div class="col-6 col-xl-3">
          <div class="ai-kpi-teal rounded-3 p-3">
            <BadgeComponent id="kpi-tokens" :params="kpiTokensParams" :get_component_data="kpiTokensGetter"
              :set_component_attr="noopSetAttr" :filters="badgeFilters" :hideLoading="true" />
          </div>
        </div>

        <div class="col-6 col-xl-3">
          <div class="ai-kpi-blue rounded-3 p-3">
            <BadgeComponent id="kpi-avgms" :params="kpiAvgMsParams" :get_component_data="kpiAvgMsGetter"
              :set_component_attr="noopSetAttr" :filters="badgeFilters" :hideLoading="true" />
          </div>
        </div>

        <div class="col-6 col-xl-3">
          <div class="ai-kpi-purple rounded-3 p-3">
            <BadgeComponent id="kpi-chats" :params="kpiChatsParams" :get_component_data="kpiChatsGetter"
              :set_component_attr="noopSetAttr" :filters="badgeFilters" :hideLoading="true" />
          </div>
        </div>

      </div>

      <!-- Token breakdown and Call type breakdown -->
      <div class="row g-3 mb-3">

        <div class="col-12 col-md-6">
          <div class="ai-section-card h-100">
            <div class="ai-section-header">
              <span class="ai-section-title">{{ _i18n('llm.token_breakdown') }}</span>
            </div>
            <div class="p-3">
              <div class="mb-3">
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <span class="d-flex align-items-center gap-2">
                    <span class="ai-dot ai-dot-orange"></span>
                    <span class="small">{{ _i18n('llm.prompt_tokens') }}</span>
                  </span>
                  <span class="d-flex align-items-center gap-2">
                    <span class="small fw-semibold">{{ fmtTokens(summary.total_prompt_tokens) }}</span>
                    <span class="badge bg-secondary-subtle text-secondary">{{ pctOf(summary.total_prompt_tokens,
                      summary.total_tokens) }}%</span>
                  </span>
                </div>
                <div class="progress" style="height:6px;">
                  <div class="progress-bar ai-bar-orange"
                    :style="{ width: pctOf(summary.total_prompt_tokens, summary.total_tokens) + '%' }"></div>
                </div>
              </div>
              <div>
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <span class="d-flex align-items-center gap-2">
                    <span class="ai-dot ai-dot-teal"></span>
                    <span class="small">{{ _i18n('llm.completion_tokens') }}</span>
                  </span>
                  <span class="d-flex align-items-center gap-2">
                    <span class="small fw-semibold">{{ fmtTokens(summary.total_completion_tokens) }}</span>
                    <span class="badge bg-secondary-subtle text-secondary">{{ pctOf(summary.total_completion_tokens,
                      summary.total_tokens) }}%</span>
                  </span>
                </div>
                <div class="progress" style="height:6px;">
                  <div class="progress-bar ai-bar-teal"
                    :style="{ width: pctOf(summary.total_completion_tokens, summary.total_tokens) + '%' }"></div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="col-12 col-md-6">
          <div class="ai-section-card h-100">
            <div class="ai-section-header">
              <span class="ai-section-title">{{ _i18n('llm.call_type_breakdown') }}</span>
            </div>
            <div class="p-3">
              <div v-if="byCallType.length === 0" class="text-muted small">—</div>
              <div v-for="ct in byCallType" :key="ct.call_type" class="mb-2">
                <div class="d-flex justify-content-between align-items-center mb-1">
                  <span :class="callTypeBadgeClass(ct.call_type)" class="badge">{{ _i18n("llm." + ct.call_type) || ct.call_type }}</span>
                  <span class="small text-muted">{{ fmtNumber(ct.calls) }}</span>
                </div>
                <div class="progress" style="height:4px;">
                  <div :class="callTypeBarClass(ct.call_type)" class="progress-bar"
                    :style="{ width: pctOfMax(ct.calls, maxCallTypeCalls) + '%' }"></div>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- Tables showing models used and user usage -->
      <div class="ai-section-card mb-3">

        <!-- Model table -->
        <div v-show="activePage === 'model'">
          <TableWithConfig ref="modelTableRef" table_config_id="llm_by_model" :f_map_config="mapModelConfig"
            :csrf="context.csrf">
            <template v-slot:custom_header>
              <NavbarTabs :tabs="tabs" :active_tab_id="activePage" @on_click="(tab) => (activePage = tab.id)" />
            </template>
          </TableWithConfig>
        </div>

        <!-- User table -->
        <div v-show="activePage === 'user'">
          <TableWithConfig ref="userTableRef" table_config_id="llm_by_user" :f_map_config="mapUserConfig"
            :csrf="context.csrf">
            <template v-slot:custom_header>
              <NavbarTabs :tabs="tabs" :active_tab_id="activePage" @on_click="(tab) => (activePage = tab.id)" />
            </template>
          </TableWithConfig>
        </div>

      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from "vue";
import { default as BadgeComponent } from "./dashboard-badge.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

// Time ranges
const timeRanges = [
  { value: "1h",  label: 'llm.1h'  },
  { value: "6h",  label: 'llm.6h'  },
  { value: "24h", label: 'llm.24h' },
  { value: "7d",  label: 'llm.7d'  },
  { value: "30d", label: 'llm.30d' },
];
const rangeSeconds = { "1h": 3600, "6h": 21600, "24h": 86400, "7d": 604800, "30d": 2592000 };

// Navbar Tabs
const activePage = ref("model");

const tabs = [
  { id: "model", label_i18n: "llm.usage_by_model" },
  { id: "user", label_i18n: "llm.usage_by_user" },
];

// State
const loading = ref(false);
const dataInitialized = ref(false);
const selectedRange = ref("24h");
const selectedProvider = ref("");
const selectedModel = ref("");
const selectedUser = ref("");

const availableProviders = ref([]);
const availableModels = ref([]);
const availableUsers = ref([]);

const summary = ref({});
const byModel = ref([]);
const byCallType = ref([]);
const byUser = ref([]);

// Triggers badge refresh after data is loaded
const badgeFilters = ref({});

// Table refs for manual refresh on filter changes
const modelTableRef = ref(null);
const userTableRef = ref(null);

// Computed
const hasData = computed(() => summary.value.total_calls && parseInt(summary.value.total_calls) > 0);

const filteredModels = computed(() =>
  selectedProvider.value
    ? availableModels.value.filter(m => m.provider === selectedProvider.value)
    : availableModels.value
);

const maxCallTypeCalls = computed(() =>
  Math.max(...byCallType.value.map(c => parseInt(c.calls) || 0), 1)
);

// Formatters
function fmtNumber(v) {
  const n = parseInt(v) || 0;
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M";
  if (n >= 1_000) return (n / 1_000).toFixed(1) + "K";
  return n.toLocaleString();
}
function fmtTokens(v) { return fmtNumber(v); }
function fmtMs(v) {
  const ms = parseFloat(v) || 0;
  if (ms >= 60000) return (ms / 60000).toFixed(1) + "m";
  if (ms >= 1000) return (ms / 1000).toFixed(1) + "s";
  return Math.round(ms) + "ms";
}
function pctOf(part, total) {
  const p = parseFloat(part) || 0, t = parseFloat(total) || 0;
  return t === 0 ? 0 : Math.round((p / t) * 100);
}
function pctOfMax(val, max) {
  return Math.max(2, Math.round(((parseFloat(val) || 0) / (parseFloat(max) || 1)) * 100));
}

// Provider helpers
function providerLabel(p) {
  if (p === "llm_anthropic") return _i18n("prefs.llm_anthropic");
  if (p === "llm_openai") return _i18n("prefs.llm_openai");
  if (p === "llm_local") return _i18n("prefs.llm_local");
  return p || "—";
}
function providerIcon(p) {
  if (p === "llm_openai") return "bi bi-openai";
  if (p === "llm_anthropic") return "bi bi-anthropic";
  return "fa-solid fa-microchip";
}
function callTypeBadgeClass(ct) {
  const map = { initial_call: "bg-primary-subtle text-primary", tool_followup: "bg-warning-subtle text-warning", final_response: "bg-success-subtle text-success", retry: "bg-danger-subtle text-danger" };
  return map[ct] ?? "bg-secondary-subtle text-secondary";
}
function callTypeBarClass(ct) {
  const map = { initial_call: "bg-primary", tool_followup: "bg-warning", final_response: "bg-success", retry: "bg-danger" };
  return map[ct] ?? "bg-secondary";
}

// Dashboard badge setup

// We provide a custom get_component_data that reads from our already-fetched
// summary ref. The badge watches the `filters` prop — we bump `badgeFilters`
// after applyFilters() completes so each badge re-reads the latest data.
//
const noopSetAttr = () => { };

function makeBadgeParams(field, i18nKey, icon) {
  return { url: '/', counter_path: field, counter_formatter: 'no_formatting', i18n_name: i18nKey, icon };
}

const kpiCallsParams = makeBadgeParams('calls', 'llm.stat_total_calls', 'fas fa-bolt');
const kpiTokensParams = makeBadgeParams('tokens', 'llm.stat_total_tokens', 'fas fa-coins');
const kpiAvgMsParams = makeBadgeParams('avgms', 'llm.stat_avg_response', 'fas fa-stopwatch');
const kpiChatsParams = makeBadgeParams('chats', 'llm.stat_unique_chats', 'fas fa-comments');

const kpiCallsGetter = async () => ({ calls: fmtNumber(summary.value.total_calls) });
const kpiTokensGetter = async () => ({ tokens: fmtTokens(summary.value.total_tokens) });
const kpiAvgMsGetter = async () => ({ avgms: fmtMs(summary.value.avg_completion_time_ms) });
const kpiChatsGetter = async () => ({ chats: fmtNumber(summary.value.unique_chats) });

// Table config mappers
function mapModelConfig(config) {
  config.get_rows = async () => ({
    totalRowCount: byModel.value.length,
    rows: byModel.value,
  });

  const add = (id, fn) => {
    const col = config.columns.find(c => c.id === id);
    if (col) col.render_func = fn;
  };

  add('provider', (d) => `<span class="d-flex align-items-center gap-1"><i class="${providerIcon(d)} small opacity-75"></i><span class="text-muted small">${providerLabel(d)}</span></span>`);
  add('model', (d) => `<code class="small">${d ?? ''}</code>`);
  add('calls', (d) => fmtNumber(d));
  add('prompt_tokens', (d) => fmtTokens(d));
  add('completion_tokens', (d) => fmtTokens(d));
  add('total_tokens', (d) => `<strong>${fmtTokens(d)}</strong>`);
  add('avg_ms', (d) => fmtMs(d));
  add('max_ms', (d) => `<span class="text-muted">${fmtMs(d)}</span>`);
  return config;
}

function mapUserConfig(config) {
  config.get_rows = async () => ({
    totalRowCount: byUser.value.length,
    rows: byUser.value,
  });
  const add = (id, fn) => {
    const col = config.columns.find(c => c.id === id);
    if (col) col.render_func = fn;
  };
  add('username', (d) => `<span><i class="fas fa-user-circle me-1 opacity-50"></i>${d}</span>`);
  add('calls', (d) => fmtNumber(d));
  add('total_tokens', (d) => `<strong>${fmtTokens(d)}</strong>`);
  add('prompt_tokens', (d) => fmtTokens(d));
  add('completion_tokens', (d) => fmtTokens(d));
  add('unique_chats', (d) => fmtNumber(d));
  add('avg_ms', (d) => fmtMs(d));
  add('token_share', (d) => {
    const pct = pctOf(d, summary.value.total_tokens);
    return `<div class="progress mb-1" style="height:5px;"><div class="progress-bar bg-primary" style="width:${pct}%"></div></div><span class="text-muted" style="font-size:0.7rem;">${pct}%</span>`;
  });
  return config;
}

// API calls
async function loadFilters() {
  try {
    const r = await fetch(`${http_prefix}/lua/pro/rest/v2/get/llm/usage_filters.lua`);
    const json = await r.json();
    const data = json.rsp || {};
    availableModels.value = Array.isArray(data.models) ? data.models : [];
    availableUsers.value = (Array.isArray(data.users) ? data.users : []).map(u => u.username).filter(Boolean);
    availableProviders.value = [...new Set(availableModels.value.map(m => m.provider).filter(Boolean))];
  } catch (e) {
    console.error("Failed to load AI usage filters", e);
  }
}

async function applyFilters() {
  loading.value = true;
  const wasInit = dataInitialized.value;

  try {
    const now = Math.floor(Date.now() / 1000);
    const secs = rangeSeconds[selectedRange.value] || 86400;
    const params = new URLSearchParams({ epoch_begin: now - secs, epoch_end: now });

    if (selectedProvider.value) params.set("provider", selectedProvider.value);
    if (selectedModel.value) params.set("model", selectedModel.value);
    if (selectedUser.value) params.set("username", selectedUser.value);

    const r = await fetch(`${http_prefix}/lua/pro/rest/v2/get/llm/token_usage.lua?${params.toString()}`);
    const json = await r.json();
    const data = json.rsp || {};

    summary.value = data.summary || {};
    byModel.value = Array.isArray(data.by_model) ? data.by_model : [];
    byCallType.value = Array.isArray(data.by_call_type) ? data.by_call_type : [];
    byUser.value = Array.isArray(data.by_user) ? data.by_user : [];
  } catch (e) {
    console.error("Failed to load AI usage stats", e);
  } finally {
    loading.value = false;
    dataInitialized.value = true;
    // Trigger badge refresh now that summary is populated
    badgeFilters.value = { _tick: Date.now() };
    
    // On subsequent filter changes, tables are already mounted — refresh them
    if (wasInit) {
      await nextTick();
      modelTableRef.value?.refresh_table(true);
      userTableRef.value?.refresh_table(true);
    }
  }
}

onMounted(async () => {
  await loadFilters();
  await applyFilters();
});
</script>

<style scoped>
.ai-stats-page {
  --ai-orange: var(--ntop-orange, #FF8F00);
  --ai-border: var(--chat-border, rgba(0, 0, 0, 0.10));
  --ai-header-bg: var(--navbar-tab-container-bg, #f1f3f5);
  --ai-card-bg: var(--bs-body-bg, #ffffff);
  --ai-muted: var(--ntop-muted-text-color, #37474F);
}

:root[data-theme='dark'] .ai-stats-page {
  --ai-border: rgba(255, 255, 255, 0.08);
  --ai-header-bg: #111c24;
  --ai-card-bg: #1a2736;
}

/* Filter card */
.ai-filter-card {
  background: var(--ai-card-bg);
  border: 1px solid var(--ai-border);
  border-radius: 12px;
  padding: 0.8rem 1rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, .05);
}

.ai-filter-row {
  display: flex;
  align-items: flex-end;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
}

.ai-filter-group {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.ai-filter-label {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ai-muted);
  margin: 0;
}

.ai-filter-divider {
  width: 1px;
  height: 34px;
  background: var(--ai-border);
  flex-shrink: 0;
}

.ai-range-pill {
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.2rem 0.6rem;
  border-radius: 6px;
  border: 1px solid var(--ai-border);
  background: transparent;
  color: var(--ai-muted);
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
}

.ai-range-pill:hover {
  background: rgba(0, 0, 0, .05);
}

.ai-range-pill.active {
  background: rgba(255, 143, 0, .12);
  border-color: var(--ai-orange);
  color: var(--ai-orange);
  font-weight: 600;
}

.ai-select {
  font-size: 0.8rem;
  border: 1px solid var(--ai-border);
  border-radius: 7px;
  padding: 0.25rem 1.6rem 0.25rem 0.55rem;
  appearance: none;
  background-color: var(--ai-card-bg);
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6'%3E%3Cpath fill='%236c757d' d='M0 0l5 6 5-6z'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 0.45rem center;
  background-size: 8px;
  color: inherit;
  min-width: 120px;
  transition: border-color 0.15s;
}

.ai-select:focus {
  outline: none;
  border-color: var(--ai-orange);
  box-shadow: 0 0 0 2px rgba(255, 143, 0, .18);
}

.ai-back-btn {
  font-size: 0.78rem;
  color: var(--ai-muted);
  text-decoration: none;
  border: 1px solid var(--ai-border);
  border-radius: 7px;
  padding: 0.25rem 0.7rem;
  white-space: nowrap;
  transition: border-color 0.15s, color 0.15s;
}

.ai-back-btn:hover {
  border-color: var(--ai-orange);
  color: var(--ai-orange);
}

.ai-refresh-btn {
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--ai-border);
  border-radius: 7px;
  background: transparent;
  color: var(--ai-muted);
  cursor: pointer;
  font-size: 0.78rem;
  transition: border-color 0.12s, color 0.12s;
}

.ai-refresh-btn:hover:not(:disabled) {
  border-color: var(--ai-orange);
  color: var(--ai-orange);
}

.ai-refresh-btn:disabled {
  opacity: 0.45;
  cursor: default;
}

/* KPI badge wrappers */
.ai-kpi-orange {
  background: var(--ntop-orange, #FF8F00);
}

.ai-kpi-teal {
  background: #0d9488;
}

.ai-kpi-blue {
  background: #2563eb;
}

.ai-kpi-purple {
  background: #7c3aed;
}

/* Section cards */
.ai-section-card {
  background: var(--ai-card-bg);
  border: 1px solid var(--ai-border);
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, .04);
}

.ai-section-header {
  padding: 0.6rem 1rem;
  border-bottom: 1px solid var(--ai-border);
  background: var(--ai-header-bg);
}

.ai-section-title {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.07em;
  color: var(--ai-muted);
}

/* Token dot indicators */
.ai-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.ai-dot-orange {
  background: var(--ai-orange);
}

.ai-dot-teal {
  background: #0d9488;
}

/* Progress bar colors */
.ai-bar-orange {
  background: var(--ai-orange) !important;
}

.ai-bar-teal {
  background: #0d9488 !important;
}
</style>
