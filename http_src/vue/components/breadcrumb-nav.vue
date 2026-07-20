<!--
  (C) 2026 - ntop.org
  Breadcrumb navigation component
  Props:
    - items: Array<{ id: String|Number, name: String, tooltip?: String }>
        Ordered list from root to current node. The last item is rendered as
        the current (non-clickable) page. `tooltip`, when present, is shown as
        a Bootstrap 5 tooltip (top placement) on hover — e.g. the crumb's kind
        ("Site", "Network", "Exporter", "Interface").
  Emits:
    - on_select(item): fired when a non-last crumb is clicked
-->
<template>
    <nav ref="navRef" class="breadcrumb-nav d-flex align-items-center flex-wrap" aria-label="breadcrumb">
        <template v-for="(item, index) in items" :key="item.id ?? index">
            <span v-if="index > 0" class="breadcrumb-nav-sep">
                <i class="bi bi-chevron-right"></i>
            </span>
            <span v-if="index === items.length - 1" class="breadcrumb-nav-current"
                :data-bs-toggle="item.tooltip ? 'tooltip' : null" data-bs-placement="top" :title="item.tooltip">
                {{ item.name }}
            </span>
            <a v-else href="#" class="breadcrumb-nav-link" @click.prevent="emit('on_select', item)"
                :data-bs-toggle="item.tooltip ? 'tooltip' : null" data-bs-placement="top" :title="item.tooltip">
                {{ item.name }}
            </a>
        </template>
    </nav>
</template>

<script setup>
import { ref, watch, nextTick, onBeforeUnmount } from "vue";

const props = defineProps({
    items: {
        type: Array,
        default: () => [],
    },
});

const emit = defineEmits(["on_select"]);

const navRef = ref(null);
let tooltipInstances = [];

function disposeTooltips() {
    tooltipInstances.forEach((t) => t.dispose());
    tooltipInstances = [];
}

async function createTooltips() {
    await nextTick();
    if (!window.bootstrap?.Tooltip || !navRef.value) return;

    navRef.value.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => {
        tooltipInstances.push(new window.bootstrap.Tooltip(el, { trigger: "hover" }));
    });
}

watch(() => props.items, () => {
    disposeTooltips();
    createTooltips();
}, { immediate: true, flush: "pre" });

onBeforeUnmount(() => {
    disposeTooltips();
});
</script>

<style scoped>
.breadcrumb-nav {
    font-size: 13px;
    color: var(--ntop-muted-text-color);
    row-gap: 4px;
    min-width: 0;
}

.breadcrumb-nav-link,
.breadcrumb-nav-current {
    max-width: 220px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.breadcrumb-nav-sep {
    font-size: 9px;
    margin: 0 8px;
    color: var(--ntop-muted-text-color);
}

.breadcrumb-nav-link {
    color: var(--ntop-orange);
    text-decoration: underline;
    text-decoration-color: currentColor;
    text-underline-offset: 2px;
    transition: color 0.12s ease;
}

.breadcrumb-nav-link:hover {
    color: var(--ntop-orange-dark, var(--ntop-orange));
}

.breadcrumb-nav-current {
    color: var(--ntop-text-color);
    font-weight: 600;
}
</style>
