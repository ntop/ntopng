<template>
    <div>
        <div class="button-group mb-2 d-flex align-items-center">
            <div class="dropdown me-3 d-flex"><span class="no-wrap d-flex align-items-center filters-label me-2"><b>{{
                _i18n("exporters_interfaces_configuration.filter")
                        }}: </b></span>
                <SelectSearch v-model:selected_option="current_selected_option" theme="bootstrap-5"
                    :options="interfaces_role_filters" @select_option="add_filter">
                </SelectSearch>
            </div>
        </div>
        <div v-if="(showChart) && props.context.showTimeseries" class="position-relative" style="height: 330px;">
            <Loading :isLoading="loading"></Loading>
            <div class="widget-name">
                <h6 class="m-0">{{ chart_title }}</h6>
            </div>
            <Transition name="add-effect" mode="out-in">
                <DashboardTimeseries ref="timeseries_chart" :key="timeseries_key" :id="timeseries_id"
                    :epoch_begin="epoch_begin" :epoch_end="epoch_end" :i18n_title="chart_title"
                    :ifid="system_interface_id" :max_width="12" :max_height="4" :params="params"
                    :get_component_data="get_component_data" :set_component_attr="set_component_attr"
                    :csrf="props.context.csrf">
                </DashboardTimeseries>
            </Transition>
        </div>
        <div class="position-relative">
            <TableWithConfig ref="table_exporters_interfaces_stats" :table_id="table_id" :csrf="props.context.csrf"
                :showLoading="true" :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
                :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
            </TableWithConfig>
        </div>
    </div>
</template>


<script setup>
import { ref, onBeforeMount, computed } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as DashboardTimeseries } from "./dashboard-timeseries.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as Loading } from "./loading.vue"
import formatterUtils from "../utilities/formatter-utils.js";
import dataUtils from "../utilities/data-utils.js";
import linksUtils from "../utilities/links-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const current_time = Math.floor(Date.now() / 1000);
const seconds_one_day = 3600 * 24;

// render table in httpdocs/tables_config/as_stats.json if context.ASNModeEnabled is false, else render the IXP mode table: httpdocs/tables_config/as_stats_ixp_mode.json
const table_id = computed(() => {
    return 'exporters_interfaces_stats';
});

const chart_title = _i18n('top_active_interfaces')
const timeseries_id = ref('top_interfaces');
const loading = ref(true);
const timeseries_chart = ref(null);
const table_exporters_interfaces_stats = ref(null);
const epoch_begin = ref(current_time - seconds_one_day); // Get one day ago
const epoch_end = ref(current_time);
const showSankey = props.context.showSankey;
const showChart = ref(props.context.isEnterprise);
const current_selected_option = ref([])
const interfaces_filters_rest_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevices/interfaces_role_filters.lua`
const interfaces_role_filters = ref([])
const timeseries_key = ref(true)
const system_interface_id = '-1'

const params = {
    post_params: {
        limit: 180,
        version: 4,
        ts_requests: {
            "$IFID$": {
                ts_query: `ifid:$IFID$`,
                ts_schema: `top:flowdev_port:traffic`,
            }
        }
    },
    source_type: "flow_device"
}

const ts_query = {
    ts_query: `ifid:$IFID$,device:$DEVICE$,port:$PORT$`,
    ts_schema: `flowdev_port:traffic`,
}

/* *************************************************** */

const set_component_attr = async (attr, value) => {
    component[attr] = value;
}

/* *************************************************** */

onBeforeMount(async () => {
    const filters_list = await ntopng_utility.http_request(interfaces_filters_rest_url)
    // Update the list of filters with the retrieved data
    if (filters_list && filters_list.length > 0) {
        interfaces_role_filters.value = filters_list;
    }
    // Select the filter based on the url (if given) or the first element 
    const selected_interface_role = ntopng_url_manager.get_url_entry("interface_role");
    if (selected_interface_role) {
        const option = interfaces_role_filters.value.find((el) => el.value === selected_interface_role);
        if (option) {
            current_selected_option.value = option
        }
    } else {
        current_selected_option.value = interfaces_role_filters.value[0]
    }
    ntopng_url_manager.set_key_to_url(current_selected_option.value.key, current_selected_option.value.value)
});

/* *************************************************** */

const add_filter = async (value) => {
    loading.value = true;
    current_selected_option.value = value;
    ntopng_url_manager.set_key_to_url(current_selected_option.value.key, current_selected_option.value.value)
    timeseries_key.value = !timeseries_key.value
    table_exporters_interfaces_stats.value.refresh_table(false);
}

/* *************************************************** */

/* Callback to request REST data from components — now calls batch.lua directly */
const get_component_data = async (url, query_params, post_params) => {
    loading.value = true;
    const top_query = {
        csrf: props.context.csrf,
        ifid: query_params.ifid,
        epoch_begin: query_params.epoch_begin,
        epoch_end: query_params.epoch_end,
        interface_role: current_selected_option.value.value,
    };
    const top_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevices/get_top_exporters_interfaces.lua?${ntopng_url_manager.obj_to_url_params(top_query)}`;
    const top_data = await ntopng_utility.http_request(top_url);
    const queries = (top_data || []).map((el, i) => ({
        id:        `top_iface_${i}`,
        ts_schema: `flowdev_port:traffic`,
        ts_query:  `ifid:${el.ifid},device:${el.exporter_ip},port:${el.interface_id}`,
        ts_unify:  true,
        limit:     post_params.limit || 180,
    }));
    post_params.queries = queries;
    delete post_params.ts_requests;
    const data = await ntopng_utility.http_post_request(url, post_params);
    loading.value = false;
    return data;
};

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "exporter_ip": (value, row) => {
            const url = linksUtils.getExporterDetailsPageURL({ ip: value, probe_source_id: row.probe_source_id, exporter_source_id: row.exporter_source_id }, http_prefix)
            return formatterUtils.formatHTMLaTagNameValue(value, row.exporter_name, url, true)
        },
        "interface_name": (value, row) => {
            const url = linksUtils.getFlowExporterInterfaceOverviewPageURL(row.exporter_ip, row.interface_id, http_prefix)
            return formatterUtils.formatHTMLaTagNameValue(row.interface_id, value, url, false)
        },
        "role": (value, row) => {
            if (!dataUtils.isEmptyString(value.label)) {
                return value.label
            }
            return "";
        },
        "bytes_sent": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        },
        "bytes_rcvd": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        },
        "total_bytes": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                host: true,
                flows: true,
                exporters_stats: showSankey,
                timeseries: props.context.showTimeseries,
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
                        current_class.push("disabled");
                    } else if (row.asn === 0 && (b.id === "exporters_stats")) {
                        current_class.push("disabled");
                    }
                    return current_class;
                }
            });
        }
    });

    return columns;
};

/* ************************************** */

function click_button_exporters_stats(event) {
    const row = event.row;
    window.location.href = linksUtils.getFlowExporterInterfaceOverviewPageURL(row["exporter_ip"], row["interface_id"], http_prefix);
}

/* ************************************** */

function click_button_flows(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/flows_stats.lua?deviceIP=${row["exporter_ip"]}&ifIdx=${row["interface_id"]}`;
}

/* ************************************** */

function click_button_hosts(event) {
    const row = event.row;
    const filters = {
        deviceIP: row.exporter_ip,
        ifIdx: row.interface_id
    }
    window.location.href = linksUtils.getAggregatedFlowsURL(filters, "host", http_prefix)
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    const url = linksUtils.getExporterInterfaceDetailsPageURL(row.exporter_ip, row.interface_id, row.ifid, http_prefix)
    window.location.href = url;
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_flows": click_button_flows,
        "click_button_exporters_stats": click_button_exporters_stats,
        "click_button_timeseries": click_button_timeseries,
        "click_button_hosts": click_button_hosts,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "total_bytes") {
            return sortingFunctions.sortByNumber(r0.total_bytes, r1.total_bytes, col.sort);
        } else if (col.id == "exporter_ip") {
            return sortingFunctions.sortByName(r0.exporter_ip, r1.exporter_ip, col.sort);
        } else if (col.id == "interface_name") {
            return sortingFunctions.sortByName(r0.interface_name, r1.interface_name, col.sort);
        } else if (col.id == "role") {
            return sortingFunctions.sortByName(r0.role?.value, r1.role?.value, col.sort);
        } else if (col.id == "bytes_sent") {
            return sortingFunctions.sortByNumber(r0.bytes_sent, r1.bytes_sent, col.sort);
        } else if (col.id == "bytes_rcvd") {
            return sortingFunctions.sortByNumber(r0.bytes_rcvd, r1.bytes_rcvd, col.sort);
        }
        // Default option
        return sortingFunctions.sortByName(r0.exporter_ip, r1.exporter_ip, col.sort);
    }
}
</script>

<style scoped>
.add-effect-move,
/* apply transition to moving elements */
.add-effect-enter-active,
.add-effect-leave-active {
    transition: all 0.35s ease;
}

/* Transform: positive pixels, the effects let enters the component
 * from the right, negative pixels from the left
 */
.add-effect-enter-from {
    opacity: 0;
    transform: translateX(-60px);
}

.add-effect-leave-to {
    opacity: 0;
    transform: translateX(0px);
}

/* ensure leaving items are taken out of layout flow so that moving
   animations can be calculated correctly. */
.add-effect-leave-active {
    position: absolute;
}
</style>
