<!--
  (C) 2013-22 - ntop.org
-->
<!-- :get_params_url_request="get_url_params" -->

<template>
    <div>
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <TimeseriesChart ref="chart" :id="id" :chart_type="chart_type" :base_url_request="base_url"
            :get_custom_chart_options="get_chart_options" :register_on_status_change="false"
            :disable_fixed_height="true" @chart-updated="chartUpdatedCallback"
            @update-requested="updateRequestedCallback">
        </TimeseriesChart>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import metricsManager from "../utilities/metrics-manager.js";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import timeseriesUtils from "../utilities/timeseries-utils.js";
import Loading from "./loading.vue";

/* *************************************************** */
/* Constants and reactive variables */
/* *************************************************** */

const height_per_row = 62 /* px */  // Base height per row of the component
const chart_type = ref(ntopChartApex.typeChart.TS_LINE);  // Chart type (line chart)
const chart = ref(null);  // Reference to the child TimeseriesChart component
const timeseries_groups = ref(null);  // Timeseries groups to display
const group_option_mode = timeseriesUtils.getGroupOptionMode('1_chart_x_yaxis');  // Grouping mode for chart options
const height = ref(null);  // Calculated height of the component
const ts_request = ref([]);  // Timeseries requests to be processed
const source_def = {};
let refresh_generation = 0;  // Incremented on each refresh; lets async chains self-cancel when stale
const isLoading = ref(true);
const firstLoading = ref(true);

const emit = defineEmits(['chart-updated', 'update-requested']);  // Events emitted to parent component

/* *************************************************** */
/* Component props */
/* *************************************************** */

const props = defineProps({
    id: String,          /* Unique component ID */
    i18n_title: String,  /* Title (i18n) for internationalization */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin (Unix timestamp) */
    epoch_end: Number,   /* Time interval end (Unix timestamp) */
    max_width: Number,   /* Component Width (4, 8, 12) - grid system */
    max_height: Number,  /* Component Height (4, 8, 12) - grid system */
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data from REST API */
    csrf: String,        /* CSRF token for security */
    filters: Object,     /* Additional filters for data query */
    hideLoading: Boolean, /* If false, no Loading animation is shown */
    showOnlyFirstLoading: Boolean, /* If true, shows only the first loading of the component, not the updates */
});

/* *************************************************** */
/* Computed properties */
/* *************************************************** */

/* Returns the base URL of the REST API */
const base_url = computed(() => {
    return `${http_prefix}${props.params.url}`;
});

/* *************************************************** */
/* Callback methods */
/* *************************************************** */

/* Callback triggered when chart is updated */
const chartUpdatedCallback = (options) => {
    emit("chart-updated", options)
    isLoading.value = false // Always false
}

/* *************************************************** */

/* Callback triggered when update is requested */
const updateRequestedCallback = (options) => {
    isLoading.value = (props?.showOnlyFirstLoading === true) ? (firstLoading.value && true) : true;
    emit("update-requested", options)
}

/* *************************************************** */

const formatUniqueKey = (requestInfo) => {
    return `${requestInfo?.ts_schema}-${requestInfo?.ts_query}`
}

/* *************************************************** */
/* Parameter substitution functions */
/* *************************************************** */

/* Substitutes $IFID$ placeholder with the actual interface ID in all parameters */
function substitute_ifid(params_to_format, current_ifid) {
    let new_formatted_params = {};
    for (const param in (params_to_format)) {
        if (params_to_format[param].includes('$IFID$')) {
            /* Contains $IFID$, substitute with the interface id */
            new_formatted_params[param] = params_to_format[param].replace('$IFID$', current_ifid);
        } else {
            /* Does NOT contain $IFID$, add the plain parameter */
            new_formatted_params[param] = params_to_format[param];
        }
    }

    return new_formatted_params;
}

/* *************************************************** */

/* Substitutes $EXPORTER$ placeholder with the actual exporter IP in all parameters */
function substitute_exporter(params_to_format, current_exporter) {
    let new_formatted_params = {};
    for (const param in (params_to_format)) {
        if (params_to_format[param].includes('$EXPORTER$')) {
            /* Contains $EXPORTER$, substitute with the exporter IP */
            new_formatted_params[param] = params_to_format[param].replace('$EXPORTER$', current_exporter);
        } else {
            /* Does NOT contain $EXPORTER$, add the plain parameter */
            new_formatted_params[param] = params_to_format[param];
        }
    }

    return new_formatted_params;
}

/* *************************************************** */

/* Substitutes $NETWORK$ placeholder with the actual network ID in all parameters */
function substitute_network(params_to_format, current_network) {
    let new_formatted_params = {};
    for (const param in (params_to_format)) {
        if (params_to_format[param].includes('$NETWORK$')) {
            /* Contains $NETWORK$, substitute with the network ID */
            new_formatted_params[param] = params_to_format[param].replace('$NETWORK$', current_network);
        } else {
            /* Does NOT contain $NETWORK$, add the plain parameter */
            new_formatted_params[param] = params_to_format[param];
        }
    }

    return new_formatted_params;
}

/* *************************************************** */
/* ANY parameter resolution functions */
/* *************************************************** */

/* Resolves $IFID$ ANY parameters by fetching all interfaces and creating requests for each */
async function format_ifids(params_to_format) {
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }
    const ifid_url = "lua/rest/v2/get/ntopng/interfaces.lua"
    const ifid_list = await ntopng_utility.http_request(`${http_prefix}/${ifid_url}`) || [];
    ifid_list.forEach((iface) => {
        const new_formatted_params = substitute_ifid(params_to_format, iface.ifid);
        const source_def_key = formatUniqueKey(new_formatted_params)
        source_def[source_def_key] = [iface.ifid]
        ts_request.value.push(new_formatted_params);
    });
}

/* *************************************************** */

/* Resolves $EXPORTER$ ANY parameters by fetching all flow exporters and creating requests for each */
async function format_exporters(params_to_format) {
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }
    const exporters_url = "lua/pro/rest/v2/get/flowdevices/list.lua"
    const exporters_list = await ntopng_utility.http_request(`${http_prefix}/${exporters_url}?ifid=${props.ifid}&gui=true`) || [];
    if (exporters_list) {
        exporters_list.forEach((exporter) => {
            if (exporter) {
                let new_formatted_params = substitute_exporter(params_to_format, exporter.probe_ip);
                new_formatted_params = substitute_ifid(new_formatted_params, exporter.ifid);
                const source_def_key = formatUniqueKey(new_formatted_params)
                source_def[source_def_key] = [exporter.ifid, exporter.probe_ip]
                ts_request.value.push(new_formatted_params);
            }
        });
    }
}

/* *************************************************** */

/* Resolves $NETWORK$ ANY parameters by fetching all networks and creating requests for each */
async function format_networks(params_to_format) {
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }
    const networks_url = "lua/rest/v2/get/network/networks.lua"
    const networks_list = await ntopng_utility.http_request(`${http_prefix}/${networks_url}?ifid=${props.ifid}`) || [];
    if (networks_list) {
        networks_list.forEach((network) => {
            if (network) {
                let new_formatted_params = substitute_network(params_to_format, network.id);
                new_formatted_params = substitute_ifid(new_formatted_params, props.ifid);
                const source_def_key = formatUniqueKey(new_formatted_params)
                source_def[source_def_key] = [props.ifid, network.id]
                ts_request.value.push(new_formatted_params);
            }
        });
    }
}

/* *************************************************** */

/* Main function to resolve all ANY parameters in the configuration */
async function resolve_any_params() {
    /* Clear the Array */
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }
    ts_request.value = [];
    /* Handle possible ANY parameters found in the post_params */
    const params = props.params.post_params?.ts_requests;
    for (const any_param in (params || {})) {
        switch (any_param) {
            case '$ANY_IFID$':
                await format_ifids(params[any_param]);
                break;
            case '$ANY_EXPORTER$':
                await format_exporters(params[any_param]);
                break;
            case '$ANY_NETWORK$':
                await format_networks(params[any_param]);
                break;
            default:
                // Handle regular parameters (no ANY substitution needed)
                let new_formatted_params = substitute_ifid(params[any_param], props.ifid);
                const source_def_key = formatUniqueKey(new_formatted_params)
                source_def[source_def_key] = [props.ifid]
                ts_request.value.push(new_formatted_params);
                break;
        }
    }
}

/* *************************************************** */
/* Timeseries group retrieval functions */
/* *************************************************** */

/* Retrieves timeseries groups from a metric schema and source definition */
async function get_timeseries_groups_from_metric(metric_schema, source_def) {
    const source_type = metricsManager.get_source_type_from_id(props.params?.source_type);
    const source_array = await metricsManager.get_source_array_from_value_array(http_prefix, source_type, source_def);
    const metric = await metricsManager.get_metric_from_schema(http_prefix, source_type, source_array, metric_schema);
    const ts_group = metricsManager.get_ts_group(source_type, source_array, metric, { past: false });
    return ts_group;
}

/* *************************************************** */

/* Retrieves basic information for all timeseries requests */
async function retrieve_basic_info() {
    /* Return the timeseries groups, info found in the JSON */
    if (!timeseries_groups.value) {
        /* Order requests only the first time */
        order_ts_request();
        const promises = ts_request.value
            .filter((value) => source_def[formatUniqueKey(value)])
            .map((value) => get_timeseries_groups_from_metric(value?.ts_schema, source_def[formatUniqueKey(value)]));
        timeseries_groups.value = await Promise.all(promises);
    }
}

/* *************************************************** */
/* Utility functions */
/* *************************************************** */

/* Sorts timeseries requests by their key for consistent ordering */
function order_ts_request() {
    ts_request.value.sort((a, b) => a.tskey.localeCompare(b.tskey));
}

/* *************************************************** */
/* Chart options and data fetching */
/* *************************************************** */

/* Main function that fetches data from REST API and formats it for the chart */
async function get_chart_options() {
    const generation = ++refresh_generation;

    /* resolve_any_params must complete first — it populates ts_request.value which
     * is needed by both retrieve_basic_info() and the POST body below. */
    await resolve_any_params();
    if (generation !== refresh_generation) return null;  // Superseded by a newer refresh

    const url = base_url.value;
    const post_params = {
        csrf: props.csrf,
        ifid: props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        ...props.params.post_params,
        ...{
            ts_requests: ts_request.value
        }
    };

    /* retrieve_basic_info() fetches metric schema metadata (consts.lua for all interfaces).
     On first load -> HTTP call
     On refresh -> cache
      */
    const [_, result] = await Promise.all([
        retrieve_basic_info(),
        /* Use get_component_data callback to enable report generation as well */
        props.get_component_data(url,
            /* Note: passing query params (even when not required) to be used by check_diff_params() */
            /* Note: filters are also passed here (as GET params) for timeseries computed from raw flows supporting them */
            { ifid: props.ifid, epoch_begin: props.epoch_begin, epoch_end: props.epoch_end, ...props.filters },
            post_params, props.epoch_begin),
    ]);
    if (generation !== refresh_generation) return null;

    /* Format the result for Dygraph chart */
    let formatted = timeseriesUtils.tsArrayToOptionsArray(result, timeseries_groups.value, group_option_mode, '');
    if (formatted[0]) {
        formatted[0].height = height.value;
        formatted[0].connectSeparatedPoints = true;  // Connect points even with gaps in data
    }
    return formatted?.[0];
}

/* *************************************************** */
/* Watchers */
/* *************************************************** */

/* Watch for changes on epoch_begin/epoch_end/filters and refresh the chart accordingly */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    refreshChart();
}, { flush: 'pre', deep: true });

/* *************************************************** */
/* Lifecycle hooks */
/* *************************************************** */

/* Initialize component before mounting */
onBeforeMount(async () => {
    await init();
});

/* *************************************************** */

onMounted(() => {
    firstLoading.value = false;
});  // Mounted hook

/* *************************************************** */
/* Initialization and refresh functions */
/* *************************************************** */

/* Initializes component by calculating height based on max_height prop */
async function init() {
    height.value = (props.max_height || 4) * height_per_row;
}

/* *************************************************** */

/* Refreshes chart data and updates the display */
async function refreshChart() {
    if (chart.value) {
        const result = await get_chart_options();
        if (result !== null) {
            chart.value.updateChartSeries(result);
        }
    }
}

/* Expose refreshChart method to parent components */
defineExpose({ refreshChart });

</script>
