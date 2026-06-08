<!--
  (C) 2013-26 - ntop.org

  Dashboard timeseries widget.
  Fetches one or more timeseries via a single POST to batch.lua and renders them
  through TimeseriesChart (timeseries-chart.vue).

  Data flow:
    1. resolveRequests() expands wildcard keys ($ANY_IFID$, $ANY_EXPORTER$,
       $ANY_NETWORK$) in params.post_params.ts_requests into concrete query
       objects, one per interface / exporter / network.  Each resolved request
       carries a _label field used later as a human-readable series prefix.
    2. fetchChart() assembles the batch POST body and dispatches it either via
       the optional get_component_data callback (pages that need custom query
       building, e.g. ASN names) or directly to batch.lua.
    3. If the callback injected a _queryLabels map into the response, those
       labels override the ones built in step 1 (covers query IDs the callback
       invented itself).
    4. mergeResults() combines all per-source results into one result object
       that TimeseriesChart can render as a multi-series chart:
         - series names become  "<source label> - <metric label>"
         - invert_direction (set by batch.lua from handler metadata) negates
           received-bytes series so they plot below the x-axis, exactly as
           convertBatchResult does for single-source results.
    5. pendingOptions is stored and returned by getChartOptions(); TimeseriesChart
       calls that function through its get_custom_chart_options prop.
-->
<template>
    <div>
        <!-- Optional spinner shown while data is loading -->
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>

        <!--
          TimeseriesChart renders the dygraph chart.
          It never fetches data itself; it calls getChartOptions() which returns
          the pre-fetched pendingOptions.
        -->
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
    /** Unique chart ID; used as the query-ID prefix and for localStorage keys. */
    id:          { type: String },
    /** Optional i18n key for the chart title (rendered by the parent). */
    i18n_title:  { type: String },
    /** Interface ID injected into $IFID$ placeholders. */
    ifid:        { type: String },
    /** Unix epoch start of the time window. */
    epoch_begin: { type: Number },
    /** Unix epoch end of the time window. */
    epoch_end:   { type: Number },
    /** Dashboard grid width (unused here, available to parent layouts). */
    max_width:   { type: Number },
    /** Dashboard grid height; controls chart pixel height (rows × height_per_row). */
    max_height:  { type: Number },
    /**
     * Component configuration object.  Must include:
     *   post_params.ts_requests  — template map of query definitions.
     *   post_params.limit        — optional max data points (default 180).
     *   post_params.zoom         — optional zoom level string.
     * Wildcard keys in ts_requests are expanded by resolveRequests():
     *   $ANY_IFID$      → one query per active interface
     *   $ANY_EXPORTER$  → one query per flow exporter
     *   $ANY_NETWORK$   → one query per known network
     *   <any other key> → single query with $IFID$ substituted
     */
    params:      { type: Object },
    /**
     * Optional async callback invoked instead of the default batch POST.
     * Signature: (url, queryParams, postBody) => Promise<batchResponse>
     * The callback may replace postBody.queries with its own set and attach
     * _queryLabels: { [qid]: humanLabel } to the returned response so that
     * mergeResults() can label the series it built.
     */
    get_component_data: { type: Function },
    /** CSRF token forwarded to batch.lua. */
    csrf:        { type: String },
    /** Extra filter object; changes trigger a chart refresh via the watcher. */
    filters:     { type: Object },
    /** When true the loading spinner is suppressed entirely. */
    hideLoading: { type: Boolean },
    showOnlyFirstLoading: { type: Boolean },
});

const emit = defineEmits([
    'chart-updated',    // forwarded from TimeseriesChart after each draw
    'update-requested', // forwarded from TimeseriesChart or zoom callback
]);

/** Pixel height contributed by each dashboard grid row. */
const height_per_row = 62;

const isLoading = ref(true);
const firstLoad = ref(true);
const chartRef  = ref(null);

/**
 * Monotonically increasing counter.  Incremented at the start of each
 * fetchChart() call.  Any async step that finds gen !== generation knows it
 * has been superseded by a newer call and must bail out.
 */
let generation = 0;

/**
 * Holds the last successfully fetched (and possibly merged) batch result.
 * TimeseriesChart reads it through the getChartOptions() callback.
 */
let pendingOptions = null;

/**
 * Expands the wildcard keys in params.post_params.ts_requests into a flat
 * array of concrete request objects.
 *
 * For each wildcard a separate HTTP call is made to fetch the relevant list
 * (interfaces, exporters, networks) and one request is produced per element.
 * Each request receives a _label property with a human-readable identifier
 * that is later used as the series-name prefix in the chart legend.
 *
 * Non-wildcard keys are passed through with $IFID$ substituted.
 *
 * @returns {Promise<Array>} Flat array of resolved request objects.
 */
async function resolveRequests() {
    const raw = props.params?.post_params?.ts_requests;
    if (!raw) return [];

    const resolved = [];
    const ifid = props.ifid;

    for (const key in raw) {
        const tpl = raw[key];

        if (key === '$ANY_IFID$') {
            /* One query per active interface. */
            const ifid_list = await ntopng_utility.http_request(
                `${http_prefix}/lua/rest/v2/get/ntopng/interfaces.lua`
            ) || [];
            ifid_list.forEach(iface => {
                const r = substituteIfid({ ...tpl }, iface.ifid);
                /* Prefer the human-readable interface name as the chart label. */
                r._label = iface.name || iface.ifname || `ifid:${iface.ifid}`;
                resolved.push(r);
            });

        } else if (key === '$ANY_EXPORTER$') {
            /* One query per flow exporter (probe IP). */
            const list = await ntopng_utility.http_request(
                `${http_prefix}/lua/pro/rest/v2/get/flowdevices/list.lua?ifid=${ifid}&gui=true`
            ) || [];
            list.forEach(exp => {
                const r = substituteStr(substituteIfid({ ...tpl }, exp.ifid), '$EXPORTER$', exp.probe_ip);
                r._label = exp.name || exp.probe_ip || `exp:${exp.ifid}`;
                resolved.push(r);
            });

        } else if (key === '$ANY_NETWORK$') {
            /* One query per known local network. */
            const list = await ntopng_utility.http_request(
                `${http_prefix}/lua/rest/v2/get/network/networks.lua?ifid=${ifid}`
            ) || [];
            list.forEach(net => {
                const r = substituteStr(substituteIfid({ ...tpl }, ifid), '$NETWORK$', net.id);
                r._label = net.name || net.label || `net:${net.id}`;
                resolved.push(r);
            });

        } else {
            /* single query entry — only substitute $IFID$, no label. */
            resolved.push(substituteIfid({ ...tpl }, ifid));
        }
    }

    return resolved;
}

/**
 * Returns a shallow copy of obj with every string value that contains $IFID$
 * replaced by the given ifid string.
 *
 * @param {Object} obj   - Template object whose string values may contain $IFID$.
 * @param {string} ifid  - Interface ID to substitute.
 * @returns {Object} New object with substitutions applied.
 */
function substituteIfid(obj, ifid) {
    const out = {};
    for (const k in obj) {
        out[k] = typeof obj[k] === 'string' ? obj[k].replace(/\$IFID\$/g, ifid) : obj[k];
    }
    return out;
}

/**
 * Returns a shallow copy of obj with every occurrence of placeholder replaced
 * by value in all string properties.
 *
 * @param {Object} obj         - Template object.
 * @param {string} placeholder - Literal placeholder string (e.g. '$EXPORTER$').
 * @param {string} value       - Replacement value.
 * @returns {Object} New object with substitutions applied.
 */
function substituteStr(obj, placeholder, value) {
    const out = {};
    for (const k in obj) {
        out[k] = typeof obj[k] === 'string'
            ? obj[k].replace(new RegExp('\\' + placeholder.replace('$', '\\$'), 'g'), value)
            : obj[k];
    }
    return out;
}

/**
 * Merges multiple per-source batch results into a single result object
 * suitable for TimeseriesChart / convertBatchResult.
 *
 * When there is only one non-empty result it is returned as-is so that
 * convertBatchResult can apply its own rxtx negation and colour logic.
 *
 * For multiple sources every series from every result is combined into a
 * single series array.  Series names become "<source label> - <metric label>"
 * (e.g. "enp1s0 - Sent", "enp1s0 - Received", "eth0 - Sent" …).
 * Received/download series are negated in place using the invert_direction
 * flag that batch.lua attached from the handler's timeseries definition,
 * mirroring the single-source behaviour of convertBatchResult.
 *
 * measure_unit is taken from the first non-empty result; all queries for the
 * same schema share the same unit.
 *
 * @param {Object} results     - batchResp.results map  { [qid]: resultEntry }.
 * @param {Object} queryLabels - Map { [qid]: humanLabel } built by fetchChart.
 * @returns {Object} Merged result ready for TimeseriesChart.
 */
function mergeResults(results, queryLabels) {
    const entries = Object.values(results);
    if (entries.length === 0) return { series: [], metadata: {} };

    const nonEmpty = entries.filter(e => e.series?.length > 0);

    /* Single source: return as-is so convertBatchResult handles rxtx negation. */
    if (nonEmpty.length <= 1) return nonEmpty[0] || entries[0];

    const mergedSeries = [];
    let baseMetadata   = {};
    /* All queries share the same schema → same unit; take from first result. */
    const measure_unit = nonEmpty[0].measure_unit || "number";

    for (const qid of Object.keys(results)) {
        const entry = results[qid];
        if (!entry?.series?.length) continue;

        /* Use the richest metadata block available (last non-empty wins). */
        if (Object.keys(entry.metadata || {}).length > 0) baseMetadata = entry.metadata;

        /*
         * Label priority:
         *   1. queryLabels[qid]  — human label from resolveRequests or _queryLabels
         *   2. entry.metadata.label — label returned by the backend (if any)
         *   3. qid               — raw query ID as final fallback
         */
        const prefix = (queryLabels || {})[qid] || entry.metadata?.label || qid;

        entry.series.forEach(s => {
            /* batch.lua sets s.label from the handler's timeseries definition
               (e.g. i18n("graphs.metric_labels.sent") → "Sent").
               Fall back to s.name (if pre-set) then to the raw s.id. */
            const seriesLabel = s.label || s.name || s.id;

            /*
             * batch.lua sets s.invert_direction = true for received/download
             * series (from the handler's invert_direction flag, e.g. bytes_rcvd).
             * Negate those values so they plot below zero, matching
             * convertBatchResult's behaviour for single-source rxtx charts.
             */
            const data = s.invert_direction && Array.isArray(s.data)
                ? s.data.map(v => (v == null || v !== v) ? v : -v)
                : s.data;

            mergedSeries.push({ ...s, name: `${prefix} - ${seriesLabel}`, data });
        });
    }

    return { ...nonEmpty[0], measure_unit, series: mergedSeries, metadata: baseMetadata };
}

/**
 * Passed to TimeseriesChart as get_custom_chart_options.
 * TimeseriesChart calls this (via retrieveOptionsAndDraw) whenever it needs
 * to draw or redraw.  Returns the last result stored by fetchChart().
 *
 * @param {string} _url - Ignored; TimeseriesChart passes a URL but we use
 *                        the pre-fetched pendingOptions instead.
 * @returns {Promise<Object|null>} The pending batch result.
 */
async function getChartOptions(_url) {
    return pendingOptions;
}

/**
 * Core data-fetch function.  Called on mount and whenever the watched props
 * (epoch_begin, epoch_end, filters, ifid) change.
 *
 * Steps:
 *   1. Increment generation; bail if superseded at each async boundary.
 *   2. Call resolveRequests() to expand wildcard ts_requests keys.
 *   3. Build queries array and queryLabels map (labels are NOT sent to backend).
 *   4. POST to batch.lua (or delegate to get_component_data).
 *   5. Merge _queryLabels injected by the callback (if any) into queryLabels.
 *   6. Call mergeResults() for multi-source responses.
 *   7. Store result in pendingOptions and trigger TimeseriesChart redraw.
 */
async function fetchChart() {
    const gen = ++generation;

    if (!props.epoch_begin || !props.epoch_end) return;

    /* Show spinner: always on first load; on refresh only when not suppressed. */
    isLoading.value = firstLoad.value || !props.showOnlyFirstLoading;

    /* Expand wildcard keys into concrete request objects. */
    const requests = await resolveRequests();
    if (gen !== generation) return; /* superseded */

    if (requests.length === 0) {
        isLoading.value = false;
        return;
    }

    /*
     * Build the queries array sent to batch.lua.
     * queryLabels is a parallel map { qid → humanLabel } kept client-side only;
     * it never leaves the browser.
     */
    const queryLabels = {};
    const queries = requests.map((r, i) => {
        const qid = `${props.id}_${i}`;
        if (r._label) queryLabels[qid] = r._label;
        return {
            id:        qid,
            ts_schema: r.ts_schema,
            ts_query:  r.ts_query,
            tskey:     r.tskey,
            ts_unify:  r.ts_unify,
            limit:     props.params?.post_params?.limit || 180,
            zoom:      props.params?.post_params?.zoom,
        };
    });

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
        /*
         * Delegate to the parent-provided callback.  The callback may:
         *   - replace post_body.queries with its own set (e.g. top-ASN queries)
         *   - attach _queryLabels to the response so mergeResults() can label
         *     those query IDs (e.g. ASN names fetched alongside the top list)
         */
        batchResp = await props.get_component_data(
            batch_url,
            { ifid: props.ifid, epoch_begin: props.epoch_begin, epoch_end: props.epoch_end },
            post_body,
        );
    } else {
        batchResp = await ntopng_utility.http_post_request(batch_url, post_body);
    }

    if (gen !== generation) return; /* superseded */
    if (!batchResp) { isLoading.value = false; return; }

    /*
     * Merge labels injected by get_component_data (_queryLabels) with the
     * labels built from resolveRequests (queryLabels).  Callback-provided
     * labels take precedence because the callback knows the real entity names.
     */
    const effectiveLabels = batchResp._queryLabels
        ? { ...queryLabels, ...batchResp._queryLabels }
        : queryLabels;

    /* Select or merge results based on how many queries returned data. */
    const resultKeys = Object.keys(batchResp.results || {});
    let result;
    if (resultKeys.length === 0) {
        result = { series: [], metadata: {} };
    } else if (resultKeys.length === 1) {
        /* Single source: pass through as-is; convertBatchResult handles it. */
        result = batchResp.results[resultKeys[0]];
    } else {
        /* Multiple sources: merge series with per-source labels. */
        result = mergeResults(batchResp.results, effectiveLabels);
    }

    /* Attach batch metadata so TimeseriesChart picks up date_format/timezone. */
    result._meta   = batchResp.meta || {};
    /* Pixel height derived from the dashboard grid row count. */
    result._height = (props.max_height || 4) * height_per_row;
    pendingOptions = result;

    /* Signal TimeseriesChart to (re)draw using the new pendingOptions. */
    if (chartRef.value) {
        chartRef.value.retrieveOptionsAndDraw('');
    }

    isLoading.value = false;
    firstLoad.value = false;
}

/** Forward zoom events from TimeseriesChart to the parent as update-requested. */
function onUpdateRequested(epoch) {
    emit('update-requested', epoch);
}

/** Forward zoom callbacks from the dygraph zoom handler to the parent. */
function onZoom(epoch) {
    emit('update-requested', epoch);
}

/** Forward chart-updated events (fired after each dygraph draw) to the parent. */
function chartUpdatedCallback(options) {
    emit('chart-updated', options);
}

onMounted(() => {
    fetchChart();
});

/*
 * Re-fetch whenever the time window, active filters, or selected interface
 * changes.  deep:true is needed because filters is an object.
 */
watch(
    () => [props.epoch_begin, props.epoch_end, props.filters, props.ifid],
    () => fetchChart(),
    { deep: true }
);
</script>
