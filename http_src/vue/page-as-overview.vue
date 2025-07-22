<template>
        <DateTimeRangePicker v-if="enable_date_time_range_picker" class="dontprint"
            id="as-date-time-picker" :round_time="true"
            min_time_interval_id="min" @epoch_change="set_time_interval">

            <!-- Report Selector -->
            <template v-slot:begin>
                <div class="me-2">
                <SelectSearch v-model:selected_option="active_sankey_type" :options="sankey_format_list"
                    @select_option="changeCriteria">
                </SelectSearch>

                </div>
            </template>

            <!-- Report Toolbox (Store, Save, ...) -->
            <template v-slot:extra_buttons>
            </template>
        </DateTimeRangePicker>

    <div class="m-2 mb-3">
        <div v-if="!enable_date_time_range_picker" class="button-group mb-2 d-flex align-items-center">
            <div class="dropdown me-3 d-flex"><span class="no-wrap d-flex align-items-center filters-label me-2"><b>{{
                _i18n("criteria")
                        }}: </b></span>
                <SelectSearch v-model:selected_option="active_sankey_type" :options="sankey_format_list"
                    @select_option="changeCriteria">
                </SelectSearch>
            </div>
        </div>
        <div style="position: relative;">
            <div class="mb-3 d-flex flex-column" style="height: 60vh;">
                <Loading :isLoading="loading"></Loading>
                <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data"
                    :autorefresh="autoRefreshEnabled" @node_click="on_node_click"
                    @autorefresh_toggle="onAutoRefreshToggle">
                </Sankey>
            </div>
        </div>
        <div style="position: relative;">
            <TableWithConfig v-if="props.context.isEnterpriseL" ref="table_as_stats" :key="reload" :table_id="table_id"
                :csrf="props.context.csrf" :showLoading="true" :f_map_columns="map_table_def_columns"
                :f_sort_rows="columns_sorting" :get_extra_params_obj="get_extra_params_obj"
                @custom_event="on_table_custom_event">
            </TableWithConfig>
        </div>
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
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import FormatterUtils from "../utilities/formatter-utils.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const first_open = ref(true);
const sankey_url = `${http_prefix}/lua/rest/v2/get/asn/sankey.lua`;
const sankey_chart = ref(null)
const sankey_data = ref({});
const loading = ref(true);
const no_data_message = _i18n("as_overview.no_data")
const autoRefreshEnabled = ref(false);
const active_sankey_type = ref({})
const table_as_stats = ref(null);
const reload = ref(false);
const main_epoch_interval = ref(null);
const table_id = ref(props.context.tableId);
const sankey_format_list = [
    { key: "criteria_as", value: 'ingress_egress_traffic_criteria', label: _i18n('as_overview.ingress_egress_traffic_criteria') },
    { key: "criteria_as", value: 'as_traffic_criteria', label: _i18n('as_overview.as_traffic_criteria') },
];

const note_list = [
    _i18n("as_overview.note_ingress_egress"),
];

const enable_date_time_range_picker = computed(() => {
    return props.context.historical;
});

/* ************************************** */

onBeforeMount(() => {
    const criteria = ntopng_url_manager.get_url_entry("criteria_as");
    active_sankey_type.value = sankey_format_list[0];
    if (criteria) {
        sankey_format_list.forEach((element) => {
            if (element.value == criteria) {
                active_sankey_type.value = element
            }
        })
    }
})

const onAutoRefreshToggle = (enabled) => {
    autoRefreshEnabled.value = enabled;
}

onMounted(() => {
    update_sankey_data();
    setInterval(() => {
        first_open.value = false;

        // refresh only if autorefresh is enabled
        if (autoRefreshEnabled.value) {
            update_sankey_data()
        }
    }, 10000 /* 10 sec refresh */)
})

/* ************************************** */

/* This function is called upon changing the selected option in the dropdown */
const changeCriteria = async (opt) => {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    update_sankey_data();
    if (table_as_stats.value) {
        if (opt.value === "ingress_egress_traffic_criteria") {
            table_id.value = "ingress_egress_as_stats"
        } else if(opt.value === "as_traffic_criteria") {
            table_id.value = "transit_as_stats"
        }
        reload.value = !reload.value
    }
}

/* ************************************** */

function set_time_interval(epoch_interval) {
    if (epoch_interval) {
        main_epoch_interval.value = epoch_interval;

        update_sankey_data();
        reload.value = !reload.value
    }
}

/* ************************************** */

const update_sankey_data = async () => {
    loading.value = true;
    let data = await get_sankey_data();
    sankey_data.value = data;
    loading.value = false;
}

const get_sankey_data = async () => {
    const url_request = get_sankey_url();
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

const get_sankey_url = () => {
    let params = {
        ifid: props.context.ifid,
        ...get_extra_params_obj()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${sankey_url}?${url_params}`;
    return url_request;
}

function on_node_click(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ***************************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    const asn = ntopng_url_manager.get_url_entry("asn");
    const url = `${http_prefix}/lua/as_overview.lua?asn=${asn}&page=historical&ts_schema=asn:exporter_traffic&ts_query=ifid:${props.context.ifid},asn:${asn},device:${row["device"]["id"]},if_index:${row["interface"]["id"]}`;
    window.location.href = url
}


/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_timeseries": click_button_timeseries,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "device") {
            return sortingFunctions.sortByName(r0.device.name, r1.device.name, col.sort);
        } else if (col.id == "interface") {
            return sortingFunctions.sortByName(r0.interface.name, r1.interface.name, col.sort);
        } else if (col.id == "as") {
            return sortingFunctions.sortByName(r0.as.name, r1.as.name, col.sort);
        } else if (col.id == "transit_as") {
            return sortingFunctions.sortByName(r0.transit_as.name, r1.transit_as.name, col.sort);
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

const map_table_def_columns = (columns) => {
    let map_columns = {
        "device": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                value.id
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "interface": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                value.id
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "as": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                value.id
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "transit_as": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                value.id
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
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
