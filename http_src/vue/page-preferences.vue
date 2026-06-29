<!--
  (C) 2014-26 - ntop.org

  POST body uses pref_section / pref_key / pref_value
-->
<template>
  <div class="prefs-shell">

    <!-- Sidebar -->
    <aside class="prefs-sidebar">

      <!-- Search -->
      <div class="sidebar-search-wrap">
        <i class="fas fa-search sidebar-search-icon"></i>
        <input
          ref="searchInput"
          v-model="sidebar_search"
          type="search"
          class="sidebar-search-input"
          :placeholder="_i18n('prefs.vue_prefs.search_placeholder')"
          autocomplete="off"
          @input="onSearch"
        />
        <button
          v-show="sidebar_search"
          class="sidebar-search-clear"
          @click="clearSearch"
          :title="_i18n('prefs.vue_prefs.clear_search')"
        ><i class="fas fa-xmark"></i></button>
      </div>

      <!-- Nav -->
      <nav class="sidebar-nav" :aria-label="_i18n('prefs.vue_prefs.settings_nav_label')">

        <!-- Expert View toggle — first item in nav, below search divider -->
        <div class="expert-row">
          <span class="expert-row-label">
            <i class="fas fa-sliders expert-row-icon"></i>
            {{ _i18n('prefs.expert_view') }}
          </span>
          <button
            type="button"
            class="expert-pill"
            :class="{ 'expert-pill--on': advanced_open }"
            @click="toggleAdvanced"
            :aria-label="advanced_open ? _i18n('prefs.vue_prefs.hide_advanced_sections') : _i18n('prefs.vue_prefs.show_advanced_sections')"
            role="switch"
            :aria-checked="advanced_open"
          >
            <span class="expert-pill-thumb"></span>
          </button>
        </div>

        <!-- No results -->
        <div v-if="search_has_results === false" class="sidebar-empty">
          {{ _i18n('prefs.vue_prefs.no_results_prefix') }}&ldquo;{{ sidebar_search }}&rdquo;
        </div>

        <template v-else>
          <!-- All sections flat, sorted alphabetically. Advanced hidden when expert off. -->
          <template v-for="section in sorted_all_sections" :key="section.id">
            <button
              v-show="matchesSearch(section) && (advanced_open || !section.advanced)"
              class="sidebar-item"
              :class="{
                'sidebar-item--active': active_id === section.id,
                'sidebar-item--locked': section.pro_only && !context_is_pro
              }"
              :disabled="section.pro_only && !context_is_pro"
              @click="setActive(section.id)"
            >
              <span class="sidebar-item-label">{{ section.label }}</span>
              <!-- Expert badge on advanced sections -->
              <span v-if="section.advanced && advanced_open" class="sidebar-expert-badge">
                {{ _i18n('prefs.vue_prefs.expert_badge') }}
              </span>
              <span
                v-if="dirty_sections.has(section.id)"
                class="sidebar-dirty-dot"
                :title="_i18n('prefs.vue_prefs.unsaved_dot_title')"
              ></span>
              <!-- Pro crown icon — links to shop on click, tooltip on hover -->
              <a
                v-if="section.pro_only && !context_is_pro"
                href="https://shop.ntop.org/"
                target="_blank"
                rel="noopener"
                class="sidebar-pro-badge"
                data-bs-toggle="tooltip"
                data-bs-placement="right"
                :title="i18n_pro_tooltip"
                @click.stop
              >
                <i class="fas fa-crown sidebar-pro-icon"></i>
              </a>
            </button>
          </template>
        </template>
      </nav>

    </aside>

    <!-- Main panel -->
    <main class="prefs-main">

      <!-- Loading -->
      <div v-if="loading" class="prefs-state-center">
        <div class="spinner-border spinner-border-sm text-secondary me-2"></div>
        <span>{{ _i18n('prefs.vue_prefs.loading') }}</span>
      </div>

      <!-- Load error -->
      <div v-else-if="load_error" class="prefs-state-center">
        <div class="alert alert-danger mb-0">
          <i class="fas fa-triangle-exclamation me-2"></i>{{ load_error }}
        </div>
      </div>

      <!-- Section view -->
      <template v-else-if="active_section">

        <!-- Header — fixed height, title only -->
        <div class="prefs-main-header">
          <div class="prefs-main-header-text">
            <h5 class="prefs-section-title">{{ active_section.label }}</h5>
            <p v-if="active_section.description" class="prefs-section-sub">
              {{ active_section.description }}
            </p>
          </div>
        </div>

        <!-- Banners — sit between header and body, height is natural/auto -->
        <div class="prefs-banners">
          <transition name="banner-slide">
            <div v-if="is_dirty" class="dirty-banner" role="alert">
              <i class="fas fa-circle-dot dirty-banner-icon"></i>
              <span class="dirty-banner-text">{{ _i18n('prefs.vue_prefs.unsaved_banner') }}</span>
              <div class="dirty-banner-actions">
                <button
                  class="btn btn-sm btn-outline-secondary"
                  :disabled="saving"
                  @click="discardChanges"
                >{{ _i18n('prefs.vue_prefs.discard') }}</button>
                <button
                  class="btn btn-sm btn-primary"
                  :disabled="saving || has_validation_errors"
                  :title="has_validation_errors ? _i18n('prefs.vue_prefs.fix_validation') : ''"
                  @click="saveSection"
                >
                  <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
                  <i v-else class="fas fa-floppy-disk me-1"></i>
                  {{ _i18n('prefs.vue_prefs.save_changes') }}
                </button>
              </div>
            </div>
          </transition>
          <transition name="banner-slide">
            <div v-if="save_success" class="alert alert-success d-flex align-items-center py-2 mb-0 rounded-0 border-start-0 border-end-0">
              <i class="fas fa-circle-check me-2"></i>
              <span>{{ _i18n('prefs.vue_prefs.changes_saved') }}</span>
            </div>
          </transition>
          <transition name="banner-slide">
            <div v-if="save_error" class="alert alert-danger d-flex align-items-center py-2 mb-0 rounded-0 border-start-0 border-end-0">
              <i class="fas fa-circle-xmark me-2 flex-shrink-0"></i>
              <span class="flex-grow-1">{{ save_error }}</span>
              <button type="button" class="btn-close ms-2" style="font-size:0.65rem" @click="save_error = ''"></button>
            </div>
          </transition>
        </div>

        <!-- Field groups -->
        <div class="prefs-main-body">
          <template v-for="(group, gi) in entry_groups" :key="gi">
            <div v-if="group.label" class="prefs-group-label">{{ group.label }}</div>
            <div class="card prefs-card mb-3">
              <div class="card-body p-0">
                <PrefField
                  v-for="entry in group.entries"
                  :key="entry.key"
                  :entry="entry"
                  v-model="form_values[entry.key]"
                  :visible="isVisible(entry.key)"
                  :highlight="entryMatchesSearch(entry)"
                  :siblingValues="form_values"
                  @update:model-value="onFieldChange(entry, $event)"
                  @validation-error="onValidationError(entry.key, $event)"
                />
              </div>
            </div>
          </template>
        </div>

      </template>

      <!-- Nothing selected -->
      <div v-else-if="!loading" class="prefs-state-center text-muted">
        {{ _i18n('prefs.vue_prefs.select_section') }}
      </div>

    </main>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { default as PrefField } from './pref-field.vue';

const props = defineProps({
  context: { type: Object, default: () => ({}) },
});

const context_is_pro  = computed(() => !!props.context?.is_pro);

function _i18n(key) {
  return (typeof window.i18n === 'function' && window.i18n(key)) || key;
}

const i18n_pro_tooltip = computed(() => _i18n('prefs.vue_prefs.pro_enterprise_tooltip'));

const sections           = ref([]);
const active_id          = ref('');
const form_values        = ref({});
const original_values    = ref({});
const visible_keys       = ref(new Set());
const dirty_sections     = ref(new Set());
const field_errors       = ref({});
const sidebar_search     = ref('');
const search_has_results = ref(null);
const search_highlight   = ref('');
const advanced_open      = ref(localStorage.getItem('ntopng_prefs_adv') === '1');
const loading            = ref(true);
const load_error         = ref('');
const saving             = ref(false);
const save_success       = ref(false);
const save_error         = ref('');
const searchInput        = ref(null);

// Computed
function sortedByLabel(arr) {
  return [...arr].sort((a, b) => a.label.localeCompare(b.label));
}

// Single flat sorted list — advanced sections interleaved alphabetically
const sorted_all_sections = computed(() => sortedByLabel(sections.value));

const advanced_sections = computed(() => sections.value.filter(s => s.advanced));

const active_section = computed(() =>
  sections.value.find(s => s.id === active_id.value) || null
);

const entry_groups = computed(() => {
  if (!active_section.value) return [];
  const groups = [];
  let cur = null;
  for (const entry of (active_section.value.entries || [])) {
    const label = entry.section || null;
    if (!cur || cur.label !== label) {
      cur = { label, entries: [] };
      groups.push(cur);
    }
    cur.entries.push(entry);
  }
  return groups;
});

const is_dirty = computed(() => {
  for (const key of Object.keys(form_values.value)) {
    if (form_values.value[key] !== original_values.value[key]) return true;
  }
  return false;
});

const has_validation_errors = computed(() =>
  Object.values(field_errors.value).some(e => e)
);

// Helpers
function normalize(s) {
  return (s || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function matchesSearch(section) {
  if (!sidebar_search.value) return true;
  const words = normalize(sidebar_search.value).split(' ').filter(Boolean);
  if (!words.length) return true;

  const lbl = normalize(section.label);
  if (words.every(w => lbl.includes(w))) return true;

  for (const entry of (section.entries || [])) {
    const haystack = normalize((entry.title || '') + ' ' + (entry.description || ''));
    if (words.every(w => haystack.includes(w))) return true;
  }
  return false;
}

function isVisible(key) {
  return visible_keys.value.has(key);
}

function entryMatchesSearch(entry) {
  if (!search_highlight.value) return false;
  const words    = search_highlight.value.split(' ').filter(Boolean);
  const haystack = normalize((entry.title || '') + ' ' + (entry.description || ''));
  return words.every(w => haystack.includes(w));
}

function buildVisibleKeys(entries, values) {
  const vis = new Set(entries.map(e => e.key));
  for (const entry of entries) {
    if (entry.to_switch && entry.type === 'toggle') {
      const onVal  = entry.on_value  ?? '1';
      const offVal = entry.off_value ?? '0';
      const val    = values[entry.key] ?? entry.default ?? offVal;
      const isOn   = val === onVal;
      const show   = entry.reverse_switch ? !isOn : isOn;
      if (!show) {
        for (const dep of entry.to_switch) vis.delete(dep);
      }
    }
  }
  return vis;
}

function onSearch() {
  if (!sidebar_search.value) {
    search_has_results.value = null;
    search_highlight.value   = '';
    return;
  }

  const visible = sections.value.filter(s => advanced_open.value || !s.advanced);
  const matches = visible.filter(s => matchesSearch(s));
  search_has_results.value = matches.length > 0 ? true : false;

  if (matches.length === 0) {
    search_highlight.value = '';
    return;
  }

  search_highlight.value = normalize(sidebar_search.value);

  const current_matches = matches.find(s => s.id === active_id.value);
  if (!current_matches) {
    setActive(matches[0].id);
  }
  nextTick(() => {
    const firstMatch = matches[0];
    if (!firstMatch) return;
    const matchingEntry = (firstMatch.entries || []).find(e => entryMatchesSearch(e));
    if (matchingEntry) {
      const el = document.getElementById('pref-row-' + matchingEntry.key);
      el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  });
}

function clearSearch() {
  sidebar_search.value     = '';
  search_has_results.value = null;
  search_highlight.value   = '';
  searchInput.value?.focus();
}

function setActive(id) {
  if (active_id.value === id) return;
  active_id.value = id;
  window.location.hash = id;
  loadSection();
}

function loadSection() {
  if (!active_section.value) return;
  const entries = active_section.value.entries || [];
  const vals = {};
  for (const e of entries) {
    vals[e.key] = e.value ?? e.default ?? '';
  }
  form_values.value     = { ...vals };
  original_values.value = { ...vals };
  visible_keys.value    = buildVisibleKeys(entries, vals);
  field_errors.value    = {};
  save_success.value    = false;
  save_error.value      = '';
}

function onFieldChange(entry, newVal) {
  form_values.value[entry.key] = newVal;
  const entries = active_section.value?.entries || [];
  visible_keys.value = buildVisibleKeys(entries, form_values.value);
}

function onValidationError(key, errorMsg) {
  field_errors.value = { ...field_errors.value, [key]: errorMsg };
}

watch(is_dirty, (dirty) => {
  const id = active_id.value;
  if (!id) return;
  if (dirty) dirty_sections.value.add(id);
  else dirty_sections.value.delete(id);
  dirty_sections.value = new Set(dirty_sections.value);
});

function discardChanges() {
  form_values.value  = { ...original_values.value };
  field_errors.value = {};
  if (active_section.value) {
    visible_keys.value = buildVisibleKeys(active_section.value.entries || [], form_values.value);
  }
  save_error.value = '';
}

function applyRuntimeEffect(key, value) {
  if (key === 'toggle_theme') {
    const mode = value === 'dark' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', mode);
    document.body.classList.toggle('dark', mode === 'dark');
  }
}

async function saveSection() {
  if (!is_dirty.value || saving.value || has_validation_errors.value) return;
  saving.value       = true;
  save_success.value = false;
  save_error.value   = '';

  const http_prefix = props.context?.http_prefix || '';
  const csrf        = props.context?.csrf || '';
  const url         = `${http_prefix}/lua/rest/v2/set/ntopng/preferences.lua`;
  const section_id  = active_id.value;

  const changed = Object.keys(form_values.value).filter(
    k => form_values.value[k] !== original_values.value[k]
  );

  try {
    for (const key of changed) {
      const body = new URLSearchParams({
        csrf,
        pref_section: section_id,
        pref_key:     key,
        pref_value:   form_values.value[key],
      });
      const resp = await fetch(url, {
        method:  'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body:    body.toString(),
      });
      const data = await resp.json();
      if (data?.rc !== 0) {
        throw new Error(data?.rc_str_hr || data?.rc_str || `Error saving ${key}`);
      }
      applyRuntimeEffect(key, form_values.value[key]);
    }
    const sec = sections.value.find(s => s.id === section_id);
    if (sec) {
      for (const entry of (sec.entries || [])) {
        if (entry.key in form_values.value) {
          entry.value = form_values.value[entry.key];
        }
      }
    }
    original_values.value = { ...form_values.value };
    dirty_sections.value.delete(active_id.value);
    dirty_sections.value  = new Set(dirty_sections.value);
    save_success.value    = true;
    document.dispatchEvent(new CustomEvent('ntopng-preferences-saved'));
    setTimeout(() => { save_success.value = false; }, 2500);
  } catch (err) {
    save_error.value = err.message || _i18n('prefs.vue_prefs.save_failed');
  } finally {
    saving.value = false;
  }
}

function toggleAdvanced() {
  advanced_open.value = !advanced_open.value;
  localStorage.setItem('ntopng_prefs_adv', advanced_open.value ? '1' : '0');
  // If current section is advanced and we're hiding expert, jump to first basic section
  if (!advanced_open.value && active_section.value?.advanced) {
    const first = sorted_all_sections.value.find(s => !s.advanced);
    if (first) setActive(first.id);
  }
}

onMounted(async () => {
  const http_prefix = props.context?.http_prefix || '';
  try {
    const resp = await fetch(`${http_prefix}/lua/rest/v2/get/ntopng/prefs_schema.lua`);
    const data = await resp.json();
    sections.value = data?.rsp?.subpages || [];

    const hash  = window.location.hash?.replace('#', '');
    const found = hash && sections.value.find(s => s.id === hash);

    const reachable = sections.value.filter(s =>
      (!s.pro_only || context_is_pro.value) && (advanced_open.value || !s.advanced)
    );
    active_id.value = (found && (!found.pro_only || context_is_pro.value) && (advanced_open.value || !found.advanced))
      ? found.id
      : (reachable[0]?.id || '');

    if (found?.advanced) advanced_open.value = true;

    await nextTick();
    loadSection();

    await nextTick();
    if (window.bootstrap?.Tooltip) {
      document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach(el => {
        new window.bootstrap.Tooltip(el, { trigger: 'hover' });
      });
    }
  } catch (err) {
    load_error.value = err.message || _i18n('prefs.vue_prefs.load_failed');
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.prefs-shell {
  --prefs-header-h: 4rem;
  display: flex;
  height: calc(100vh - var(--sb-navbar-h, 3rem) - 5.5rem);
  min-height: 400px;
  background: var(--bg-surface, #fff);
  color: var(--ntop-text-color, #111);
  overflow: hidden;
  border: 1px solid var(--border-color, #dee2e6);
  border-radius: 0.375rem;
}

.prefs-sidebar {
  width: 224px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  min-height: 0;
  border-right: 1px solid var(--border-color, #dee2e6);
  background: var(--bg-elevated, #f8f9fa);
  overflow: hidden;
}

.expert-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.6rem 0.875rem 0.55rem calc(0.875rem - 3px);
  border-left: 3px solid transparent;
  border-bottom: 1px solid var(--border-color, #dee2e6);
  margin-bottom: 0.25rem;
  background: var(--bg-elevated, #f8f9fa);
}

.expert-row-label {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.775rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  color: var(--ntop-text-color, #212529);
  user-select: none;
}
.expert-row-icon {
  font-size: 0.75rem;
  color: var(--ntop-muted-text-color, #6c757d);
}
[data-theme="dark"] .expert-row-label { color: #e2e8f0; }
[data-theme="dark"] .expert-row-icon  { color: #94a3b8; }

/* Toggle pill — larger, clear on/off */
.expert-pill {
  flex-shrink: 0;
  position: relative;
  width: 2.4rem;
  height: 1.3rem;
  border-radius: 1rem;
  border: none;
  background: var(--border-color, #ced4da);
  cursor: pointer;
  padding: 0;
  transition: background 0.18s;
  outline: none;
}
.expert-pill:focus-visible {
  box-shadow: 0 0 0 2px rgba(255,143,0,.4);
}
.expert-pill--on {
  background: var(--ntop-orange, #FF8F00);
}
.expert-pill-thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 0.95rem;
  height: 0.95rem;
  border-radius: 50%;
  background: #fff;
  box-shadow: 0 1px 3px rgba(0,0,0,.2);
  transition: transform 0.18s;
}
.expert-pill--on .expert-pill-thumb {
  transform: translateX(1.1rem);
}

/* Search — same height as .prefs-main-header so the dividing lines align */
.sidebar-search-wrap {
  position: relative;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  height: var(--prefs-header-h, 4rem);
  padding: 0 0.75rem;
  border-bottom: 1px solid var(--border-color, #dee2e6);
}
.sidebar-search-icon {
  position: absolute;
  left: 1.25rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--ntop-muted-text-color, #6c757d);
  font-size: 0.7rem;
  pointer-events: none;
}
.sidebar-search-input {
  width: 100%;
  padding: 0.4rem 1.6rem;
  border: 1px solid var(--border-color, #dee2e6);
  border-radius: 0.375rem;
  font-size: 0.8125rem;
  background: var(--input-bg, #fff);
  color: var(--input-text, #495057);
  outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  -webkit-appearance: none;
}
.sidebar-search-input::-webkit-search-cancel-button { display: none; }
.sidebar-search-input:focus {
  border-color: var(--ntop-orange, #FF8F00);
  box-shadow: 0 0 0 2px rgba(255,143,0,.18);
}
.sidebar-search-clear {
  position: absolute;
  right: 1.25rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--ntop-muted-text-color, #6c757d);
  padding: 0;
  cursor: pointer;
  font-size: 0.7rem;
  line-height: 1;
}
.sidebar-search-clear:hover { color: var(--ntop-text-color, #111); }

/* Nav — scrollable, takes remaining height */
.sidebar-nav {
  flex: 1;
  overflow-y: auto;
  padding: 0.375rem 0;
  scrollbar-width: thin;
  scrollbar-color: var(--scrollbar-thumb, rgba(55,71,79,.38)) transparent;
}
.sidebar-nav::-webkit-scrollbar        { width: 4px; }
.sidebar-nav::-webkit-scrollbar-track  { background: transparent; }
.sidebar-nav::-webkit-scrollbar-thumb  { background: var(--scrollbar-thumb, rgba(55,71,79,.38)); border-radius: 2px; }

.sidebar-empty {
  padding: 1rem 0.875rem;
  font-size: 0.8rem;
  color: var(--ntop-muted-text-color, #6c757d);
}

/* Nav items */
.sidebar-item {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  width: 100%;
  padding: 0.42rem 0.875rem 0.42rem calc(0.875rem - 3px);
  background: none;
  border: none;
  border-left: 3px solid transparent;
  text-align: left;
  font-size: 0.8275rem;
  color: var(--ntop-text-color, #111);
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s, color 0.12s;
  line-height: 1.35;
}
.sidebar-item:hover:not(:disabled) {
  background: rgba(255,143,0,.07);
  color: var(--ntop-orange, #FF8F00);
}
.sidebar-item--active {
  border-left-color: var(--ntop-orange, #FF8F00);
  background: rgba(255,143,0,.1);
  color: var(--ntop-orange, #FF8F00);
  font-weight: 600;
}
.sidebar-item--active:hover { background: rgba(255,143,0,.14); }
.sidebar-item--locked { opacity: 0.55; cursor: not-allowed; }
.sidebar-item--locked:hover { background: none; color: var(--ntop-text-color, #111); }

.sidebar-item-label {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Expert badge on advanced section items */
.sidebar-expert-badge {
  flex-shrink: 0;
  font-size: 0.58rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  padding: 0.1em 0.38em;
  border-radius: 3px;
  background: rgba(100,116,139,.12);
  color: var(--ntop-muted-text-color, #6c757d);
  border: 1px solid rgba(100,116,139,.2);
  white-space: nowrap;
}
[data-theme="dark"] .sidebar-expert-badge {
  background: rgba(148,163,184,.13);
  border-color: rgba(148,163,184,.22);
}

/* Dirty unsaved dot */
.sidebar-dirty-dot {
  flex-shrink: 0;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--ntop-orange, #FF8F00);
}

/* PRO badge */
.sidebar-pro-badge {
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  padding: 0.15em 0.45em;
  border-radius: 3px;
  background: rgba(255,143,0,.15);
  color: var(--ntop-orange-dark, #C56000);
  border: 1px solid rgba(255,143,0,.3);
  text-decoration: none;
  cursor: pointer;
  transition: background 0.12s;
  white-space: nowrap;
}
.sidebar-pro-badge:hover { background: rgba(255,143,0,.28); color: var(--ntop-orange-dark, #C56000); }
[data-theme="dark"] .sidebar-pro-badge { color: var(--ntop-orange-light, #FFC046); border-color: rgba(255,143,0,.35); }
.sidebar-pro-icon { font-size: 0.58rem; }

.prefs-main {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: var(--bg-surface, #fff);
}

.prefs-state-center {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  color: var(--ntop-text-color, #111);
}

/* Section header */
.prefs-main-header {
  height: var(--prefs-header-h, 4rem);
  padding: 0 1.5rem;
  border-bottom: 1px solid var(--border-color, #dee2e6);
  flex-shrink: 0;
  display: flex;
  align-items: center;
  background: var(--bg-surface, #fff);
  overflow: hidden;
}
.prefs-main-header-text {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}
.prefs-section-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--ntop-text-color, #111);
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.prefs-section-sub {
  font-size: 0.8125rem;
  color: var(--ntop-muted-text-color, #6c757d);
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Banner zone */
.prefs-banners {
  flex-shrink: 0;
  border-bottom: 1px solid var(--border-color, #dee2e6);
}
.prefs-banners:empty { border-bottom: none; }

/* Unsaved changes banner */
.dirty-banner {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
  padding: 0.6rem 0.875rem;
  background: rgba(255,143,0,.1);
  border: 1px solid rgba(255,143,0,.35);
  border-radius: 0.375rem;
  font-size: 0.8275rem;
}
.dirty-banner-icon { color: var(--ntop-orange, #FF8F00); font-size: 0.85rem; }
.dirty-banner-text { flex: 1; min-width: 0; color: var(--ntop-text-color, #111); font-weight: 500; }
.dirty-banner-actions { display: flex; gap: 0.4rem; flex-shrink: 0; }

/* Scrollable body */
.prefs-main-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.25rem 1.5rem 1rem;
  background: var(--bg-base, #f5f7fa);
  scrollbar-width: thin;
  scrollbar-color: var(--scrollbar-thumb, rgba(55,71,79,.38)) transparent;
}
.prefs-main-body::-webkit-scrollbar        { width: 4px; }
.prefs-main-body::-webkit-scrollbar-track  { background: transparent; }
.prefs-main-body::-webkit-scrollbar-thumb  { background: var(--scrollbar-thumb, rgba(55,71,79,.38)); border-radius: 2px; }

.prefs-group-label {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--ntop-muted-text-color, #6c757d);
  margin-bottom: 0.5rem;
  margin-top: 1.25rem;
}
.prefs-group-label:first-child { margin-top: 0; }

.prefs-card {
  border: 1px solid var(--border-color, #dee2e6);
  border-radius: 0.375rem;
  overflow: hidden;
  background: var(--bg-surface, #fff);
}

/* Transitions */
.banner-slide-enter-active,
.banner-slide-leave-active {
  transition: opacity 0.18s ease, transform 0.18s ease;
}
.banner-slide-enter-from,
.banner-slide-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}
</style>
