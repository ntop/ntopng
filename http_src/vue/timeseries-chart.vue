<!-- (C) 2026 - ntop.org -->
<template>
    <!-- Main container for the chart component with legend controls -->
    <div class="mb-2"> <!-- legend-wrapper -->
        <div class="d-flex align-items-center"> <!-- legend-div -->
            <!-- Stacked chart toggle switch (hidden when hide_stacked prop is true) -->
            <div v-if="!$props.hide_stacked" class="form-check form-switch form-control-sm ms-1"
                data-bs-toggle="tooltip"
                :title="block_stacked ? _i18n('stacked_blocked_title') : _i18n('stacked_unblocked_title')">
                <input type="checkbox" class="form-check-input" @click="changeStacked" :checked="stacked"
                    :disabled="block_stacked">
                <label class="form-check-label">
                    {{ _i18n('stacked') }}
                </label>
            </div>
            <!-- Timeseries visibility toggles - dynamically generated checkboxes -->
            <div class="ms-auto" style="overflow-x: auto; white-space: nowrap;">
                <label class="form-check-label form-control-sm" v-for="(item, i) in timeseries_list">
                    <input type="checkbox" class="form-check-input align-middle mt-0"
                        @click="changeVisibility(!item.checked, i)" :checked="item.checked"
                        style="border-color: #0d6efd;" :style="{ backgroundColor: item.color }">
                    {{ item.name }}
                </label>
            </div>
        </div>
    </div>
    <!-- Chart containers with dynamic height based on disable_fixed_height prop -->
    <div>
        <template v-if="disable_fixed_height == true">
            <!-- First chart container (active) - no fixed height -->
            <div class="mb-3 w-100 position-relative first-chart" ref="first_chart">
            </div>
            <!-- Second chart container (hidden) - used for smooth transitions -->
            <div class="mb-3 w-100 position-relative second-chart d-none" ref="second_chart">
            </div>
            <!-- Legend display element (hidden by default) -->
            <div class="dygraph-legend" ref="legend" style="display:none;"></div>
        </template>
        <template v-else>
            <!-- Chart containers with fixed minimum height of 320px -->
            <div class="mb-3 w-100 position-relative first-chart" style="min-height:320px;" ref="first_chart">
            </div>
            <div class="mb-3 w-100 d-none position-relative second-chart" style="min-height:320px;" ref="second_chart">
            </div>
            <div class="dygraph-legend" ref="legend" style="display:none;"></div>
        </template>
    </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { ntopng_utility, ntopng_status_manager, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import { Dygraph } from '../utilities/graph/dygraph';
import formatterUtils from '../utilities/formatter-utils';
import dygraphFormat from '../utilities/graph/dygraph-format';
import colorsInterpolation from '../utilities/colors/colors-interpolation';

// Component event definitions for parent communication
const emit = defineEmits(["chart_reloaded", "zoom", "chart-updated", "update-requested"]);

// Component prop definitions with TypeScript-like annotations
const props = defineProps({
    id: String, // Unique identifier for the chart component
    chart_type: String, // Type of chart (e.g., line, bar, etc.)
    register_on_status_change: Boolean, // Whether to register for status change events
    base_url_request: String, // Base URL for fetching chart data
    get_params_url_request: Function, // Function to generate URL parameters
    get_custom_chart_options: Function, // Custom chart options provider
    disable_fixed_height: Boolean, // Whether to disable fixed chart height
    hide_stacked: Boolean, // Whether to hide the stacked chart toggle
});

// Reactive state variables
const drawOnSecondDiv = ref(false) // Toggle between first and second chart container
const chart = ref(null) // Reference to the Dygraph chart instance
const legend = ref(null); // Reference to the legend DOM element
const first_chart = ref(null) // Reference to first chart container
const second_chart = ref(null) // Reference to second chart container
const stacked = ref(null) // Whether chart is in stacked mode
const block_stacked = ref(false) // Whether stacked mode is disabled
const from_zoom = ref(false) // Flag to track if zoom action initiated the update
const timeseries_list = ref([]) // List of timeseries with visibility states
const _i18n = (t) => i18n(t) // Internationalization helper function

/* *************************************************** */

/**
 * Constructs the complete URL for chart data requests.
 * Combines base URL with parameters from either custom function or URL manager.
 * 
 * @param {Object|null} status - Optional status object for parameter generation
 * @returns {string} Complete URL with query parameters
 */
const get_url_request = function (status) {
    let url_params = '';
    if (props.get_params_url_request != null) {
        if (status == null) {
            status = ntopng_status_manager.get_status();
        }
        url_params = props.get_params_url_request(status);
    } else {
        url_params = ntopng_url_manager.get_url_params();
    }

    return `${props.base_url_request || ''}?${url_params}`;
}

/* *************************************************** */

/**
 * Registers the chart component to listen for status change events.
 * When status changes, updates the chart with new data if URL has changed.
 * 
 * @param {Object} status - Initial status object
 * @sideeffect Registers callback with ntopng_status_manager
 */
const register_status = function (status) {
    let url_request = get_url_request(status);
    ntopng_status_manager.on_status_change(props.id, (new_status) => {
        if (from_zoom.value == true) {
            from_zoom.value = false;
        }
        const new_url_request = get_url_request(new_status);
        if (new_url_request === url_request) {
            url_request = new_url_request;
            return;
        }
        url_request = new_url_request;
        updateChart(new_url_request);
    }, false);
}

/* *************************************************** */

/**
 * Initializes the chart component.
 * Sets up status change listeners if configured and loads initial data.
 */
const init = function () {
    const status = ntopng_status_manager.get_status();
    const url_request = get_url_request(status);
    if (props.register_on_status_change) {
        register_status(status);
    }
    retrieveOptionsAndDraw(url_request);
}

/* *************************************************** */

/**
 * Toggles the stacked chart mode.
 * Updates local state, persists preference to localStorage, and updates the chart.
 * 
 * @sideeffect Updates stacked.value, localStorage, and chart display
 */
const changeStacked = function () {
    stacked.value = !stacked.value;
    localStorage.setItem('ntopng.timeseries.chartStackedOption.' + props.id, stacked.value)
    updateIntoStackedChart(stacked.value);
}

/* *************************************************** */

/**
 * Changes the visibility of a specific timeseries in the chart.
 * Updates the internal state and communicates with Dygraph instance.
 * 
 * @param {boolean} visible - Whether the timeseries should be visible
 * @param {number} id - Index of the timeseries in timeseries_list
 */
const changeVisibility = function (visible, id) {
    if (timeseries_list.value[id] != null) {
        timeseries_list.value[id]["checked"] = visible
        chart.value.setVisibility(id, visible);
    }
}

/* *************************************************** */

/**
 * Utility function to ensure a nested object path exists.
 * Creates intermediate objects as needed if they don't exist.
 * 
 * @param {Object} obj - Target object to modify
 * @param {Array<string>} path - Array of keys representing the path
 * @returns {Object} Reference to the object at the end of the path
 * 
 * @example
 * ensurePath({}, ['axes', 'x']) // Returns empty object at obj.axes.x
 */
const ensurePath = function (obj, path) {
    return path.reduce((acc, key) => (acc[key] ??= {}), obj);
}

/* *************************************************** */

/**
 * Updates the stacked chart option based on saved preferences and chart constraints.
 * Handles initialization, localStorage retrieval, and blocked stacked scenarios.
 * 
 * @param {Object} chart_options - Chart configuration object
 * @returns {Object} Updated chart_options with stackedGraph property set
 */
const updateStackedOption = function (chart_options) {
    if (stacked.value === null && !chart_options.blockStacked) {
        // First loading of the chart - check localStorage for saved preference
        const is_stacked_option_found = localStorage.getItem('ntopng.timeseries.chartStackedOption.' + props.id)
        if (is_stacked_option_found !== null) {
            stacked.value = (is_stacked_option_found == 'true');
            chart_options.stackedGraph = stacked.value;
        } else {
            stacked.value = chart_options.stackedGraph;
        }
    } else {
        // Subsequent loads or blocked stacked mode
        if (chart_options.blockStacked)
            stacked.value = false;
        chart_options.stackedGraph = stacked.value;
    }
    return chart_options;
}

/* *************************************************** */

/**
 * Converts a raw batch result {series:[{id,name,data}], metadata:{epoch_begin,epoch_step,...}}
 * into a dygraph-ready options object {data, labels, colors, series, axes, ...}.
 * If the result already has .data it is returned as-is (already formatted by dygraph-config.js).
 *
 * For rxtx schemas (bytes_sent / bytes_rcvd), bytes_rcvd is negated so it plots below zero.
 */
const convertBatchResult = function (result) {
    if (!result || result.data) return result;   // already formatted or null

    const seriesArr = result.series || [];
    if (!seriesArr.length) return null;

    const metadata    = result.metadata || {};
    const epochBegin  = metadata.epoch_begin || 0;
    const step        = metadata.epoch_step  || 300;
    const n           = seriesArr[0]?.data?.length || 0;
    const measureUnit = result.measure_unit || "number";

    /* Detect rxtx pattern: series ids are bytes_sent and bytes_rcvd */
    const isRxtx = seriesArr.length === 2 &&
        seriesArr.some(s => s.id === 'bytes_sent') &&
        seriesArr.some(s => s.id === 'bytes_rcvd');

    const labels = ["Time", ...seriesArr.map(s => String(s.name || s.label || s.id || ""))];
    const palette = dygraphFormat.defaultColors;
    const baseColors = seriesArr.map((_, i) => palette[i % palette.length]);
    const colors = colorsInterpolation.transformColors(baseColors);

    const seriesConfig = {};
    labels.slice(1).forEach(name => {
        seriesConfig[name] = { fillGraph: true, strokeWidth: 1.0, pointSize: 1.5, fillAlpha: 0.5 };
    });

    const rows = [];
    for (let i = 0; i < n; i++) {
        const t = new Date((epochBegin + i * step) * 1000);
        const row = [t];
        seriesArr.forEach(s => {
            let v = s.data?.[i];
            if (v === null || v === undefined || v !== v) { row.push(NaN); return; }
            /* Negate received bytes so they plot below zero */
            if (isRxtx && s.id === 'bytes_rcvd') v = -v;
            row.push(v);
        });
        rows.push(row);
    }

    const formatter = formatterUtils.getFormatter(measureUnit);
    /* For rxtx, show absolute value in axis labels and tooltip */
    const axisFormatter  = isRxtx ? (v) => formatter(Math.abs(v)) : formatter;
    const valueFormatter = isRxtx ? (v) => formatter(Math.abs(v)) : (v) => formatter(v);

    /* Build legendFormatter using the same style as dygraph-config.js */
    const legendFormatter = function (data) {
        if (!data.x) return "";
        const timeBadge = `<h6><span class="badge bg-light mb-1 text-dark">${data.xHTML}</span></h6>`;
        const seriesHTML = data.series
            .filter(s => s.isVisible && s.yHTML)
            .map(s => {
                const colorDot = `<span class="badge rounded-pill me-1" style="background-color:${s.color}"> </span>`;
                return `<div class="mt-1 d-flex"><div class="me-4">${colorDot}${s.labelHTML}</div><div class="ms-auto">${s.yHTML}</div></div>`;
            }).join("");
        return `<div style="font-size:13px; line-height:1.4;">${timeBadge}${seriesHTML}</div>`;
    };

    const opts = {
        data:            rows,
        labels,
        colors,
        series:          seriesConfig,
        stackedGraph:    false,
        legendFormatter,
        axes: {
            y: {
                axisLabelFormatter: axisFormatter,
                valueFormatter:     valueFormatter,
                axisLabelWidth:     80,
            },
        },
        yRangePad:   1,
        includeZero: true,
    };
    if (isRxtx) {
        opts.includeZero = true;
        opts.blockStacked = true;
    }
    if (result._height) opts.height = result._height;
    return opts;
}

/* *************************************************** */

/**
 * Fetches and processes chart configuration options from server or custom provider.
 * Applies date formatting, stacked option updates, and emits chart_reloaded event.
 *
 * @param {string} url_request - Complete URL for fetching chart options
 * @returns {Promise<Object>} Processed chart configuration object
 * @throws May throw if HTTP request fails
 */
const getChartOptions = async function (url_request) {
    /* date_format is only needed for axis label formatting, fetch it in parallel with the actual chart data */
    const chart_options_promise = props.get_custom_chart_options != null
        ? props.get_custom_chart_options(url_request)
        : ntopng_utility.http_request(url_request);

    /* When the custom provider already embeds date_format/timezone in the options
     * (batch API responses), skip the extra server round-trip. */
    const chart_options_raw = await chart_options_promise;
    const meta_date_format = chart_options_raw?._meta?.date_format;
    if (meta_date_format) {
        ntopng_utility.set_cached_date_format(meta_date_format);
    }
    const [date_format] = await Promise.all([
        ntopng_utility.get_date_format(false, props.csrf, http_prefix),
    ]);

    /* If the provider returned a raw batch result, convert it to dygraph format */
    let chart_options = (chart_options_raw?.series && !chart_options_raw?.data)
        ? (convertBatchResult(chart_options_raw) || {})
        : (chart_options_raw || {});

    const xAxis = ensurePath(chart_options, ["axes", "x"]);
    /* Set the date formatting depending on the server date format */
    xAxis.axisLabelFormatter ??= function (date) {
        return ntopng_utility.from_utc_to_server_date_format(date, date_format);
    };
    xAxis.valueFormatter ??= function (date) {
        return ntopng_utility.from_utc_to_server_date_format(date, date_format);
    };
    /* Update the stacked option based on user preferences */
    chart_options = updateStackedOption(chart_options);
    /* Emit the chart_reloaded event for parent components */
    emit('chart_reloaded', chart_options);
    return chart_options;
}

/* *************************************************** */

/**
 * Orchestrates the process of fetching chart options and drawing the chart.
 * 
 * @param {string} url_request - URL for fetching chart data and options
 */
const retrieveOptionsAndDraw = async function (url_request) {
    const chart_options = await getChartOptions(url_request);
    if (!chart_options || !chart_options.data) return;
    drawChart(chart_options)
}

/* *************************************************** */

/**
 * Positions the legend element to follow the mouse cursor during highlighting.
 * Calculates position within chart container with boundary clamping.
 * 
 * @param {MouseEvent} event - Mouse event containing cursor coordinates
 * @sideeffect Updates legend element position and visibility
 */
let _containerRect = null;

const followLegend = function (event) {
    if (!_containerRect) {
        const targetDiv = drawOnSecondDiv.value ? second_chart.value : first_chart.value;
        _containerRect = targetDiv.getBoundingClientRect();
    }
    const mouseX = event.clientX - _containerRect.left;
    const mouseY = event.clientY - _containerRect.top;

    const offset = 50;

    let left = mouseX + offset;
    let top = mouseY - offset;

    left = Math.min(left, _containerRect.width - legend.value.offsetWidth - 2);
    top = Math.min(top, _containerRect.height - legend.value.offsetHeight - 2);

    legend.value.style.left = `${left}px`;
    legend.value.style.top = `${top}px`;
    legend.value.style.display = 'block';
}

/* *************************************************** */

/**
 * Hides the legend element when mouse leaves chart area.
 * 
 * @sideeffect Sets legend display to 'none'
 */
const hideLegend = function () {
    legend.value.style.display = 'none';
}

/* *************************************************** */

/**
 * Hides the legend element when mouse leaves chart area.
 * 
 * @sideeffect Sets legend display to 'none'
 */
const chartUpdated = async function (dygraph, is_initial) {
    const option = { dygraph: dygraph, firstLoad: is_initial };
    emit('chart-updated', option);
}

/* *************************************************** */

/**
 * Creates and renders a Dygraph chart with the provided options.
 * Supports smooth transitions between chart states using dual containers.
 * 
 * @param {Object} options - Chart configuration object from getChartOptions
 * @param {boolean} drawOnHidden - Whether to draw on the hidden container for transitions
 * @sideeffect Creates new Dygraph instance, updates timeseries_list, manages container visibility
 */
const drawChart = async function (options, drawOnHidden) {
    const data = options.data || [];
    options.data = null;
    options.zoomCallback = onZoomed;
    options.drawCallback = chartUpdated;
    /* When legend:'follow' is set (batch-converted charts), Dygraph's own plugin
     * handles positioning — don't override with manual labelsDiv/highlightCallback */
    if (!options.legend) {
        options.labelsDiv = legend.value;
        options.highlightCallback = followLegend;
        options.unhighlightCallback = hideLegend;
    }
    if (options.blockStacked) {
        block_stacked.value = true
    }

    // Build timeseries list for legend checkboxes
    timeseries_list.value = [];
    let visibility = [];
    let id = 0;
    if (!options.disableTsList) {
        for (const key in options.series) {
            timeseries_list.value.push({ name: key, checked: true, id: id, color: options.colors[id] + "!important" });
            id = id + 1;
            visibility.push(true);
        }
    }

    // Handle container switching for smooth transitions
    if (drawOnHidden) {
        drawOnSecondDiv.value = !drawOnSecondDiv.value
    }

    _containerRect = null; // invalidate cached rect on each draw

    const targetDiv = drawOnSecondDiv.value ? second_chart.value : first_chart.value
    const newChart = new Dygraph(targetDiv, data, options);

    // Swap containers and clean up old chart if transitioning
    if (drawOnHidden) {
        const toHideDiv = !drawOnSecondDiv.value ? second_chart.value : first_chart.value
        /* Basically swap the 2 divs for smooth transition */
        toHideDiv.classList.add('d-none');
        targetDiv.classList.remove('d-none');
        newChart.resize();
        newChart.resetZoom();
        chart.value.destroy();
        chart.value = null;
        // Clean the width and height used by Dygraph
        toHideDiv.style.width = '';
        toHideDiv.style.height = '';
    }
    chart.value = newChart;
}

/* *************************************************** */

/**
 * Updates an existing chart with new data from the specified URL.
 * 
 * @param {string} url_request - URL for fetching updated chart data
 */
const updateChart = async function (url_request) {
    if (chart.value) {
        const chart_options = await getChartOptions(url_request);
        chart.value.updateChart(chart_options);
    }
}

/* *************************************************** */

/**
 * Updates the chart's stacked mode without reloading data.
 * 
 * @param {boolean} stacked - Whether to enable stacked mode
 */
const updateIntoStackedChart = function (stacked) {
    if (chart.value) {
        chart.value.updateOptions({ 'stackedGraph': stacked });
    }
}

/* *************************************************** */

/**
 * Exports the current chart as a PNG image.
 * 
 * @param {Object} image - Image configuration object for export
 * @returns {*} Result from Dygraph export function
 */
const getImage = function (image) {
    const targetDiv = drawOnSecondDiv.value ? second_chart.value : first_chart.value
    return Dygraph.Export.asPNG(chart.value, image, targetDiv);
}

/* *************************************************** */

/**
 * Updates chart timeseries with new data, handling structural changes.
 * Recreates the chart entirely if timeseries list has changed (added/removed series).
 * Otherwise updates the existing chart with new data.
 * 
 * @param {Object} options - New chart options with updated data/series
 */
const updateChartSeries = async function (options) {
    emit('update-requested', { firstLoad: false });
    if (options == null || !chart.value) { return; }
    /* There is a possibility: that the timeseries number changes, for example, 
     * before there was the DNS, now there is not. For that reason we have to 
     * check if the timeseries options are the same or not
     */
    let recreateChart = false;

    // Check for new series
    for (const serie_name in options.series) {
        if (!timeseries_list.value.find((element) => { return (element.name === serie_name) })) {
            /* Element not found, the list is not the same */
            recreateChart = true;
            break
        }
    }

    // Check for removed series
    timeseries_list.value.forEach((serie) => {
        if (!options.series[serie.name]) {
            recreateChart = true;
            return;
        }
    });

    // Recreate chart if series structure changed, otherwise update
    if (recreateChart) {
        drawChart(options, true)
    } else {
        chart.value.updateOptions({ 'file': options.data, 'colors': options.colors, 'labels': options.labels });
    }
    // Alwais reset the zoom after updating
    chart.value.resetZoom()
}

/* *************************************************** */

/**
 * Handles zoom events from the Dygraph chart.
 * Converts dates to epoch timestamps and emits zoom event to parent.
 * 
 * @param {Date} minDate - Start date of zoom range
 * @param {Date} maxDate - End date of zoom range
 * @sideeffect Emits zoom event, updates global epoch status
 */
const onZoomed = function (minDate, maxDate) {
    from_zoom.value = true;
    const begin = moment(minDate);
    const end = moment(maxDate);
    // the timestamps are in milliseconds, convert them into seconds
    let new_epoch_status = { epoch_begin: Number.parseInt(begin.unix()), epoch_end: Number.parseInt(end.unix()) };
    ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, new_epoch_status, props.id);
    emit('zoom', new_epoch_status);
}

// Used to redraw the legend
function clampDygraphLegend() {
    if (!legend.value) return;

    const observer = new MutationObserver(() => {

        const rect = legend.value.getBoundingClientRect();
        const margin = 8;

        if (rect.bottom > window.innerHeight) {
            const overflow = rect.bottom - window.innerHeight;
            const newTop = Math.max(margin, parseFloat(legend.value.style.top) - overflow - margin);
            legend.value.style.top = newTop + 'px';
        }

        if (rect.top < margin) {
            legend.value.style.top = margin + 'px';
        }
    });

    observer.observe(legend.value, { attributes: true, attributeFilter: ['style'] });
}

/* *************************************************** */

/** 
 * Vue lifecycle hook: Called after the component template is mounted to the DOM.
 * Initializes the chart and signals readiness to synchronization system.
 */
onMounted(async () => {
    emit('update-requested', { firstLoad: true });
    await nextTick();
    // In this way, with the double requestAnimationFrame, it's sure that the DOM layout + style
    // is complitely loaded, and this should avoid problems with slow systems, e.g. loading the chart
    // outside the div (wrong height + width)
    requestAnimationFrame(() => {
        requestAnimationFrame(() => {
            init();
            ntopng_sync.ready(props.id);
            clampDygraphLegend();
        })
    })
});

/* *************************************************** */

// Expose public methods for parent component access
defineExpose({ updateChartSeries, getImage, retrieveOptionsAndDraw });

/* *************************************************** */
</script>

<style>
/* Custom styles for Dygraph legend and axis labels */
.dygraph-legend {
    color: var(--ntop-text-color);
    background-color: var(--timeseries-legend-bg-color) !important;
    border-color: var(--timeseries-legend-border-color);
    border-style: solid;
    border-width: thin;
    z-index: 9999 !important;
    position: absolute;
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, .15);
    border-radius: 0.375rem;
    width: auto;
    word-wrap: break-word;
    padding: 8px !important;
}

.dygraph-legend>span {
    color: #111111;
    padding-left: 5px;
    padding-right: 2px;
    margin-left: -5px;
    background-color: #FFFFFF !important;
}

.dygraph-legend>span:first-child {
    margin-top: 2px;
}

.dygraph-axis-label {
    z-index: 10;
    line-height: normal;
    overflow: hidden;
    color: var(--ntop-text-color);
}
</style>