<!--
  (C) 2026 - ntop.org
  Generic sidebar navigation entry: icon + name + colored dot + right-aligned
  badge number (optionally formatted, e.g. as a speed/traffic value).
  Props:
    - id: String              — unique node id
    - name: String             — display label (already i18n-resolved by caller)
    - icon: String              — icon class, e.g. "bi bi-geo-alt-fill"
    - color: String             — CSS color for the leading status dot (optional)
    - depth: Number             — indentation level (nested tree rows)
    - selected: Boolean         — highlight state
    - hasChildren: Boolean      — show/hide the expand chevron
    - expanded: Boolean         — chevron rotation state
    - loading: Boolean          — show a small orange spinner instead of the chevron
                                  while this entry's children are being fetched
    - disabled: Boolean         — renders as a muted, non-interactive placeholder
                                  row (e.g. a synthetic "no data available" leaf)
    - badgeValue: Number|String — right badge raw value (optional)
    - badgeFormatter: String    — formatter-utils key, e.g. "speed", "bytes", "number" (optional)
    - badgeVariant: String      — dashboard-badge style variant passed through
  Emits:
    - on_click(id): row clicked (selection)
    - on_toggle(id): chevron clicked (expand/collapse)
-->
<template>
    <div class="sidebar-nav-item d-flex align-items-center gap-2"
        :class="{ 'sidebar-nav-item-selected': selected, 'sidebar-nav-item-disabled': disabled }"
        :style="{ paddingLeft: indentPx + 'px' }" @click="handleClick">
        <span v-if="loading" class="sidebar-nav-spinner flex-shrink-0" aria-hidden="true"></span>
        <button v-else type="button" class="sidebar-nav-chevron border-0 bg-transparent p-0"
            :class="{ invisible: !hasChildren }" @click.stop="handleToggle" :aria-label="_i18n('expand')">
            <i class="bi bi-chevron-right" :class="{ 'sidebar-nav-chevron-open': expanded }"></i>
        </button>

        <span v-if="color" class="sidebar-nav-dot flex-shrink-0" :style="{ background: color }"></span>

        <i v-if="icon" class="sidebar-nav-icon flex-shrink-0" :class="icon"></i>

        <span class="sidebar-nav-label flex-grow-1 text-truncate">{{ name }}</span>

        <span v-if="formattedBadge !== null" class="sidebar-nav-badge flex-shrink-0">{{ formattedBadge }}</span>
    </div>
</template>

<script setup>
import { computed } from "vue";
import formatterUtils from "../../utilities/formatter-utils";

const _i18n = (t) => i18n(t);

const props = defineProps({
    id: [String, Number],
    name: String,
    icon: String,
    color: String,
    depth: {
        type: Number,
        default: 0,
    },
    selected: Boolean,
    hasChildren: Boolean,
    expanded: Boolean,
    loading: Boolean,
    disabled: Boolean,
    badgeValue: [Number, String],
    badgeFormatter: String,
});

const emit = defineEmits(["on_click", "on_toggle"]);

const indentPx = computed(() => 8 + props.depth * 16);

const formattedBadge = computed(() => {
    if (props.badgeValue === null || props.badgeValue === undefined || props.badgeValue === "") {
        return null;
    }
    if (!props.badgeFormatter || props.badgeFormatter === "no_formatting") {
        return props.badgeValue;
    }
    const format = formatterUtils.getFormatter(props.badgeFormatter);
    return format(props.badgeValue);
});

function handleClick() {
    if (props.disabled) return;
    emit("on_click", props.id);
}

function handleToggle() {
    if (props.disabled) return;
    emit("on_toggle", props.id);
}
</script>

<style scoped>
.sidebar-nav-item {
    padding-top: 6px;
    padding-bottom: 6px;
    padding-right: 12px;
    border-radius: 6px;
    margin: 1px 6px;
    cursor: pointer;
    user-select: none;
    color: #c7ccd4;
    font-size: 0.8125rem;
    font-weight: 500;
    transition: background 0.12s ease, color 0.12s ease;
}

.sidebar-nav-item:hover:not(.sidebar-nav-item-selected) {
    background: rgba(255, 255, 255, 0.07);
}

.sidebar-nav-item-selected {
    background: #EA6A2A;
    color: #fff;
    font-weight: 600;
}

.sidebar-nav-item-disabled {
    cursor: default;
    color: #7c8494;
    font-style: italic;
    opacity: 0.7;
}

.sidebar-nav-item-disabled:hover {
    background: transparent;
}

.sidebar-nav-chevron {
    width: 16px;
    height: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    color: inherit;
}

.sidebar-nav-chevron i {
    font-size: 10px;
    transition: transform 0.15s ease;
}

.sidebar-nav-chevron-open {
    transform: rotate(90deg);
}

.sidebar-nav-spinner {
    width: 16px;
    height: 16px;
    display: block;
    border: 2px solid rgba(234, 106, 42, 0.25);
    border-top-color: #EA6A2A;
    border-radius: 50%;
    animation: sidebar-nav-spin 0.7s linear infinite;
}

@keyframes sidebar-nav-spin {
    to {
        transform: rotate(360deg);
    }
}

.sidebar-nav-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
}

.sidebar-nav-icon {
    font-size: 13px;
    width: 15px;
    text-align: center;
    color: var(--ntop-orange);
}

.sidebar-nav-item-selected .sidebar-nav-icon {
    color: inherit;
}

.sidebar-nav-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.sidebar-nav-badge {
    font-size: 11.5px;
    font-weight: 700;
    white-space: nowrap;
}
</style>
