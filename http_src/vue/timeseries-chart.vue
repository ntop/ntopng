<!-- (C) 2026 - ntop.org -->
<template>
    <!-- Main container for the chart component with legend controls -->
    <div class="mb-2" style="overflow-x: auto; white-space: nowrap;"> <!-- legend-wrapper -->
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
            <div class="ms-auto">
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
            <div class="mb-3 w-100 position-relative" ref="first_chart">
            </div>
            <!-- Second chart container (hidden) - used for smooth transitions -->
            <div class="mb-3 w-100 d-none position-relative" ref="second_chart">
            </div>
            <!-- Legend display element (hidden by default) -->
            <div class="dygraph-legend" ref="legend" style="display:none;"></div>
        </template>
        <template v-else>
            <!-- Chart containers with fixed minimum height of 320px -->
            <div class="mb-3 w-100 position-relative" style="min-height:320px;" ref="first_chart">
            </div>
            <div class="mb-3 w-100 d-none position-relative" style="min-height:320px;" ref="second_chart">
            </div>
            <div class="dygraph-legend" ref="legend" style="display:none;"></div>
        </template>
    </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { ntopng_utility, ntopng_status_manager, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import { Dygraph } from '../utilities/graph/dygraph';

// Component event definitions for parent communication
const emit = defineEmits(["apply", "hidden", "showed", "chart_reloaded", "zoom"]);

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
 * Fetches and processes chart configuration options from server or custom provider.
 * Applies date formatting, stacked option updates, and emits chart_reloaded event.
 * 
 * @param {string} url_request - Complete URL for fetching chart options
 * @returns {Promise<Object>} Processed chart configuration object
 * @throws May throw if HTTP request fails
 */
const getChartOptions = async function (url_request) {
    let chart_options = {};
    const date_format = await ntopng_utility.get_date_format(false, props.csrf, http_prefix);

    /* Retrieve the chart options from server or custom provider */
    if (props.get_custom_chart_options == null) {
        chart_options = await ntopng_utility.http_request(url_request);
    } else {
        chart_options = await props.get_custom_chart_options(url_request);
    }
    if (!chart_options) {
        chart_options = {}
    }
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
const followLegend = async function (event) {
    const targetDiv = drawOnSecondDiv.value ? second_chart.value : first_chart.value
    const containerRect = targetDiv.getBoundingClientRect();
    const mouseX = event.clientX - containerRect.left;
    const mouseY = event.clientY - containerRect.top;

    const offset = 50;

    let left = mouseX + offset;
    let top = mouseY - offset;

    // Clamp position to keep legend within container bounds
    left = Math.min(left, containerRect.width - legend.value.offsetWidth - 2);
    top = Math.min(top, containerRect.height - legend.value.offsetHeight - 2);

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
const hideLegend = async function () {
    legend.value.style.display = 'none';
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
    options.labelsDiv = legend.value
    options.highlightCallback = followLegend
    options.unhighlightCallback = hideLegend
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

/* *************************************************** */

/** 
 * Vue lifecycle hook: Called after the component template is mounted to the DOM.
 * Initializes the chart and signals readiness to synchronization system.
 */
onMounted(async () => {
    await init();
    ntopng_sync.ready(props.id);
});

/* *************************************************** */

// Expose public methods for parent component access
defineExpose({ updateChartSeries, getImage });

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
    z-index: 80 !important;
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