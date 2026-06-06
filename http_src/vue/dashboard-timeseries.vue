<!--
  (C) 2013-26 - ntop.org
  Uses batch.lua — zero consts.lua / ts_multi.lua calls.
  Fetches data then drives TimeseriesChart via get_custom_chart_options + retrieveOptionsAndDraw.
-->
<template>
    <div>
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <TimeseriesChart
            ref="chartRef"
            :id="id"
            :get_custom_chart_options="getChartOptions"
            :disable_fixed_height="true"
            @zoom="onZoom"
            @chart-updated="chartUpdatedCallback"
            @update-requested="onUpdateRequested"
        />
    </div>
</template>

<script setup>
import { ref, watch, onMounted } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as Loading } from "./loading.vue";
import { default as TimeseriesChart } from "./timeseries-chart.vue";

const props = defineProps({
    id:          { type: String },
    i18n_title:  { type: String },
    ifid:        { type: String },
    epoch_begin: { type: Number },
    epoch_end:   { type: Number },
    max_width:   { type: Number },
    max_height:  { type: Number },
    params:      { type: Object },
    get_component_data: { type: Function },
    csrf:        { type: String },
    filters:     { type: Object },
    hideLoading: { type: Boolean },
    showOnlyFirstLoading: { type: Boolean },
});

const emit = defineEmits(['chart-updated', 'update-requested']);

const height_per_row = 62;

const isLoading = ref(true);
const firstLoad = ref(true);
const chartRef  = ref(null);
let   generation = 0;

/* Holds the fetched result; getChartOptions returns it so TimeseriesChart can format it */
let pendingOptions = null;

async function resolveRequests() {
    const raw = props.params?.post_params?.ts_requests;
    if (!raw) return [];

    const resolved = [];
    const ifid = props.ifid;

    for (const key in raw) {
        const tpl = raw[key];

        if (key === '$ANY_IFID$') {
            const ifid_list = await ntopng_utility.http_request(
                `${http_prefix}/lua/rest/v2/get/ntopng/interfaces.lua`
            ) || [];
            ifid_list.forEach(iface => {
                resolved.push(substituteIfid({ ...tpl }, iface.ifid));
            });
        } else if (key === '$ANY_EXPORTER$') {
            const list = await ntopng_utility.http_request(
                `${http_prefix}/lua/pro/rest/v2/get/flowdevices/list.lua?ifid=${ifid}&gui=true`
            ) || [];
            list.forEach(exp => {
                const r = substituteIfid({ ...tpl }, exp.ifid);
                resolved.push(substituteStr(r, '$EXPORTER$', exp.probe_ip));
            });
        } else if (key === '$ANY_NETWORK$') {
            const list = await ntopng_utility.http_request(
                `${http_prefix}/lua/rest/v2/get/network/networks.lua?ifid=${ifid}`
            ) || [];
            list.forEach(net => {
                const r = substituteIfid({ ...tpl }, ifid);
                resolved.push(substituteStr(r, '$NETWORK$', net.id));
            });
        } else {
            resolved.push(substituteIfid({ ...tpl }, ifid));
        }
    }

    return resolved;
}

function substituteIfid(obj, ifid) {
    const out = {};
    for (const k in obj) {
        out[k] = typeof obj[k] === 'string' ? obj[k].replace(/\$IFID\$/g, ifid) : obj[k];
    }
    return out;
}

function substituteStr(obj, placeholder, value) {
    const out = {};
    for (const k in obj) {
        out[k] = typeof obj[k] === 'string' ? obj[k].replace(new RegExp('\\' + placeholder.replace('$','\\$'), 'g'), value) : obj[k];
    }
    return out;
}

function mergeResults(results) {
    const entries = Object.values(results);
    if (entries.length === 0) return { series: [], metadata: {} };
    return entries.find(r => r.series && r.series.length > 0) || entries[0];
}

/* Returned to TimeseriesChart as get_custom_chart_options; called by retrieveOptionsAndDraw */
async function getChartOptions(_url) {
    return pendingOptions;
}

async function fetchChart() {
    const gen = ++generation;

    if (!props.epoch_begin || !props.epoch_end) return;

    isLoading.value = firstLoad.value || !props.showOnlyFirstLoading;

    const requests = await resolveRequests();
    if (gen !== generation) return;

    if (requests.length === 0) {
        isLoading.value = false;
        return;
    }

    const queries = requests.map((r, i) => ({
        id:        `${props.id}_${i}`,
        ts_schema: r.ts_schema,
        ts_query:  r.ts_query,
        tskey:     r.tskey,
        ts_unify:  r.ts_unify,
        limit:     props.params?.post_params?.limit || 180,
        zoom:      props.params?.post_params?.zoom,
    }));

    const batch_url = `${http_prefix}/lua/rest/v2/get/timeseries/batch.lua`;
    const post_body = {
        csrf:        props.csrf,
        ifid:        props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end:   props.epoch_end,
        queries,
    };

    let batchResp;
    if (props.get_component_data) {
        batchResp = await props.get_component_data(
            batch_url,
            { ifid: props.ifid, epoch_begin: props.epoch_begin, epoch_end: props.epoch_end },
            post_body,
        );
    } else {
        batchResp = await ntopng_utility.http_post_request(batch_url, post_body);
    }

    if (gen !== generation) return;
    if (!batchResp) { isLoading.value = false; return; }

    const resultKeys = Object.keys(batchResp.results || {});
    let result;
    if (resultKeys.length === 0) {
        result = { series: [], metadata: {} };
    } else if (resultKeys.length === 1) {
        result = batchResp.results[resultKeys[0]];
    } else {
        result = mergeResults(batchResp.results);
    }

    /* Attach meta so timeseries-chart picks up date_format/timezone */
    result._meta   = batchResp.meta || {};
    result._height = (props.max_height || 4) * height_per_row;
    pendingOptions = result;

    /* Trigger (re)draw now that data is ready */
    if (chartRef.value) {
        chartRef.value.retrieveOptionsAndDraw('');
    }

    isLoading.value = false;
    firstLoad.value = false;
}

function onUpdateRequested(epoch) {
    emit('update-requested', epoch);
}

function onZoom(epoch) {
    emit('update-requested', epoch);
}

function chartUpdatedCallback(options) {
    emit('chart-updated', options);
}

onMounted(() => {
    fetchChart();
});

watch(
    () => [props.epoch_begin, props.epoch_end, props.filters, props.ifid],
    () => fetchChart(),
    { deep: true }
);
</script>
