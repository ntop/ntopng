<!--
  (C) 2013-26 - ntop.org
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
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Loading } from "./loading.vue";
import { default as TsChart } from "./ts-chart.vue";

const height_per_row = 62;

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
});

const emit = defineEmits(['chart-updated', 'update-requested']);

const isLoading   = ref(true);
const height      = ref(180);
const chartResult = ref(null);
const chartMeta   = ref(null);
let   generation  = 0;

/* cache top-N: only fetched once per mount (epoch-independent list) */
let cachedTopData = null;

/* top-N fetch */
async function fetchTopData() {
    if (cachedTopData !== null) return cachedTopData;

    const topUrl = `${http_prefix}${props.params.url}`;
    const query_params = {
        ...props.params.url_params,
        csrf:        props.csrf,
        ifid:        props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end:   props.epoch_end,
    };
    const url_params = ntopng_url_manager.obj_to_url_params(query_params);
    cachedTopData = await ntopng_utility.http_request(`${topUrl}?${url_params}`) || [];
    return cachedTopData;
}

/* build batch queries from top-N */

function buildQueries(topData) {
    const post = props.params?.post_params || {};
    const ts_requests_tpl = post.ts_requests || {};

    /* Find the first concrete ts_request template (not a $ANY$ key) */
    const tpl_key = Object.keys(ts_requests_tpl).find(k => !k.startsWith('$')) ||
                    Object.keys(ts_requests_tpl)[0];
    const tpl = ts_requests_tpl[tpl_key] || {};

    const schema = tpl.ts_schema || '';
    const queries = [];

    topData.forEach((el, i) => {
        let ts_schema = schema;
        let ts_query  = '';

        if (schema === 'top:flowdev_port:traffic') {
            ts_schema = 'flowdev_port:traffic';
            ts_query  = `ifid:${el.ifid},device:${el.exporter_ip},port:${el.interface_id}`;
        } else if (schema === 'top:asn:traffic') {
            ts_schema = 'asn:traffic';
            ts_query  = `ifid:${props.ifid},asn:${el.asn}`;
        } else {
            /* Generic: substitute known placeholders */
            ts_query = (tpl.ts_query || '')
                .replace(/\$IFID\$/g, props.ifid)
                .replace(/\$ASN\$/g, el.asn || '')
                .replace(/\$DEVICE\$/g, el.exporter_ip || '')
                .replace(/\$PORT\$/g, el.interface_id || '');
        }

        queries.push({
            id:        `${props.id}_top_${i}`,
            ts_schema,
            ts_query,
            ts_unify:  true,
            limit:     post.limit || 180,
        });
    });

    return queries;
}

async function fetchChart() {
    const gen = ++generation;

    if (!props.epoch_begin || !props.epoch_end) return;
    isLoading.value = true;
    emit('update-requested', {});

    const topData = await fetchTopData();
    if (gen !== generation) return;

    if (!topData || topData.length === 0) {
        chartResult.value = { series: [], metadata: {} };
        isLoading.value = false;
        return;
    }

    const queries = buildQueries(topData);
    if (queries.length === 0) { isLoading.value = false; return; }

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

    chartMeta.value = batchResp.meta || {};

    /* Merge all top-N results into one unified series (equivalent to ts_unify) */
    const entries = Object.values(batchResp.results || {});
    chartResult.value = mergeTopResults(entries);

    isLoading.value = false;
}

function mergeTopResults(entries) {
    if (entries.length === 0) return { series: [], metadata: {} };
    /* The backend handles ts_unify per-query in batch.lua -> ts_data.
     * Here we pick the first non-empty result as the unified series. */
    return entries.find(r => r.series && r.series.length > 0) || entries[0];
}

function onZoom(epoch) { emit('update-requested', epoch); }
function chartUpdatedCallback(options) { emit('chart-updated', options); }

onBeforeMount(() => {
    height.value = (props.max_height || 4) * height_per_row;
});

onMounted(() => {
    fetchChart();
});

watch(
    () => [props.epoch_begin, props.epoch_end, props.filters],
    () => {
        cachedTopData = null; /* re-fetch top-N on time range change */
        fetchChart();
    },
    { deep: true }
);

defineExpose({ refreshChart: fetchChart });
</script>
