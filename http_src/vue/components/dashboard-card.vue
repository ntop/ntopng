<!--
  (C) 2026 - ntop.org
  Generic card container used to host any component or chart inside the
  dashboard grid
  Props:
    - title: String        — i18n-resolved card title (optional)
    - icon: String          — icon class shown next to the title (optional)
    - noPadding: Boolean     — set true when the slotted content manages its own padding (e.g. charts)
  Slots:
    - header: overrides the default title/icon header entirely
    - default: card body content (any component or chart)
    - footer: optional footer content
-->
<template>
    <div class="dashboard-card">
        <div v-if="$slots.header || title" class="dashboard-card-header d-flex align-items-center justify-content-between">
            <slot name="header">
                <span class="dashboard-card-title d-flex align-items-center gap-2">
                    <i v-if="icon" :class="icon"></i>
                    {{ title }}
                </span>
            </slot>
        </div>
        <div class="dashboard-card-body" :class="{ 'p-0': noPadding }">
            <slot></slot>
        </div>
        <div v-if="$slots.footer" class="dashboard-card-footer">
            <slot name="footer"></slot>
        </div>
    </div>
</template>

<script setup>
defineProps({
    title: String,
    icon: String,
    noPadding: Boolean,
});
</script>

<style scoped>
.dashboard-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    overflow: hidden;
    height: 100%;
    display: flex;
    flex-direction: column;
}

.dashboard-card-header {
    padding: 14px 18px;
    border-bottom: 1px solid var(--border-subtle);
}

.dashboard-card-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--ntop-text-color);
}

.dashboard-card-body {
    padding: 16px 18px;
    flex: 1 1 auto;
    min-height: 0;
    color: var(--ntop-text-color);
}

.dashboard-card-footer {
    padding: 10px 18px;
    border-top: 1px solid var(--border-subtle);
}
</style>
