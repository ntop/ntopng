<!--
  (C) 2013-26 - ntop.org

  Dashboard top-N timeseries widget.
  Shows the top-N entities (ASNs, flow-device ports, networks, …) each as a
  separate series in one shared dygraph chart.

  Data flow:
    1. fetchTopData() requests the top-N list from params.url (e.g. get_top_asn.lua).
       The list is cached for the lifetime of the current epoch window so that
       refreshes caused by zoom do not re-fetch the same list.
    2. buildQueries(topData) derives one batch.lua query per entity, picking the
       correct ts_schema / ts_query based on the schema template.  Each query
       carries ts_unify:true so that backend aggregates multiple matching
       timeseries into a single per-entity series.  A parallel queryLabels map
       maps each query ID to the entity's human-readable display name.
    3. The queries are POSTed to batch.lua in one shot.
    4. mergeTopResults(results, queryLabels) combines all per-entity results into
       one result object:
         - When an entity yields a single unified series → the series name is
           just the entity label (e.g. "AS12345 My ISP").
         - When an entity yields multiple series → names become
           "<entity label> - <metric label>" (e.g. "AS12345 - Sent").
         - received/download series are negated (invert_direction from batch.lua)
           so they plot below zero, matching the rxtx visual convention.
    5. pendingOptions is stored; getChartOptions() returns it so TimeseriesChart
       can draw without fetching again.

  On epoch/filter/ifid change:
    - cachedTopData is cleared so the next fetchChart() re-fetches the top list.
    - fetchChart() is re-invoked by the watcher.

  defineExpose({ refreshChart }) lets parents trigger a manual refresh.
-->
<template>
    <div>
        <!-- Optional spinner; suppressed when hideLoading prop is set. -->
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>

        <TimeseriesChart
            ref="chartRef"
            :id="id"
            :get_custom_chart_options="getChartOptions"
            :disable_fixed_height="true"
            @zoom="onZoom"
            @chart-updated="chartUpdatedCallback"
        />
    </div>
</template>

<script setup>
import { ref, watch, onMounted } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
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
    /**
     * Component configuration object.  Expected shape:
     *   url              — path to the top-N REST endpoint
     *                      (e.g. /lua/rest/v2/get/asn/top_stats.lua)
     *   url_params       — extra query parameters forwarded to that endpoint
     *   post_params
     *     ts_requests    — map with a single template entry whose ts_schema
     *                      drives per-entity query construction in buildQueries()
     *     limit          — max data points per series (default 180)
     */
    params:      { type: Object },
    /**
     * Optional async callback that replaces the default batch POST.
     * Signature: (url, queryParams, postBody) => Promise<batchResponse>
     * May attach _queryLabels to the returned response (same pattern as
     * dashboard-timeseries.vue) though buildQueries() already covers labels.
     */
    get_component_data: { type: Function },
    csrf:        { type: String },
    filters:     { type: Object },
    hideLoading: { type: Boolean },
});

const emit = defineEmits([
    'chart-updated',    // forwarded from TimeseriesChart after each dygraph draw
    'update-requested', // emitted on fetch start and forwarded on zoom
]);

/** Pixel height contributed by each dashboard grid row. */
const height_per_row = 62;

const isLoading = ref(true);
/** Template ref to the TimeseriesChart child so we can call retrieveOptionsAndDraw. */
const chartRef  = ref(null);

/**
 * Monotonically increasing counter.  Incremented at the start of each
 * fetchChart() call.  Any async step that finds gen !== generation knows it
 * has been superseded by a newer call and must bail out without updating state.
 */
let generation = 0;

/**
 * Top-N entity list cached for the current epoch window.  Cleared whenever
 * epoch_begin / epoch_end / filters change so the next refresh re-fetches.
 * Null means "not yet fetched or invalidated".
 */
let cachedTopData = null;

/**
 * Holds the last successfully built (and merged) batch result.
 * TimeseriesChart reads it through getChartOptions().
 */
let pendingOptions = null;

/**
 * Fetches the top-N entity list from params.url.
 * Returns the cached result immediately if available; otherwise makes an
 * HTTP GET and caches the response for subsequent calls within the same
 * epoch window.
 *
 * @returns {Promise<Array>} Array of top-entity objects (ASNs, ports, …).
 */
async function fetchTopData() {
    debugger;
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

/**
 * Extracts the most descriptive available label from a top-entity element.
 * Fields are tried in decreasing specificity:
 *   1. el.label       — explicit label provided by the endpoint
 *   2. el.name        — generic name field
 *   3. el.description — human-readable description
 *   4. exporter_ip:interface_id — composite for flow-device ports
 *   5. ASN <number>   — fallback for ASN entries
 *   6. el.exporter_ip — bare IP for exporters without a port
 *   7. String(el.id)  — numeric ID as last resort
 *
 * @param {Object} el - One element from the top-N list.
 * @returns {string}  Human-readable label.
 */
function entityLabel(el) {
    return el.label || el.name || el.description ||
        (el.exporter_ip && el.interface_id != null ? `${el.exporter_ip}:${el.interface_id}` : null) ||
        (el.asn != null ? `ASN ${el.asn}` : null) ||
        el.exporter_ip || String(el.id ?? '');
}

/**
 * Derives one batch.lua query per entity from the top-N list.
 *
 * Schema-specific handling:
 *   top:flowdev_port:traffic  → strips "top:" prefix, builds device+port query
 *   top:asn:traffic           → strips "top:" prefix, builds ifid+asn query
 *   anything else             → generic template substitution of
 *                               $IFID$, $ASN$, $DEVICE$, $PORT$ placeholders
 *
 * ts_unify:true is set on every query so that batch.lua aggregates multiple
 * matching timeseries for the same entity into one unified series per query.
 *
 * @param {Array} topData - Top-N entity list from fetchTopData().
 * @returns {{ queries: Array, queryLabels: Object }}
 *   queries     — array of query objects for the batch POST body
 *   queryLabels — map { qid → humanLabel } used by mergeTopResults()
 */
function buildQueries(topData) {
    const post = props.params?.post_params || {};
    const ts_requests_tpl = post.ts_requests || {};

    /* Pick the first non-wildcard template entry, or the very first key. */
    const tpl_key = Object.keys(ts_requests_tpl).find(k => !k.startsWith('$')) ||
                    Object.keys(ts_requests_tpl)[0];
    const tpl = ts_requests_tpl[tpl_key] || {};

    const schema   = tpl.ts_schema || '';
    const queries     = [];
    const queryLabels = {};

    topData.forEach((el, i) => {
        let ts_schema = schema;
        let ts_query  = '';

        if (schema === 'top:flowdev_port:traffic') {
            /* Flow-device port traffic: one query per exporter IP + interface ID. */
            ts_schema = 'flowdev_port:traffic';
            ts_query  = `ifid:${el.ifid},device:${el.exporter_ip},port:${el.interface_id}`;

        } else if (schema === 'top:asn:traffic') {
            /* ASN traffic: one query per ASN number on the current interface. */
            ts_schema = 'asn:traffic';
            ts_query  = `ifid:${props.ifid},asn:${el.asn}`;

        } else {
            /* Generic: substitute well-known placeholders in the template query string. */
            ts_query = (tpl.ts_query || '')
                .replace(/\$IFID\$/g,   props.ifid)
                .replace(/\$ASN\$/g,    el.asn          || '')
                .replace(/\$DEVICE\$/g, el.exporter_ip  || '')
                .replace(/\$PORT\$/g,   el.interface_id || '');
        }

        /* Stable query ID: <componentId>_top_<index> */
        const qid = `${props.id}_top_${i}`;
        queryLabels[qid] = entityLabel(el) || qid;

        queries.push({
            id:       qid,
            ts_schema,
            ts_query,
            ts_unify: true,         /* aggregate per-entity series server-side */
            limit:    post.limit || 180,
        });
    });

    return { queries, queryLabels };
}

/**
 * Merges per-entity batch results into a single result object for TimeseriesChart.
 *
 * Because ts_unify:true was set, each entity normally yields exactly one series.
 * In that case the series name is just the entity label for a clean legend:
 *   "AS12345 My ISP"
 *
 * If an entity unexpectedly yields multiple series (e.g. split sent/rcvd),
 * the name becomes "<entity label> - <metric label>":
 *   "AS12345 My ISP - Sent"
 *
 * received/download series are negated using the invert_direction flag that
 * batch.lua attached from the handler's timeseries definition (same convention
 * as convertBatchResult for single-source charts).
 *
 * measure_unit is taken from the first non-empty result; all queries share
 * the same schema → same unit.
 *
 * @param {Object} results     - batchResp.results map { [qid]: resultEntry }.
 * @param {Object} queryLabels - Map { [qid]: humanLabel } from buildQueries().
 * @returns {Object} Merged result ready for TimeseriesChart.
 */
function mergeTopResults(results, queryLabels) {
    const entries = Object.values(results);
    if (entries.length === 0) return { series: [], metadata: {} };

    const nonEmpty = entries.filter(e => e.series?.length > 0);

    /* Single entity with data: return as-is. */
    if (nonEmpty.length <= 1) return nonEmpty[0] || entries[0];

    const mergedSeries = [];
    let baseMetadata   = {};
    /* All queries share the same schema → same unit; take from first result. */
    const measure_unit = nonEmpty[0].measure_unit || "number";

    for (const qid of Object.keys(results)) {
        const entry = results[qid];
        if (!entry?.series?.length) continue;

        /* Keep the richest metadata block available. */
        if (Object.keys(entry.metadata || {}).length > 0) baseMetadata = entry.metadata;

        /*
         * Label priority:
         *   1. queryLabels[qid] — entity name from buildQueries()
         *   2. qid              — raw query ID as fallback
         */
        const prefix = (queryLabels || {})[qid] || qid;

        entry.series.forEach(s => {
            /*
             * batch.lua sets s.label from the handler's timeseries definition.
             * s.name may be pre-set by a caller; s.id is the raw metric ID.
             */
            const seriesLabel = s.label || s.name || s.id || '';

            /*
             * When ts_unify produced exactly one series per entity, use only
             * the entity label (no metric suffix) → cleaner legend.
             * When there are multiple series per entity, qualify with metric.
             */
            const displayName = entry.series.length > 1
                ? `${prefix} - ${seriesLabel}`
                : prefix;

            /*
             * batch.lua sets s.invert_direction=true for received/download
             * series (from handler metadata, e.g. bytes_rcvd).
             * Negate those values to plot below zero (rxtx convention).
             */
            const data = s.invert_direction && Array.isArray(s.data)
                ? s.data.map(v => (v == null || v !== v) ? v : -v)
                : s.data;

            mergedSeries.push({ ...s, name: displayName, data });
        });
    }

    return { ...nonEmpty[0], measure_unit, series: mergedSeries, metadata: baseMetadata };
}

/**
 * Passed to TimeseriesChart as get_custom_chart_options.
 * TimeseriesChart calls this whenever it needs to draw or redraw.
 * Returns the pending result pre-fetched and merged by fetchChart().
 *
 * @returns {Promise<Object|null>} The last merged batch result.
 */
async function getChartOptions(_url) {
    return pendingOptions;
}

/**
 * Core fetch function.  Invoked on mount and on epoch/filters/ifid changes.
 *
 * Steps:
 *   1. Increment generation; bail at each async boundary if superseded.
 *   2. Fetch (or use cached) top-N entity list.
 *   3. Build per-entity queries and queryLabels with buildQueries().
 *   4. POST to batch.lua (or delegate to get_component_data callback).
 *   5. Merge results with mergeTopResults().
 *   6. Store in pendingOptions and trigger TimeseriesChart redraw.
 */
async function fetchChart() {
    const gen = ++generation;

    if (!props.epoch_begin || !props.epoch_end) return;
    isLoading.value = true;
    emit('update-requested', {});

    /* Fetch or reuse top-N list. */
    const topData = await fetchTopData();
    if (gen !== generation) return; /* superseded */

    if (!topData || topData.length === 0) {
        pendingOptions = { series: [], metadata: {} };
        isLoading.value = false;
        return;
    }

    const { queries, queryLabels } = buildQueries(topData);
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
        /*
         * Parent-provided callback (e.g. a page that needs custom labels or
         * fetching logic).  post_body is passed so the callback can amend it.
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

    /* Select or merge results. */
    const resultKeys = Object.keys(batchResp.results || {});
    let result;
    if (resultKeys.length === 0) {
        result = { series: [], metadata: {} };
    } else if (resultKeys.length === 1) {
        /* Single entity: pass through as-is. */
        result = batchResp.results[resultKeys[0]];
    } else {
        /* Multiple entities: merge into a multi-series result. */
        result = mergeTopResults(batchResp.results, queryLabels);
    }

    /* Attach batch metadata (date_format, timezone) for TimeseriesChart. */
    result._meta   = batchResp.meta || {};
    /* Pixel height from dashboard grid row count. */
    result._height = (props.max_height || 4) * height_per_row;
    pendingOptions = result;

    /* Trigger TimeseriesChart redraw. */
    if (chartRef.value) {
        chartRef.value.retrieveOptionsAndDraw('');
    }

    isLoading.value = false;
}

/** Forward zoom callbacks to the parent as update-requested. */
function onZoom(epoch) { emit('update-requested', epoch); }

/** Forward chart-updated events (fired after each dygraph draw) to the parent. */
function chartUpdatedCallback(options) { emit('chart-updated', options); }

onMounted(() => {
    fetchChart();
});

/*
 * Re-fetch on time window, filter, or interface changes.
 * Clear cachedTopData so the new epoch window gets a fresh top-N list.
 * deep:true is needed because filters is an object.
 */
watch(
    () => [props.epoch_begin, props.epoch_end, props.filters],
    () => {
        cachedTopData = null;
        fetchChart();
    },
    { deep: true }
);

/* Allow parent components (e.g. dashboard grids) to trigger a manual refresh. */
defineExpose({ refreshChart: fetchChart });
</script>
