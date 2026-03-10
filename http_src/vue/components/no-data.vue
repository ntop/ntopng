<!--
  (C) 2026 - ntop.org
-->

<template>
    <div v-if="show" class="no-data-message">
        {{ message || _i18n(i18nKey) }}
    </div>
</template>

<script setup>
const _i18n = (t) => i18n(t);

defineProps({
    show: { type: Boolean, required: true },
    i18nKey: { type: String, default: 'flows_page.no_data' },
    message: { type: String, default: null }
});
</script>

<style scoped>
.no-data-message {
    margin: 20px;
    padding: 15px;
    border-radius: 4px;
    color: var(--ntop-text-color);
    background-color: var(--loading-bg);
    border: 1px solid var(--loading-spinner-border);
}
</style>