<!--
  (C) 2026 - ntop.org
  Reusable tab-selector component.
  Props:
    - tabs: Array<{ id: string, label_i18n: string, count?: number }>
        label_i18n  — i18n key for the tab label
        count       — optional numeric badge shown next to the label
    - active_tab_id: string (optional, defaults to first tab id)
  Emits:
    - on_click(tab): fired when the user clicks a tab that is not already active
-->
<template>
  <div class="d-inline-flex align-items-center navbar-tabs-container p-1 gap-1" role="group">
    <button
      v-for="tab in tabs"
      :key="tab.id"
      type="button"
      class="tab-btn border-0 rounded px-3 py-1"
      :class="{ 'tab-btn-active': activeId === tab.id }"
      @click="handleClick(tab)"
    >
      {{ _i18n(tab.label_i18n) }}
      <span v-if="tab.count != null" class="tab-count">{{ tab.count }}</span>
    </button>
  </div>
</template>

<script setup>
import { ref, watch } from "vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  tabs: {
    type: Array,
    required: true,
  },
  active_tab_id: {
    type: String,
    default: null,
  },
});

const emit = defineEmits(["on_click"]);

const activeId = ref(
  props.active_tab_id ?? (props.tabs.length > 0 ? props.tabs[0].id : null)
);

watch(
  () => props.active_tab_id,
  (newVal) => {
    activeId.value = newVal;
  }
);

function handleClick(tab) {
  if (activeId.value !== tab.id) {
    activeId.value = tab.id;
    emit("on_click", tab);
  }
}
</script>

<style scoped>
.navbar-tabs-container {
  background: var(--navbar-tab-container-bg);
  border-radius: 8px;
}

.tab-btn {
  appearance: none;
  border: none;
  outline: none;
  background: transparent;
  color: var(--navbar-tab-btn);
  font-size: 0.8125rem;
  font-weight: 500;
  letter-spacing: 0.01em;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
  white-space: nowrap;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.tab-btn:focus,
.tab-btn:focus-visible {
  outline: none;
  box-shadow: none;
}

.tab-btn:hover:not(.tab-btn-active) {
  background: var(--navbar-tab-hover-bg);
  color: var(--navbar-tab-hover-color);
}

.tab-btn-active {
  background: var(--navbar-tab-active-bg);
  color: var(--navbar-tab-active-color);
  box-shadow: 0 1px 4px var(--navbar-tab-active-shadow);
}

.tab-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  padding: 1px 5px;
  border-radius: 10px;
  font-size: 0.7rem;
  font-weight: 600;
  line-height: 1.4;
  background: var(--navbar-tab-count-bg);
  color: inherit;
}

.tab-btn-active .tab-count {
  background: var(--navbar-tab-count-active-bg);
}
</style>
