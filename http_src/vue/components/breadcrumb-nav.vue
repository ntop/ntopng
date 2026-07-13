<!--
  (C) 2026 - ntop.org
  Breadcrumb navigation component
  Props:
    - items: Array<{ id: String|Number, name: String }>
        Ordered list from root to current node. The last item is rendered as
        the current (non-clickable) page.
  Emits:
    - on_select(item): fired when a non-last crumb is clicked
-->
<template>
    <nav class="breadcrumb-nav d-flex align-items-center flex-wrap" aria-label="breadcrumb">
        <template v-for="(item, index) in items" :key="item.id ?? index">
            <span v-if="index > 0" class="breadcrumb-nav-sep">
                <i class="bi bi-chevron-right"></i>
            </span>
            <span v-if="index === items.length - 1" class="breadcrumb-nav-current">{{ item.name }}</span>
            <a v-else href="#" class="breadcrumb-nav-link" @click.prevent="emit('on_select', item)">{{ item.name }}</a>
        </template>
    </nav>
</template>

<script setup>
defineProps({
    items: {
        type: Array,
        default: () => [],
    },
});

const emit = defineEmits(["on_select"]);
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
