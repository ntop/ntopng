<!--
  (C) 2013-26 - ntop.org
-->
<template>
    <div>
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <PieChart ref="chart" :chart="chart_config" :hideLoading="true" @chart-updated="chartUpdated"
            @update-requested="chartUpdatesRequested" />
    </div>
</template>

<script setup>
import { ref, computed, watch } from "vue";
import PieChart from "./charts/pie-chart.vue";
import Loading from "./loading.vue";

const chart = ref(null);
const isLoading = ref(true);
const firstLoading = ref(true);

const props = defineProps({
    id: String,
    i18n_title: String,
    ifid: String,
    epoch_begin: Number,
    epoch_end: Number,
    max_width: Number,
    max_height: Number,
    params: Object,
    get_component_data: Function,
    filters: Object,
    hideLoading: Boolean, /* If false, no Loading animation is shown */
    showOnlyFirstLoading: Boolean, /* If true, shows only the first loading of the component, not the updates */
});

/* *************************************************** */

const get_url_params = () => {
    const raw = {
        ifid: props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        ...props.params.url_params,
        ...props.filters,
    };
    return Object.fromEntries(Object.entries(raw).filter(([_, v]) => v != null));
};

/* *************************************************** */

// Override the fetch function so the dashboard loading lifecycle works
const custom_fetch = async (url, url_params) => {
    const res = await props.get_component_data(url, url_params, undefined, props.epoch_begin);
    const raw = res?.rsp ?? res;
    if (!Array.isArray(raw)) return raw;
    const lk = props.params.label_key;
    const vk = props.params.value_key;
    if (!lk || !vk) return raw;
    return raw.map(item => ({ label: item[lk], value: item[vk], url: item.url }));
};

/* *************************************************** */

const chart_config = computed(() => ({
    name: props.id,
    update_url: `${http_prefix}${props.params.url}`,
    unit: props?.params?.unit,
    label: props?.params?.label,
    url_params: get_url_params(),
    custom_fetch,
}));

/* *************************************************** */

const chartUpdated = () => {
    isLoading.value = false
    firstLoading.value = false;
}

/* *************************************************** */

const chartUpdatesRequested = () => {
    isLoading.value = (props?.showOnlyFirstLoading === true) ? (firstLoading.value && true) : true;
}

/* *************************************************** */

watch(() => [props.epoch_begin, props.epoch_end, props.filters], () => {
    chart.value?.update();
}, { flush: 'post', deep: true });
</script>
