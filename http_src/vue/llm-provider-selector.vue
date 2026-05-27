<!-- (C) 2013-26 - ntop.org -->
<template>
  <div v-if="loading" class="d-flex align-items-center gap-2 small ps-muted">
    <span class="spinner-border spinner-border-sm" role="status"></span>
    {{ _i18n('llm.loading_providers') }}
  </div>
  <div v-else-if="providers.length === 0" class="text-warning small d-flex align-items-center gap-1">
    <i class="fas fa-exclamation-triangle"></i>
    {{ _i18n('llm.no_providers') }}
  </div>
  <div v-else class="ps-wrapper flex-shrink-0" ref="wrapperRef">
    <div class="provider-pill" :class="{ open: dropdownOpen, disabled: disabled }"
      @click.stop="!disabled && (dropdownOpen = !dropdownOpen)">
      <span class="provider-pill-icon" v-html="getProviderIconHtml(selected_provider)"></span>
      <span class="provider-pill-info">
        <span class="provider-pill-name">{{ _i18n('prefs.' + selected_provider) }}</span>
        <span class="provider-pill-model">{{ selectedInfo?.model }}</span>
      </span>
      <i class="fas fa-chevron-down provider-pill-chevron"></i>
    </div>
    <div v-if="dropdownOpen" class="provider-dropdown">
      <div v-for="p in providers" :key="p.provider" class="provider-option"
        :class="{ active: p.provider === selected_provider }"
        @click.stop="onSelect(p.provider)">
        <span class="provider-option-icon" v-html="getProviderIconHtml(p.provider)"></span>
        <span class="provider-option-info">
          <span class="provider-option-name">{{ _i18n('prefs.' + p.provider) }}</span>
          <span class="provider-option-model">{{ p.model }}</span>
        </span>
        <i v-if="p.provider === selected_provider" class="fas fa-check provider-option-check"></i>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from "vue";
import { getProviderIconHtml } from "./composables/useLlmChat.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  providers:         { type: Array,   default: () => [] },
  selected_provider: { type: String,  default: "" },
  loading:           { type: Boolean, default: false },
  disabled:          { type: Boolean, default: false },
});

const emit = defineEmits(['select']);

const dropdownOpen = ref(false);
const wrapperRef   = ref(null);

const selectedInfo = computed(() => props.providers.find(p => p.provider === props.selected_provider));

function onSelect(provider) {
  emit('select', provider);
  dropdownOpen.value = false;
}

function onDocumentClick(e) {
  if (wrapperRef.value && !wrapperRef.value.contains(e.target)) {
    dropdownOpen.value = false;
  }
}

onMounted(()        => document.addEventListener('click', onDocumentClick));
onBeforeUnmount(()  => document.removeEventListener('click', onDocumentClick));
</script>

<style scoped>
.ps-muted { color: var(--ntop-muted-text-color); }

.ps-wrapper { position: relative; }

.provider-pill {
  display: flex; align-items: center; gap: 0.45rem;
  background: var(--bg-surface);
  border: 1px solid var(--border-color);
  border-radius: 10px; padding: 0.28rem 0.65rem 0.28rem 0.5rem;
  cursor: pointer; transition: border-color 0.15s, box-shadow 0.15s;
}
.provider-pill:hover:not(.disabled), .provider-pill.open:not(.disabled) {
  border-color: var(--ntop-orange);
  box-shadow: 0 0 0 3px rgba(255,143,0,0.18);
}
.provider-pill.disabled { opacity: 0.6; cursor: not-allowed; }

.provider-pill-icon {
  width: 22px; height: 22px; border-radius: 6px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(255,143,0,0.12); color: var(--ntop-orange); font-size: 0.82rem;
}
.provider-pill-info  { display: flex; flex-direction: column; line-height: 1.2; }
.provider-pill-name  { font-size: 0.72rem; font-weight: 600; color: var(--ntop-text-color); }
.provider-pill-model { font-size: 0.65rem; color: var(--ntop-muted-text-color); }
.provider-pill-chevron { font-size: 0.6rem; color: var(--ntop-muted-text-color); transition: transform 0.15s; }
.provider-pill.open .provider-pill-chevron { transform: rotate(180deg); }

.provider-dropdown {
  position: absolute; top: calc(100% + 6px); left: 0; min-width: 220px;
  background: var(--bg-elevated);
  border: 1px solid var(--border-color);
  border-radius: 12px; box-shadow: 0 6px 20px rgba(0,0,0,0.16);
  z-index: 1050; padding: 4px; overflow: hidden;
  animation: psDropdownFadeIn 0.12s ease-out;
}
@keyframes psDropdownFadeIn {
  from { opacity: 0; transform: translateY(-4px); }
  to   { opacity: 1; transform: translateY(0); }
}

.provider-option {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.5rem 0.75rem; border-radius: 8px; cursor: pointer; transition: background 0.12s;
}
.provider-option:hover  { background: var(--bg-sunken); }
.provider-option.active { background: rgba(255,143,0,0.10); }

.provider-option-icon {
  width: 22px; height: 22px; border-radius: 6px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(255,143,0,0.10); color: var(--ntop-orange); font-size: 0.82rem;
}
.provider-option-info  { display: flex; flex-direction: column; flex-grow: 1; line-height: 1.2; }
.provider-option-name  { font-size: 0.75rem; font-weight: 600; color: var(--ntop-text-color); }
.provider-option-model { font-size: 0.65rem; color: var(--ntop-muted-text-color); }
.provider-option-check { font-size: 0.7rem; color: var(--ntop-orange); }
</style>
