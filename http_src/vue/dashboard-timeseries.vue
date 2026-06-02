<!--
  (C) 2013-26 - ntop.org
  Uses batch.lua — zero consts.lua / ts_multi.lua calls.
  One POST per refresh, data passed straight to ts-chart.vue for rendering.
-->
<template>
    <div>
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <TsChart
            :id="id"
            :result="chartResult"
            :meta="chartMeta"
            :height="height"
            @zoom="onZoom"
            @chart-updated="chartUpdatedCallback"
        />
    </div>
</template>

<script setup>
import { ref, watch, onMounted, onBeforeMount, computed } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as Loading } from "./loading.vue";
import { default as TsChart } from "./ts-chart.vue";

const height_per_row = 62; /* px per grid row */

const props = defineProps({
    id:          { type: String },
    i18n_title:  { type: String },
    ifid:        { type: String },
    epoch_begin: { type: Number },
    epoch_end:   { type: Number },
    max_width:   { type: Number },
    max_height:  { type: Number },
    params:      { type: Object },   /* dashboard JSON component params */
    get_component_data: { type: Function },
    csrf:        { type: String },
    filters:     { type: Object },
    hideLoading: { type: Boolean },
    showOnlyFirstLoading: { type: Boolean },
});

const emit = defineEmits(['chart-updated', 'update-requested']);

const isLoading   = ref(true);
const firstLoad   = ref(true);
const height      = ref(180);
const chartResult = ref(null);
const chartMeta   = ref(null);
let   generation  = 0;   /* stale-request guard */

/**
 * Resolve $IFID$ / $ANY_IFID$ placeholders.
 * Returns an array of concrete ts_request objects.
 */
async function resolveRequests() {
    const raw = props.params?.post_params?.ts_requests;
    if (!raw) return [];

    const resolved = [];
    const ifid = props.ifid;

    for (const key in raw) {
        const tpl = raw[key];

        if (key === '$ANY_IFID$') {
            /* Fan-out: one request per interface */
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
            /* Regular entry — just substitute $IFID$ */
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

async function fetchChart() {
    const gen = ++generation;

    if (!props.epoch_begin || !props.epoch_end) return;

    isLoading.value = firstLoad.value || !props.showOnlyFirstLoading;
    emit('update-requested', { firstLoad: firstLoad.value });

    const requests = await resolveRequests();
    if (gen !== generation) return;  /* superseded */

    if (requests.length === 0) {
        isLoading.value = false;
        return;
    }

    /* Build batch queries: one entry per resolved ts_request */
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
        /* Use dashboard callback so report snapshots work */
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

    chartMeta.value = batchResp.meta || {};
    if (batchResp.meta?.date_format) ntopng_utility.set_cached_date_format(batchResp.meta.date_format);

    /* If multiple queries (ANY expansion), merge series into first result */
    const resultKeys = Object.keys(batchResp.results || {});
    if (resultKeys.length === 0) {
        chartResult.value = { series: [], metadata: {}, error: null };
    } else if (resultKeys.length === 1) {
        chartResult.value = batchResp.results[resultKeys[0]];
    } else {
        /* Merge all results into the first one (ts_unify behaviour) */
        chartResult.value = mergeResults(batchResp.results);
    }

    isLoading.value = false;
    firstLoad.value = false;
}

function mergeResults(results) {
    const entries = Object.values(results);
    if (entries.length === 0) return { series: [], metadata: {} };
    /* Use the first non-empty result as base */
    const base = entries.find(r => r.series && r.series.length > 0) || entries[0];
    return base;
}

function onZoom(epoch) {
    emit('update-requested', epoch);
}

function chartUpdatedCallback(options) {
    emit('chart-updated', options);
}

onBeforeMount(() => {
    height.value = (props.max_height || 4) * height_per_row;
});

onMounted(() => {
    fetchChart();
});

watch(
    () => [props.epoch_begin, props.epoch_end, props.filters, props.ifid],
    () => fetchChart(),
    { deep: true }
);
</script>
