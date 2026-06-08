<template>
    <div>
        <!-- Filter and Time Resolution Controls -->
        <div class="d-flex flex-wrap align-items-center mb-2 gap-1">
            <!-- ASN Type Filter Dropdown -->
            <div class="dropdown me-3 d-flex">
                <span class="no-wrap d-flex align-items-center filters-label me-2">
                    <b>{{ _i18n("asn_configuration.filter") }}: </b>
                </span>
                <SelectSearch v-model:selected_option="current_selected_option" theme="bootstrap-5"
                    :options="asn_type_option" @select_option="add_filter" :dropdown_size="'small'" />
            </div>

            <!-- Time Resolution Dropdown (only shown when chart is visible and timeseries is enabled) -->
            <div class="dropdown me-3 d-flex">
                <span class="no-wrap d-flex align-items-center filters-label me-2">
                    <b>{{ _i18n("time") }}: </b>
                </span>
                <SelectSearch v-model:selected_option="selected_resolution" theme="bootstrap-5"
                    :options="resolutionOptions" @select_option="select_resolution" :dropdown_size="'small'" />
            </div>

            <!-- Interface Role Filter Dropdown -->
            <div class="dropdown me-3 d-flex">
                <span class="no-wrap d-flex align-items-center filters-label me-2">
                    <b>{{ _i18n("as_stats.interface_role") }}: </b>
                </span>
                <SelectSearch v-model:selected_option="current_interface_role" theme="bootstrap-5"
                    :options="interface_role_options" @select_option="add_interface_role_filter"
                    :dropdown_size="'small'" />
            </div>

            <!-- Interface Filter Dropdown (visible only when role is peering or transit) -->
            <div v-if="current_interface_role?.value === 'peering' || current_interface_role?.value === 'transit'"
                class="dropdown me-3 d-flex">
                <span class="no-wrap d-flex align-items-center filters-label me-2">
                    <b>{{ _i18n("as_stats.interfaces") }}: </b>
                </span>
                <SelectSearch v-model:selected_option="current_interface_filter" theme="bootstrap-5"
                    :options="interface_filter_options" @select_option="add_interface_filter"
                    :dropdown_size="'small'" />
            </div>
        </div>

        <!-- Timeseries Chart Section -->
        <div v-if="(showChart)" class="position-relative chart-container">
            <!-- Loading Overlay -->
            <Loading :isLoading="loadingChart" />

            <!-- Chart Title -->
            <div class="widget-name">
                <h6 class="m-0">{{ chart_title }}</h6>
            </div>

            <!-- Chart Component with Transition Effect -->
            <Transition name="add-effect" mode="out-in">
                <DashboardTimeseries ref="timeseries_chart" :key="timeseries_key" :id="timeseries_id"
                    :epoch_begin="epoch_begin" :epoch_end="epoch_end" :i18n_title="chart_title"
                    :ifid="props.context.ifid.toString()" :max_width="12" :max_height="4" :params="params"
                    :get_component_data="get_component_data" :csrf="props.context.csrf" @update-requested="updateChart"
                    @chart-updated="updateChartDone" />
            </Transition>
        </div>

        <!-- ASN Statistics Table Section -->
        <div class="position-relative">
            <TableWithConfig ref="table_as_stats" :table_id="table_id" :csrf="props.context.csrf" :showLoading="true"
                :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
                :handleLoadedColumns="handleLoadedColumns" :get_extra_params_obj="get_extra_params_obj"
                @custom_event="on_table_custom_event" />
        </div>
    </div>
</template>

<script setup>
/**
 * ASN Statistics Component
 * Displays ASN (Autonomous System Number) statistics with timeseries chart and data table
 * Supports filtering by ASN type (customer, sub-customer, remote, etc.) and time resolution
 * 
 * @component AsStats
 */

import { ref, onBeforeMount, onMounted, computed } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as DashboardTimeseries } from "./dashboard-timeseries.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as Loading } from "./loading.vue"
import FormatterUtils from "../utilities/formatter-utils.js";
import NtopUtils from "../utilities/ntop-utils.js";

// Internationalization helper
const _i18n = (t) => i18n(t);

// Component Props
const props = defineProps({
    /** Context object containing configuration and runtime data */
    context: Object,
});

// Time Constants
const currentTime = Math.floor(Date.now() / 1000);
const SECONDS_ONE_DAY = 3600 * 24;
const SECONDS_FIFTEEN_MINUTES = 15 * 60;

// Table Configuration
// Renders table from httpdocs/tables_config/as_stats.json if context.ASNModeEnabled is false,
// otherwise renders the IXP mode table from httpdocs/tables_config/as_stats_ixp_mode.json
const table_id = 'as_stats';

// Chart Configuration
const chart_title = _i18n('top_active_asn');
const timeseries_id = ref('topASNPageASStats');
const loadingChart = ref(true);
const timeseries_chart = ref(null);
const table_as_stats = ref(null);
const epoch_begin = ref(currentTime - SECONDS_ONE_DAY); // Default: one day ago
const epoch_end = ref(currentTime);
const showSankey = props.context.showSankey;
const showTimeResolution = ref(props.context.isClickhouseEnabled)
const showChart = ref(props.context.isEnterprise && props.context.showTimeseries);
const isLive = ref(true);
const current_selected_option = ref([]);
const current_interface_role = ref([]);
const current_interface_filter = ref([]);

// ASN Type Icons with Tooltips
const ASN_ICONS = {
    customer: { icon: 'fa-house-flag', i18nKey: 'asn_configuration.customer_asn_title' },
    subCustomer: { icon: 'fa-house-laptop', i18nKey: 'asn_configuration.sub_customer_asn_title' },
    remote: { icon: 'fa-house-fire', i18nKey: 'asn_configuration.remote_asn_title' },
};

// Component Keys for Re-rendering
const timeseries_key = ref(false);

// ASN Type Filter Options
const asn_type_option = ref([
    { key: "show_as", value: "all", label: i18n("asn_configuration.all_asn") },
    { key: "show_as", value: "my_as", label: i18n("asn_configuration.customer_asn_title") },
    { key: "show_as", value: "my_customer_as", label: i18n("asn_configuration.sub_customer_asn_title") },
    { key: "show_as", value: "remote_as", label: i18n("asn_configuration.remote_asn_title") },
    { key: "show_as", value: "other_as", label: i18n("asn_configuration.other") }
]);

// Interface Role Filter Options
const interface_role_options = ref([
    { key: "interface_role", value: "all", label: i18n("as_stats.all_roles") },
    { key: "interface_role", value: "peering", label: i18n("prefs.snmp_interface_role_list.peering") },
    { key: "interface_role", value: "transit", label: i18n("prefs.snmp_interface_role_list.transit") },
]);

// Interface Filter Options
const interface_filter_options = ref([
    { key: "interface_filter", value: `all`, label: i18n("db_search.all.input_snmp") }
]);

// Time Resolution Options
let resolutionOptions = ref([
    { value: "live", label: i18n('show_alerts.presets.live'), icon: "fa-solid fa-circle fa-2xs text-danger", currently_active: false },
]);
const DEFAULT_RESOLUTION = "live"
const selected_resolution = ref(resolutionOptions.value.find((el) => el.value === DEFAULT_RESOLUTION));

// Chart Query Parameters
const params = {
    post_params: {
        limit: 180,
        version: 4,
        ts_requests: {
            "$IFID$": {
                ts_query: `ifid:$IFID$`,
                ts_schema: `top:asn:traffic`,
            }
        }
    },
    source_type: "interface"
};

// Time Series Query Template
const ts_query = {
    ts_query: `ifid:$IFID$,asn:$ASN$`,
    ts_schema: `asn:traffic`,
};

/**
 * Updates chart loading state when update is requested
 */
const updateChart = () => {
    loadingChart.value = true;
};

/**
 * Updates chart loading state when update is complete
 */
const updateChartDone = () => {
    loadingChart.value = false;
};

/**
 * Loads ASN filter from URL parameters or sets default
 */
const loadASNFilter = () => {
    const selected_as = ntopng_url_manager.get_url_entry("show_as");
    if (selected_as) {
        const option = asn_type_option.value.find((el) => el.value === selected_as);
        if (option) {
            current_selected_option.value = option;
        }
    } else {
        current_selected_option.value = asn_type_option.value[0];
    }
    ntopng_url_manager.set_key_to_url(current_selected_option.value.key, current_selected_option.value.value);
}

/**
 * Loads interface role filter from URL parameters or sets default
 */
const loadInterfaceRoleFilter = () => {
    const selected_role = ntopng_url_manager.get_url_entry("interface_role");
    if (selected_role) {
        const role_option = interface_role_options.value.find((el) => el.value === selected_role);
        if (role_option) {
            current_interface_role.value = role_option;
        }
    } else {
        current_interface_role.value = interface_role_options.value[0];
    }
    ntopng_url_manager.set_key_to_url(current_interface_role.value.key, current_interface_role.value.value);
}

/**
 * Loads interface filter from URL parameters and populates interface list
 */
const loadInterfaceFilter = () => {
    load_interfaces_filter().then(() => {
        const selected_interface = ntopng_url_manager.get_url_entry("interface_filter");
        if (selected_interface) {
            const iface_option = interface_filter_options.value.find((el) => String(el.value) === String(selected_interface));
            if (!iface_option) {
                // Interface not found, falling back to the default one
                current_interface_filter.value = interface_filter_options.value[0];
                ntopng_url_manager.set_key_to_url(current_interface_filter.value.key, current_interface_filter.value.value);
            }
        }
    })
}

/**
 * Loads time resolution options and sets selected value from URL or localStorage
 */
const loadTimeResolution = () => {
    // If ClickHouse is enabled, then it is possible to not only see th "live" data
    // but also see historical data, so simply add data
    if (showTimeResolution.value) {
        const extra_resolutions = [
            { value: "30_min", label: i18n('show_alerts.presets.30_min'), currently_active: false },
            { value: "hour", label: i18n('show_alerts.presets.hour'), currently_active: false },
            { value: "12_hours", label: i18n('show_alerts.presets.12_hours'), currently_active: false },
            { value: "day", label: i18n('show_alerts.presets.day'), currently_active: true },
            { value: "week", label: i18n('show_alerts.presets.week'), currently_active: false },
        ]
        resolutionOptions.value.push(...extra_resolutions)
        // Also in this case, search for the storage default url
        const storedResolution = localStorage.getItem('ntopng.timeseries.chartResolution.' + timeseries_id);
        const requestedResolution = ntopng_url_manager.get_url_entry("chart_resolution") ?
            storedResolution : DEFAULT_RESOLUTION;
        selected_resolution.value = resolutionOptions.value.find((el) => el.value === requestedResolution)
    }
    select_resolution(selected_resolution.value, true);
}

/* *************************************************** */
// Lifecycle Hooks
/* *************************************************** */
onMounted(() => { })

/**
 * Component initialization before mounting
 * Loads saved filter preferences from URL or localStorage
 */
onBeforeMount(() => {
    // Load ASN filter from URL
    loadASNFilter();
    // Load Interface Role filter from URL
    loadInterfaceRoleFilter();
    // Load Interface filter from URL
    loadInterfaceFilter();
    // Load time resolution from URL
    loadTimeResolution();
});

/* *************************************************** */
// Event Handlers
/* *************************************************** */

/**
 * Handles time resolution selection
 * @param {Object} value - Selected resolution option
 * @param {boolean} isFirstLoad - Whether this is the initial component load
 */
const select_resolution = (value, isFirstLoad) => {
    // Retrieve the timeframe value
    const timeframes = ntopng_utility.get_timeframes_dict();
    const selected_timeframe = timeframes[value.value];

    // Check the timeframe requested
    if (selected_timeframe != null) {
        if (selected_timeframe === 0) {
            // Live mode: 15 minutes ago up to now
            isLive.value = true;
            epoch_begin.value = epoch_end.value - SECONDS_FIFTEEN_MINUTES;
        } else {
            // Historical mode: selected timeframe up to now
            epoch_begin.value = epoch_end.value - selected_timeframe;
            isLive.value = false;
        }
    }

    // Refresh table if not first load
    if (!isFirstLoad) {
        table_as_stats.value.refresh_table(false);
    }

    // Save preference
    localStorage.setItem('ntopng.timeseries.chartResolution.' + timeseries_id, value.value);
};

/* *************************************************** */

/**
 * Adds ASN type filter and refreshes data
 * @param {Object} value - Selected filter option
 */
const add_filter = async (value) => {
    current_selected_option.value = value;
    ntopng_url_manager.set_key_to_url(current_selected_option.value.key, current_selected_option.value.value);
    timeseries_key.value = !timeseries_key.value; // Force chart re-render
    table_as_stats.value.refresh_table(false);
};

/**
 * Adds Interface Role filter and refreshes data
 * @param {Object} value - Selected filter option
*/
const add_interface_role_filter = async (value) => {
    current_interface_role.value = value;
    ntopng_url_manager.set_key_to_url(current_interface_role.value.key, current_interface_role.value.value);
    // If interface_filter is present, remove it
    ntopng_url_manager.delete_key_from_url(current_interface_filter.value.key);
    load_interfaces_filter().then(() => {
        timeseries_key.value = !timeseries_key.value; // Force chart re-render
        table_as_stats.value.refresh_table(false);
    })
};

/**
 * Adds Interface filter and refreshes data
 * @param {Object} value - Selected filter option
*/
const add_interface_filter = (value) => {
    current_interface_filter.value = value;
    ntopng_url_manager.set_key_to_url(current_interface_filter.value.key, current_interface_filter.value.value);
    timeseries_key.value = !timeseries_key.value; // Force chart re-render
    table_as_stats.value.refresh_table(false);
};

/* *************************************************** */
// Data Fetching
/* *************************************************** */

/**
 * Fetches the list of interfaces for the currently selected role (peering or transit)
 * and populates the interface filter dropdown accordingly.
 * If the role is neither "peering" nor "transit", clears the dropdown and returns early.
 */
// Note the abort controller is used to stop a request in case the user
// swap between interfaces roles fast enough to not let the previous
// request end before sending the second one, this can create race conditions
let _interfaceAbortController = null;
// Also use requestId guard pattern to prevent race conditions
let requestId = 0;
async function load_interfaces_filter() {
    if (current_interface_role.value.value === interface_role_options.value[0].value) {
        // Load this filter only when a specific role is selected, not the "All" filter
        return;
    }
    const id = ++requestId;
    // abort previous request
    if (_interfaceAbortController) {
        _interfaceAbortController.abort();
    }
    // create new controller
    _interfaceAbortController = new AbortController();
    const controller = _interfaceAbortController;
    // Clear the array, except the All Interfaces (alwais available)
    interface_filter_options.value.splice(1)
    // Set the filter to the default one (first element)
    current_interface_filter.value = interface_filter_options.value[0];
    // Fetch interfaces filtered by the current role from the REST endpoint
    const url = `${http_prefix}/lua/pro/rest/v2/get/snmp/metric/role_interfaces.lua?snmp_interface_role=${current_interface_role.value.value}`;
    return ntopng_utility.http_request(url, { signal: controller.signal }, true)
        .then((response) => {
            // if the request is aborted ignore result
            if (controller.signal.aborted) return;
            // if the request is an old one, ignore it
            if (id !== requestId) return;

            // When the request is done, update the filter options
            interface_filter_options.value = [
                ...interface_filter_options.value,
                ...response.map((iface) => ({
                    key: "interface_filter",
                    value: iface.device_ip + "_" + iface.interface_id,
                    label: iface.interface_name,
                }))
            ]
        })
        .catch((e) => {
            if (e.name === "AbortError") {
                console.log("Previous interface request aborted");
                return;
            }
            console.error(e);
        });
}

/**
 * Requests REST data from components for timeseries chart
 * @param {string} url - Base URL for the request
 * @param {Object} query_params - Query parameters
 * @param {Object} post_params - POST parameters
 * @returns {Promise<Object>} Timeseries data
 */
const get_component_data = async (url, query_params, post_params) => {
    const url_params = ntopng_url_manager.obj_to_url_params(get_extra_params_obj());
    const top_url = `${http_prefix}/lua/rest/v2/get/asn/get_top_asn.lua?${url_params}`;
    const top_data = await ntopng_utility.http_request(top_url);

    const queryLabels = {};
    const queries = (top_data || []).map((el, i) => {
        const qid = `top_asn_${i}`;
        queryLabels[qid] = el.asname || `ASN ${el.asn}`;
        return {
            id:        qid,
            ts_schema: `asn:traffic`,
            ts_query:  `ifid:${props.context.ifid},asn:${el.asn}`,
            ts_unify:  true,
            limit:     post_params.limit || 180,
        };
    });
    post_params.queries = queries;
    delete post_params.ts_requests;
    const resp = await ntopng_utility.http_post_request(url, post_params);
    if (resp) resp._queryLabels = queryLabels;
    return resp;
};

/**
 * Builds additional parameters for API requests
 * @returns {Object} Extra parameters including time range
 */
const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return {
        ...extra_params,
        ...{
            epoch_begin: epoch_begin.value,
            epoch_end: epoch_end.value,
            is_live: isLive.value
        }
    };
};

/* ************************************** */
// Formatting Utilities
/* ************************************** */

/**
 * Formats ASN icon based on AS type
 * @param {*} value - Cell value
 * @param {Object} row - Row data
 * @returns {string} HTML icon string
 */
const formatIconAS = (value, row) => {
    const type = row.is_customer_asn ? 'customer'
        : row.is_sub_customer_asn ? 'subCustomer'
            : row.is_remote_asn ? 'remote'
                : null;
    if (!type) return '';
    const { icon, i18nKey } = ASN_ICONS[type];
    return `<i class="fa-solid ${icon}" data-bs-toggle="tooltip" data-bs-placement="top" title="${_i18n(i18nKey)}"></i>`;
};

/*******************************************************/
// Column Configuration
/*******************************************************/

/**
 * Dynamically modifies columns based on license and available data
 * @param {Array} columns - Original column definitions
 * @returns {Array} Modified column definitions
 */
const handleLoadedColumns = (columns) => {
    let modified_columns = columns;
    if (props.context.ASNModeEnabled === true) {
        // Remove columns not needed in ASN mode
        modified_columns = modified_columns.filter((element) => {
            return ((element.id !== "num_hosts")
                && (element.id !== "alerted_flows")
                && (element.id !== "score"));
        });
    } else {
        modified_columns = modified_columns.filter((element) => {
            return (element.id !== "breakdown_role");
        });
    }
    return modified_columns;
};

/* ************************************** */

/**
 * Maps table column definitions to rendering functions
 * @param {Array} columns - Column definitions
 * @returns {Array} Enhanced column definitions with render functions
 */
const map_table_def_columns = (columns) => {
    let map_columns = {
        /**
         * Renders AS name with links and icons
         */
        "asname": (value, row) => {
            const asName = row["asname"];
            let return_value = "";
            let icon = formatIconAS(value, row);

            if (asName.length > 0) {
                return_value += `${row["asname"]}`;
                if (row["asn"] != 0) {
                    return_value += ` [ <A class='ntopng-external-link' href='https://stat.ripe.net/app/launchpad/S1_${row["asn"]}_C13C31C4C34C9C22C28C20C6C7C26C29C30C14C17C2C21C33C16C10'>RIPEstat <i class='fas fa-external-link-alt fa-sm'></i></A>`;
                    return_value += ` | <A class='ntopng-external-link' href='https://www.peeringdb.com/asn/${row["asn"]}'>PeeringDB <i class='fas fa-external-link-alt fa-sm'></i></A> ]`;
                }
            }
            return_value += icon;
            return return_value;
        },

        /**
         * Renders AS number
         */
        "asn": (value, row) => row["asn"],

        /**
         * Formats host count
         */
        "hosts": (value, row) => FormatterUtils.getFormatter("number")(value),

        /**
         * Formats seen since timestamp
         */
        "seen_since": (value, row) => FormatterUtils.formatDateTime(value),

        /**
         * Formats score value
         */
        "score": (value, row) => FormatterUtils.getFormatter("number")(value),

        /**
         * Creates traffic breakdown visualization
         */
        "breakdown": (value, row) => {
            const total_bytes = row["traffic"];
            const bytes_sent_pctg = total_bytes ? (value.bytes_sent / total_bytes) * 100 : 0;
            const bytes_rcvd_pctg = total_bytes ? (value.bytes_rcvd / total_bytes) * 100 : 0;
            return NtopUtils.createBreakdown(bytes_sent_pctg, bytes_rcvd_pctg, "Sent", "Rcvd");
        },

        /**
         * Creates per-role traffic breakdown visualization (Other / Transit / Peering)
         */
        "breakdown_role": (value, row) => {
            const total_bytes = (value.bytes_other || 0) + (value.bytes_transit || 0) + (value.bytes_peering || 0);
            if (!total_bytes) return NtopUtils.createBreakdown_multi_elem([0], [_i18n("no_data")]);
            const raw = [
                (value.bytes_other / total_bytes) * 100,
                (value.bytes_transit / total_bytes) * 100,
                (value.bytes_peering / total_bytes) * 100,
            ];

            const [pct_other, pct_transit, pct_peering] = NtopUtils.largestRemainderRound(raw);

            return NtopUtils.createBreakdown_multi_elem(
                [pct_other, pct_transit, pct_peering],
                [
                    _i18n("asn_configuration.other"),
                    _i18n("prefs.snmp_interface_role_list.transit"),
                    _i18n("prefs.snmp_interface_role_list.peering"),
                ]
            );
        },

        /**
         * Formats throughput in bps
         */
        "throughput": (value, row) => FormatterUtils.getFormatter("bps")(value),

        /**
         * Formats traffic in bytes
         */
        "traffic": (value, row) => FormatterUtils.getFormatter("bytes")(value),

        /**
         * Formats alerted flows count
         */
        "alerted_flows": (value, row) => FormatterUtils.getFormatter("number")(value),
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];

        // Configure action buttons
        if (c.id == "actions") {
            const visible_dict = {
                host: true,
                flows: true,
                exporters_stats: showSankey,
                timeseries: props.context.showTimeseries,
            };

            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // Disable buttons based on conditions
                    if (!visible_dict[b.id]) {
                        current_class.push("disabled");
                    } else if (((row.asn === 0) || ((isLive.value === false) && row.is_in_memory === false)) && (b.id === "exporters_stats")) {
                        current_class.push("disabled");
                    } else if (((isLive.value === false) && (row.is_in_memory === false)) && (b.id === "host")) {
                        current_class.push("disabled");
                    }
                    return current_class;
                };
            });
        }
    });

    return columns;
};

/* ************************************** */
// Button Click Handlers
/* ************************************** */

/**
 * Navigates to exporters statistics page
 * @param {Object} event - Click event containing row data
 */
function click_button_exporters_stats(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/as_overview.lua?asn=${row["asn"]}`;
}

/* ************************************** */

/**
 * Navigates to hosts statistics page
 * @param {Object} event - Click event containing row data
 */
function click_button_host(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/hosts_stats.lua?asn=${row["asn"]}`;
}

/* ************************************** */

/**
 * Navigates to flows statistics page (live or historical based on mode)
 * @param {Object} event - Click event containing row data
 */
function click_button_flows(event) {
    const row = event.row;
    if (isLive.value == true) {
        window.location.href = `${http_prefix}/lua/flows_stats.lua?asn=${row["asn"]}`;
    } else {
        window.location.href = `${http_prefix}/lua/pro/db_search.lua?ifid=${props.context.ifid}&epoch_begin=${epoch_begin.value}&epoch_end=${epoch_end.value}&asn=${row.asn};eq`;
    }
}

/* ************************************** */

/**
 * Navigates to timeseries historical view
 * @param {Object} event - Click event containing row data
 */
function click_button_timeseries(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/as_overview.lua?asn=${row["asn"]}&page=historical`;
}

/* ************************************** */

/**
 * Dispatches table custom events to appropriate handlers
 * @param {Object} event - Custom event object
 */
function on_table_custom_event(event) {
    let events_managed = {
        "click_button_host": click_button_host,
        "click_button_flows": click_button_flows,
        "click_button_exporters_stats": click_button_exporters_stats,
        "click_button_timeseries": click_button_timeseries,
    };

    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

/**
 * Custom sorting function for table columns
 * @param {Object} col - Column definition
 * @param {Object} r0 - First row to compare
 * @param {Object} r1 - Second row to compare
 * @returns {number} Comparison result
 */
function columns_sorting(col, r0, r1) {
    if (col != null) {
        /* Networks */
        if (col.id == "as_number") {
            return sortingFunctions.sortByNumber(r0.asn, r1.asn, col.sort);
        } else if (col.id == "name") {
            return sortingFunctions.sortByName(r0.asname, r1.asname, col.sort);
        } else if (col.id == "num_hosts") {
            return sortingFunctions.sortByNumber(r0.num_hosts, r1.num_hosts, col.sort);
        } else if (col.id == "score") {
            return sortingFunctions.sortByNumber(r0.score, r1.score, col.sort);
        } else if (col.id == "alerted_flows") {
            return sortingFunctions.sortByNumber(r0.alerted_flows, r1.alerted_flows, col.sort);
        } else if (col.id == "alerted_flows") {
            return sortingFunctions.sortByNumber(r0.alertedFlows, r1.alertedFlows, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
    }
}
</script>

<style scoped>
/**
 * Transition animations for component add/remove effects
 * Uses Vue's transition system with enter/leave animations
 */

/* Apply transition to moving elements */
.add-effect-move,
.add-effect-enter-active,
.add-effect-leave-active {
    transition: all 0.35s ease;
}

/**
 * Enter animation: fade in from left
 */
.add-effect-enter-from {
    opacity: 0;
    transform: translateX(-60px);
}

/**
 * Leave animation: fade out
 */
.add-effect-leave-to {
    opacity: 0;
    transform: translateX(0px);
}

/**
 * Ensure leaving items are taken out of layout flow
 * so that moving animations can be calculated correctly
 */
.add-effect-leave-active {
    position: absolute;
}

.chart-container {
    height: 330px;
}

@media (max-width: 768px) {
    .chart-container {
        height: 220px;
    }
}
</style>
