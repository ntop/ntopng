<template>

    <div class="button-group mb-2 d-flex align-items-center">
        <div class="dropdown me-2 d-flex"><span class="no-wrap d-flex align-items-center filters-label me-2"><b>{{
            _i18n("view_options")
                    }}: </b></span>
            <SelectSearch v-model:selected_option="active_sankey_type" :options="sankey_format_list"
                @select_option="changeCriteria">
            </SelectSearch>
        </div>
        <div class="w-100 d-flex align-items-center button-group">
            <CustomSwitch v-model:value="toggle_slider" :change_label_side="true" :label="toggle_slider_label" style=""
                class="me-1" icon="fa-calendar-days" :title="toggle_slider_label" @change_value="saveSwitch">
            </CustomSwitch>
            <div class="w-100 position-relative">
                <Transition name="add-effect" mode="out-in">
                    <DateTimeRangePicker v-if="!toggle_slider" class="dontprint" id="as-date-time-picker"
                        :round_time="true" :custom_time_interval_list="time_preset_list" min_time_interval_id="live"
                        :custom_change_select_time="changeTime" @epoch_change="setTimeInterval">
                    </DateTimeRangePicker>
                </Transition>
                <Transition name="add-effect" mode="out-in">
                    <DateSlider v-if="toggle_slider" id="as-date-slider" :min_epoch="first_date_epoch"
                        @epoch_change="setTimeInterval" style="width: 100%" />
                </Transition>
            </div>
        </div>
    </div>

    <div class="m-2 mb-3">
        <div class="position-relative">
            <div class="mb-3 d-flex flex-column" style="height: 60vh;">
                <Loading :isLoading="loading"></Loading>
                <Sankey v-if="show_sankey" ref="sankey_chart" :no_data_message="no_data_message"
                    :sankey_data="sankey_data" @node_click="onNodeClick" @autorefresh_toggle="onAutoRefreshToggle">
                </Sankey>
                <Pie v-if="show_pie" ref="pie_chart" :no_data_message="no_data_message" :pie_data="pie_data"
                    @autorefresh_toggle="onAutoRefreshToggle">>
                </Pie>
            </div>
        </div>
        <Transition name="add-effect" mode="out-in">
            <div class="position-relative" :key="reRenderTable" style="min-height: 614px;">
                <TableWithConfig v-if="props.context.isEnterpriseL && show_table" ref="table_as_stats"
                    :table_id="table_id" :csrf="props.context.csrf" :showLoading="true" :f_map_columns="mapTableColumns"
                    :f_sort_rows="columnsSorting" :get_extra_params_obj="getExtraParameters"
                    @custom_event="onTableCustomEvent">
                </TableWithConfig>
            </div>
        </Transition>
        <div class="card-footer">
            <NoteList :note_list="note_list"> </NoteList>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as Loading } from "./loading.vue"
import { default as Sankey } from "./sankey.vue";
import { default as Pie } from "./pie-test.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as DateSlider } from "./date-slider.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as CustomSwitch } from "./custom-switch.vue";
import FormatterUtils from "../utilities/formatter-utils.js";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const sankey_url = `${http_prefix}/lua/rest/v2/get/asn/sankey.lua`;
const pie_url = `${http_prefix}/lua/rest/v2/get/asn/pie.lua`;
const sankey_chart = ref(null);
const sankey_data = ref({});
const pie_chart = ref(null);
const pie_data = ref({});
const show_table = ref(true);
const show_pie = ref(true);
const show_sankey = ref(true);
const loading = ref(true);
const no_data_message = _i18n("as_overview.no_data")
let intervalId = null;
const active_sankey_type = ref({})
const table_as_stats = ref(null);
const reRenderTable = ref(false);
const main_epoch_interval = ref(null);
const first_date_epoch = ref(props.context.first_date_epoch);
const toggle_slider = ref(false);
const toggle_slider_label = ref(_i18n("db_search.time_range"));
const skipFirstCheck = ref(true);
const customerIcon = '<i class="fa-solid fa-house-flag" data-bs-toggle="tooltip" data-bs-placement="top" title="' + _i18n("asn_configuration.customer_asn_title") + '"></i>'
const subCustomerIcon = '<i class="fa-solid fa-house-laptop" data-bs-toggle="tooltip" data-bs-placement="top" title="' + _i18n("asn_configuration.sub_customer_asn_title") + '"></i>'
const remoteIcon = '<i class="fa-solid fa-house-fire" data-bs-toggle="tooltip" data-bs-placement="top" title="' + _i18n("asn_configuration.remote_asn_title") + '"></i>'
const sankey_format_list = [
    { key: "criteria_as", value: 'traffic_between_ases', label: _i18n('as_overview.as_traffic_criteria') },
    { key: "criteria_as", value: 'ingress_egress_traffic_criteria', label: _i18n('as_overview.ingress_egress_traffic_criteria') },
];
const time_preset_list = [
    { value: "live", label: i18n('live'), currently_active: true },
    { value: "30_min", label: i18n('show_alerts.presets.30_min'), currently_active: false },
    { value: "hour", label: i18n('show_alerts.presets.hour'), currently_active: false },
    { value: "12_hours", label: i18n('show_alerts.presets.12_hours'), currently_active: false },
    { value: "day", label: i18n('show_alerts.presets.day'), currently_active: false },
    { value: "week", label: i18n('show_alerts.presets.week'), currently_active: false },
    { value: "month", label: i18n('show_alerts.presets.month'), currently_active: false },
    { value: "year", label: i18n('show_alerts.presets.year'), currently_active: false },
    { value: "custom", label: i18n('show_alerts.presets.custom'), currently_active: false, disabled: true, },
]

const note_list = [
    _i18n("as_overview.note_ingress_egress"),
];

/* ************************************** */

onMounted(() => {
    updateSankeyData();
    updatePieData();
})

/* ************************************** */

onBeforeMount(() => {
    defineDropdown();
    const criteria = ntopng_url_manager.get_url_entry("criteria_as");
    toggle_slider.value = localStorage.getItem("as-overview-slider") == "true"
    active_sankey_type.value = sankey_format_list[0];
    if (criteria) {
        sankey_format_list.forEach((element) => {
            if (element.value == criteria) {
                active_sankey_type.value = element
            }
        })
    }
    ntopng_url_manager.set_key_to_url("criteria_as", active_sankey_type.value.value);
    checkComponentsToShow();
})

/* ************************************** */

function checkComponentsToShow() {
    /* First two entries of the dropdown have both sankey + table */
    if (active_sankey_type.value.value == "traffic_between_ases" ||
        active_sankey_type.value.value == "ingress_egress_traffic_criteria") {
        show_table.value = true;
        show_sankey.value = true;
        show_pie.value = false;
    } else if (active_sankey_type.value.value == "user_traffic_breakdown") {
        show_table.value = false;
        show_sankey.value = false;
        show_pie.value = true;
    }
}

/* ************************************** */

const changeTime = (selectedTimeframe) => {
    let interval = 0; // Live
    if (selectedTimeframe !== 'live') {
        const timeframesDict = ntopng_utility.get_timeframes_dict();
        interval = timeframesDict[selectedTimeframe];
    }
    const epoch_end = ntopng_utility.get_utc_seconds(Date.now());
    const epoch_begin = epoch_end - interval;
    return [epoch_begin, epoch_end]
}

/* ************************************** */

const onAutoRefreshToggle = (enabled) => {
    if (enabled) {
        intervalId = setInterval(() => {
            updateSankeyData()
            updatePieData()
        }, 10000 /* 10 sec refresh */)
    } else {
        clearInterval(intervalId);
    }
}

/* ************************************** */

const table_id = computed(() => {
    if (active_sankey_type.value?.value === "ingress_egress_traffic_criteria") {
        return "ingress_egress_as_stats"
    } else if (active_sankey_type.value?.value === "traffic_between_ases") {
        return "traffic_between_ases"
    }

    return props.context.tableId;
});

/* ************************************** */

/* This function is called upon changing the selected option in the dropdown */
const changeCriteria = async (opt) => {
    checkComponentsToShow();
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    updateSankeyData();
    updatePieData();
}

/* ************************************** */

function reloadTable() {
    table_as_stats.value.refresh_table()
}

/* ************************************** */

function setTimeInterval(epoch_interval) {
    // Check if it's live
    if (epoch_interval.isToday) {
        ntopng_url_manager.delete_key_from_url("type")
    } else {
        ntopng_url_manager.set_key_to_url("type", "historical")
    }

    if (epoch_interval.timeframe_id === 'live' || (epoch_interval.epoch_begin === epoch_interval.epoch_end)) {
        ntopng_url_manager.delete_key_from_url("type")
        ntopng_url_manager.delete_key_from_url("timeframe_id")
    }
    main_epoch_interval.value = epoch_interval;
    updateSankeyData();
    updatePieData();
    reloadTable()
}

/* ************************************** */

function saveSwitch() {
    localStorage.setItem("as-overview-slider", toggle_slider.value);
}

/* ************************************** */

const updatePieData = async () => {
    if (show_pie.value) {
        loading.value = true;
        const data = await getPieData();
        pie_data.value = data;
        loading.value = false;
    }
}

/* ************************************** */

const getPieData = async () => {
    const url_request = getPieUrl();
    let graph = await ntopng_utility.http_request(url_request);
    return graph
}

/* ************************************** */

const getPieUrl = () => {
    let params = {
        ifid: props.context.ifid,
        ...getExtraParameters()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${pie_url}?${url_params}`;
    return url_request;
}

/* ************************************** */

const updateSankeyData = async () => {
    if (show_sankey.value) {
        loading.value = true;
        let data = await getSankeyData();
        sankey_data.value = data;
        loading.value = false;
    }
}

/* ************************************** */

const getSankeyData = async () => {
    const url_request = getSankeyUrl();
    let graph = await ntopng_utility.http_request(url_request);
    graph.nodes.forEach((node, i) => {
        node.index = i
    })
    graph.links.forEach((link, i) => {
        if (link.value === 0) {
            link.value = 1
        }
        let node = graph.nodes.find((el) => el.node_id == link.source_node_id)
        link.source = node.index;
        node = graph.nodes.find((el) => el.node_id == link.target_node_id)
        link.target = node.index;
    })

    return graph
}

/* ************************************** */

const getSankeyUrl = () => {
    let params = {
        ifid: props.context.ifid,
        ...getExtraParameters()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${sankey_url}?${url_params}`;
    return url_request;
}

/* ************************************** */

function onNodeClick(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ***************************************************** */

const getExtraParameters = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function defineDropdown() {
    let asn_configuration = props.context.configuration
    if (asn_configuration != "customer_asn" && asn_configuration != "sub_customer_asn"){
        sankey_format_list.push({
            key: "criteria_as",
            value: "user_traffic_breakdown",
            label: _i18n("as_overview.user_traffic_breakdown")
        });
    }
}

/* ************************************** */

function clickButtonTimeseries(event) {
    const row = event.row;
    const asn = ntopng_url_manager.get_url_entry("asn");
    const url = `${http_prefix}/lua/as_overview.lua?asn=${asn}&page=historical&ts_schema=asn:exporter_traffic&ts_query=ifid:${props.context.ifid},asn:${asn},device:${row["device"]["id"]},if_index:${row["interface"]["id"]}`;
    window.location.href = url
}


/* ************************************** */

function onTableCustomEvent(event) {
    let events_managed = {
        "click_button_timeseries": clickButtonTimeseries,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

function columnsSorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "device") {
            return sortingFunctions.sortByName(r0.device.name, r1.device.name, col.sort);
        } else if (col.id == "interface") {
            return sortingFunctions.sortByName(r0.interface.name, r1.interface.name, col.sort);
        } else if (col.id == "as") {
            return sortingFunctions.sortByName(r0.as.name, r1.as.name, col.sort);
        } else if (col.id == "dst_as") {
            return sortingFunctions.sortByName(r0.dst_as.name, r1.dst_as.name, col.sort);
        } else if (col.id == "src_as") {
            return sortingFunctions.sortByName(r0.src_as.name, r1.src_as.name, col.sort);
        } else if (col.id == "src_transit_as") {
            return sortingFunctions.sortByName(r0.src_transit_as?.name || "", r1.src_transit_as?.name || "", col.sort);
        } else if (col.id == "dst_transit_as") {
            return sortingFunctions.sortByName(r0.dst_transit_as?.name || "", r1.dst_transit_as?.name || "", col.sort);
        } else if (col.id == "transit_as") {
            return sortingFunctions.sortByName(r0.transit_as?.name || "", r1.transit_as?.name || "", col.sort);
        } else if (col.id == "bytes_sent") {
            return sortingFunctions.sortByNumber(r0.bytes_sent, r1.bytes_sent, col.sort);
        } else if (col.id == "bytes_rcvd") {
            return sortingFunctions.sortByNumber(r0.bytes_rcvd, r1.bytes_rcvd, col.sort);
        } else if (col.id == "total_bytes") {
            return sortingFunctions.sortByNumber(r0.total_bytes, r1.total_bytes, col.sort);
        }
    }
    /* Default sorting */
    return sortingFunctions.sortByNumber(r0.total_bytes, r1.total_bytes, col.sort);
}

/* ************************************** */

const formatAS = (value) => {
    if (!value) {
        return ''
    }
    let addTitle = true;
    let importantASNIcon = ''
    const title = `data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}"`;
    if (value.is_customer_asn) {
        importantASNIcon = customerIcon;
    } else if (value.is_sub_customer_asn) {
        importantASNIcon = subCustomerIcon;
    } else if (value.is_remote_asn) {
        importantASNIcon = remoteIcon;
    }
    if (dataUtils.isEmptyString(value.name)) {
        addTitle = false
    }
    if (!dataUtils.isEmptyString(value.url)) {
        return `<a href="${value.url}" ${addTitle ? title : ""}>${value.name}</a> ${importantASNIcon}`;
    }
    return `<span ${addTitle ? title : ""}>${value.name}</span> ${importantASNIcon}`;
}

/* ************************************** */

const mapTableColumns = (columns) => {
    let map_columns = {
        "device": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                return value.id
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "interface": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                return value.id
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "as": (value, row) => {
            return formatAS(value);
        },
        "dst_as": (value, row) => {
            return formatAS(value);
        },
        "src_as": (value, row) => {
            return formatAS(value);
        },
        "src_transit_as": (value, row) => {
            return formatAS(value);
        },
        "dst_transit_as": (value, row) => {
            return formatAS(value);
        },
        "bytes_sent": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value);
        },
        "bytes_rcvd": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value);
        },
        "total_bytes": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value);
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                timeseries: props.context.showTimeseries
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
                        current_class.push("disabled");
                    } else if (row.asn === 0 && (b.id === "exporters_stats" || b.id === "timeseries")) {
                        current_class.push("disabled");
                    }
                    return current_class;
                }
            });
        }
    });

    return columns;
};
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
    transform: translateX(60px);
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

.slider-connect {
    background: none !important;
}
</style>
