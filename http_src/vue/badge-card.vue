<!--
  (C) 2026 - ntop.org
-->

<template>
    <!-- static mode: no REST fetch, value is passed directly by the parent. -->
    <div v-if="props.simple" class="badge-card-kpi-card">
        <div class="badge-card-kpi-header">
            <div v-if="props.icon" class="badge-card-kpi-icon" :style="{ background: props.activeColor || props.color }">
                <i :class="props.icon"></i>
            </div>
            <span class="badge-card-kpi-label">{{ props.label }}</span>
        </div>
        <h4 class="badge-card-kpi-value mb-0">{{ props.value }}</h4>
        <p v-if="props.sub" class="badge-card-kpi-sub mb-0 small">{{ props.sub }}</p>
    </div>

    <!-- REST mode. Icon + label header, big value below, sub below that. -->
    <template v-else>
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <div class="badge-card-kpi-card">
            <a :href="link_url" class="badge-card-kpi-link">
                <div class="badge-card-kpi-header">
                    <div v-if="icon" class="badge-card-kpi-icon" :style="{ background: props.activeColor || icon_color }">
                        <i :class="icon"></i>
                    </div>
                    <span class="badge-card-kpi-label">{{ name }}</span>
                </div>
                <h4 class="badge-card-kpi-value mb-0">
                    <span :title="counter_title">{{ counter }}</span><span
                        v-if="secondary_counter" :title="secondary_counter_title"
                        class="badge-card-kpi-value-secondary"> / {{ secondary_counter }}</span>
                </h4>
                <p v-if="extra_text" class="badge-card-kpi-sub mb-0 small">{{ extra_text }}</p>
            </a>
        </div>
    </template>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";
import formatterUtils from "../utilities/formatter-utils";
import Loading from "./loading.vue";

const _i18n = (t) => i18n(t);

const counter = ref('')
const secondary_counter = ref('')
const counter_title = ref('')
const secondary_counter_title = ref('')
const name = ref('')
const icon = ref('')
const link_url = ref('#')
const isLoading = ref(true);
const firstLoading = ref(true);
const extra_text = ref('');
const icon_color = ref('var(--ntop-orange, #FF8F00)');

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    set_component_attr: Function, /* Callback to set component attributes (e.g. Box active color) */
    filters: Object,
    hideLoading: Boolean, /* If false, no Loading animation is shown */
    showOnlyFirstLoading: Boolean, /* If true, shows only the first loading of the component, not the updates */
    style: String,       /* Unused */
    csrf: String,        /* Unused */
    /* Simple/static mode props: bypass the REST-driven flow entirely */
    simple: Boolean,      /* If true, render a static KPI card from the props below */
    icon: String,         /* Icon class (simple mode) */
    color: String,        /* Icon background color (simple mode) */
    label: String,        /* Card label (simple mode) */
    value: [String, Number], /* Card value (simple mode) */
    sub: String,          /* Card secondary line (simple mode) */
    /* Overrides the icon square color regardless of mode — used by callers to signal
       state (e.g. warning/danger when a limit is reached) without tinting the whole tile. */
    activeColor: String,
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    if (!props.simple) refresh_component();
}, { flush: 'pre', deep: true });

/* Watch - static_value mode: parent recomputed the value locally, no REST call needed */
watch(() => props.params?.static_value, () => {
    if (!props.simple && props.params?.static_value !== undefined) {
        refresh_component();
    }
});

onBeforeMount(() => {
    if (!props.simple) init();
});

onMounted(() => {
    firstLoading.value = false; // No more first loading
});

function init() {
    if (props.params.i18n_name) {
        name.value = _i18n(props.params.i18n_name);
    }

    if (props.params.i18n_extra_text) {
        extra_text.value = _i18n(props.params.i18n_extra_text);
    }

    if (props.params.icon) {
        icon.value = props.params.icon;
    }

    /* Icon square color */
    if (props.params.color) {
        icon_color.value = props.params.color;
    }

    refresh_component();
}

async function refresh_component() {
    isLoading.value = (props?.showOnlyFirstLoading === true) ? (firstLoading.value && true) : true;
    /* Refresh component */

    /* Static mode: the parent already has the value and no REST call is needed. */
    if (props.params.static_value !== undefined) {
        const formatter = props.params.counter_formatter === "no_formatting"
            ? (v) => v
            : formatterUtils.getFormatter(props.params.counter_formatter || "number");
        counter.value = formatter(props.params.static_value);
        isLoading.value = false;
        return;
    }

    if (props.params.url) {

        const url_params = {
            ifid: props.ifid,
            epoch_begin: props.epoch_begin,
            epoch_end: props.epoch_end,
            ...props.params.url_params,
            ...props.filters
        }

        let data = await props.get_component_data(`${http_prefix}${props.params.url}`, url_params, undefined, props.epoch_begin);
        if (props.params.badge_index) {
            data = data[props.params.badge_index]
        }
        /* TODO handle dot-separated path for non-flat json */
        let counter_value = data[props.params.counter_path];
        if (props.params.i18n_counter_title) {
            counter_title.value = _i18n(props.params.i18n_counter_title);
        }
        if (props.params.i18n_counter_title_path) {
            name.value = _i18n(data[props.params.i18n_counter_title_path]);
        }
        if (props.params.extra_text_path && data[props.params.extra_text_path] != null) {
            extra_text.value = data[props.params.extra_text_path];
        }

        let has_secondary_counter = false;
        let secondary_counter_value = '';
        if (props.params.secondary_counter_path) {
            has_secondary_counter = true;
            secondary_counter_value = data[props.params.secondary_counter_path];
            if (props.params.i18n_secondary_counter_title) {
                secondary_counter_title.value = _i18n(props.params.i18n_secondary_counter_title);
            }
        }

        if (props.params.counter_formatter == "no_formatting") {
            counter.value = counter_value;
            if (has_secondary_counter) {
                secondary_counter.value = secondary_counter_value;
            }
        } else {
            let counter_formatter = props.params.counter_formatter;
            if (!counter_formatter) {
                counter_formatter = "number";
            }

            let formatCounter = formatterUtils.getFormatter(counter_formatter);
            counter.value = formatCounter(counter_value);
            if (has_secondary_counter) {
                secondary_counter.value = formatCounter(secondary_counter_value);
            }

            if (counter_value) {
                props.set_component_attr('active', true);
            }

            if (props.params.link) {
                const link_url_params = {
                    ifid: props.ifid,
                    epoch_begin: props.epoch_begin,
                    epoch_end: props.epoch_end,
                    ...props.params.link.url_params
                }

                const link_query_params = ntopng_url_manager.obj_to_url_params(link_url_params);
                link_url.value = `${http_prefix}${props.params.link.url}?${link_query_params}`;
            }
            if (props.params.link_path && data[props.params.link_path]) {
                link_url.value = `${http_prefix}${data[props.params.link_path]}`;
            }
        }
    }
    isLoading.value = false // Always false
}
</script>

<style scoped>
.badge-card-kpi-card {
    height: 100%;
    min-width: 0;
    box-sizing: border-box;
    background: var(--bg-surface, #FFFFFF);
    border: 1px solid var(--border-color, #DEE2E6);
    border-radius: 14px;
    box-shadow: 0 1px 2px rgba(15, 23, 42, 0.05), 0 10px 26px -14px rgba(15, 23, 42, 0.12);
    padding: 14px 18px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 6px;
    container-type: inline-size;
}

:root[data-theme='dark'] .badge-card-kpi-card {
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.5), 0 10px 26px -14px rgba(0, 0, 0, 0.6);
}

.badge-card-kpi-link {
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 6px;
    height: 100%;
    color: inherit;
    text-decoration: none;
}

.badge-card-kpi-header {
    display: flex;
    align-items: center;
    gap: 10px;
    min-width: 0;
}

.badge-card-kpi-icon {
    width: 32px;
    height: 32px;
    border-radius: 9px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #fff;
    font-size: 14px;
    flex-shrink: 0;
}

.badge-card-kpi-label {
    display: block;
    color: var(--ntop-text-color);
    font-size: 0.9375rem;
    font-weight: 800;
    letter-spacing: -0.01em;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.badge-card-kpi-value {
    display: flex;
    align-items: baseline;
    gap: 6px;
    color: var(--ntop-text-color);
    font-size: 1.375rem;
    font-weight: 700;
    line-height: 1;
    letter-spacing: -0.01em;
    min-width: 0;
    padding-left: calc(32px + 10px);
}

.badge-card-kpi-value > span:first-child {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.badge-card-kpi-value-secondary {
    font-size: 0.9375rem;
    font-weight: 600;
    color: var(--ntop-muted-text-color);
}

.badge-card-kpi-sub {
    color: var(--ntop-muted-text-color);
    font-size: 0.75rem;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    padding-left: calc(32px + 10px);
}
</style>
