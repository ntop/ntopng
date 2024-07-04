<!-- (C) 2022 - ntop.org     -->
<template>
    <Navbar id="navbar" :main_title="context.navbar.main_title" :base_url="context.navbar.base_url"
        :help_link="context.navbar.help_link" :items_table="context.navbar.items_table" @click_item="click_navbar_item">
    </Navbar>

    <div class='row'>
        <div class='col-12'>
            <div class="mb-2">
                <div class="w-100">
                    <div clas="range-container d-flex flex-wrap">
                        <div class="range-picker d-flex m-auto flex-wrap">
                            <AlertInfo id="alert_info" :global="true" ref="alert_info"></AlertInfo>
                            <RangePicker v-if="mount_range_picker" ref="range_picker" id="range_picker"
                                :min_time_interval_id="min_time_interval_id" :round_time="round_time">
                                <template v-slot:begin>
                                    <Switch v-if="props.context.is_enterprise_xl" v-model:value="flows_aggregated"
                                        class="me-2 mt-1" :change_label_side="true" :label="flow_type_label" style=""
                                        @change_value="change_flow_type"></Switch>
                                    <div class="ms-1 me-2">
                                        <select class="me-2 form-select" style="min-width:8rem;"
                                            v-model="selected_query_preset" @change="update_select_query_presets()">
                                            <template v-for="item in query_presets">
                                                <option v-if="item.builtin == true" :value="item">{{ item.name }}</option>
                                            </template>
                                            <optgroup v-if="page != 'analysis'" :label="_i18n('queries.queries')">
                                                <template v-for="item in query_presets">

                                                    <option v-if="!item.builtin" :value="item">{{ item.name }}</option>
                                                </template>
                                            </optgroup>
                                        </select>
                                    </div>
                                </template>
                                <template v-slot:extra_range_buttons>
                                    <button v-if="context.show_permalink" class="btn btn-link btn-sm"
                                        @click="get_permanent_link" :title="_i18n('graphs.get_permanent_link')"
                                        ref="permanent_link_button"><i class="fas fa-lg fa-link"></i></button>
                                    <a v-if="context.show_download" class="btn btn-link btn-sm"
                                        :title="_i18n('graphs.download_records')" :href="href_download_records"><i
                                            class="fas fa-lg fa-file"></i></a>
                                    <button v-if="context.show_pcap_download || show_pcap_download" class="btn btn-link btn-sm"
                                        @click="show_modal_traffic_extraction"
                                        :title="_i18n('traffic_recording.pcap_download')"><i
                                            class="fas fa-lg fa-download"></i></button>
                                    <button v-if="context.is_ntop_enterprise_m" class="btn btn-link btn-sm"
                                        @click="show_modal_snapshot" :title="_i18n('datatable.manage_snapshots')"><i
                                            class="fas fa-lg fa-camera-retro"></i></button>
                                </template>
                            </RangePicker>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class='col-12'>
            <div class="card card-shadow">
                <div class="card-body">

                    <div class="row">
                        <div v-if="context.show_chart" class="col-12 mb-2" id="chart-vue">
                            <div class="card overflow-hidden" :style="chart_style">
                                <!-- <div class="card h-300 overflow-hidden"> -->
                                <Chart ref="chart" id="chart_0" :chart_type="chart_type" :base_url_request="chart_data_url"
                                    :map_chart_options="f_map_chart_options" :register_on_status_change="false"
                                    :min_time_interval_id="min_time_interval_id" :round_time="round_time">
                                </Chart>
                            </div>
                        </div>
                        <TableWithConfig ref="table_flows" :table_id="table_id" :table_config_id="table_config_id"
                            :csrf="context.csrf" :f_map_columns="map_table_def_columns"
                            :get_extra_params_obj="get_extra_params_obj" @loaded="on_table_loaded"
                            @custom_event="on_table_custom_event">
                            <template v-slot:custom_header>
                                <Dropdown v-for="(t, t_index) in top_table_array"
                                    :f_on_open="get_open_top_table_dropdown(t, t_index)"
                                    :ref="el => { top_table_dropdown_array[t_index] = el }"> <!-- Dropdown columns -->
                                    <template v-slot:title>
                                        <Spinner :show="t.show_spinner" size="1rem" class="me-1"></Spinner>
                                        <a class="ntopng-truncate" :title="t.title">{{ t.label }}</a>
                                    </template>
                                    <template v-slot:menu>
                                        <a v-for="opt in t.options" style="cursor:pointer; display: block;"
                                            @click="add_top_table_filter(opt, $event)" class="ntopng-truncate tag-filter "
                                            :title="opt.value">{{ opt.label + " (" + opt.count + "%)" }}</a>
                                    </template>
                                </Dropdown> <!-- Dropdown columns -->
                            </template> <!-- custom_header -->
                        </TableWithConfig>
                    </div>
                </div> <!-- card body -->

                <div v-if="props.context.show_acknowledge_all || props.context.show_delete_all" class="card-footer">
                    <button v-if="props.context.show_acknowledge_all" id="dt-btn-acknowledge" :disabled="true"
                        data-bs-target="#dt-acknowledge-modal" data-bs-toggle="modal" class="btn btn-primary me-1">
                        <i class="fas fa fa-user-check"></i> Acknowledge Alerts
                    </button>
                    <button v-if="props.context.show_delete_all" id="dt-btn-delete" :disabled="true"
                        data-bs-target="#dt-delete-modal" data-bs-toggle="modal" class="btn btn-danger">
                        <i class="fas fa fa-trash"></i> Delete Alerts
                    </button>
                </div> <!-- card footer -->
            </div> <!-- card-shadow -->

        </div> <!-- div col -->
    </div> <!-- div row -->

    <ModalTrafficExtraction id="modal_traffic_extraction" ref="modal_traffic_extraction">
    </ModalTrafficExtraction>

    <ModalSnapshot ref="modal_snapshot" :csrf="context.csrf">
    </ModalSnapshot>

    <ModalAcknoledgeAlert ref="modal_acknowledge" :context="context" @acknowledge="refresh_page_components">
    </ModalAcknoledgeAlert>

    <ModalDeleteAlert ref="modal_delete" :context="context" @delete_alert="refresh_page_components"></ModalDeleteAlert>

    <ModalAlertsFilter :alert="current_alert" :page="page" @exclude="add_exclude" ref="modal_alerts_filter">
    </ModalAlertsFilter>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility, ntopng_sync, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import NtopUtils from "../utilities/ntop-utils";
import { ntopChartApex } from "../components/ntopChartApex.js";
import { DataTableRenders } from "../utilities/datatable/sprymedia-datatable-utils.js";
import FormatterUtils from "../utilities/formatter-utils.js";

import { default as SelectSearch } from "./select-search.vue";
import { default as Navbar } from "./page-navbar.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as Spinner } from "./spinner.vue";

import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalAlertsFilter } from "./modal-alerts-filter.vue";
import { default as ModalAcknoledgeAlert } from "./modal-acknowledge-alert.vue";
import { default as ModalDeleteAlert } from "./modal-delete-alert.vue";

import { default as Switch } from "./switch.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const page_id = "page-flow-historical";
const alert_info = ref(null);
const chart = ref(null);
const table_flows = ref(null);
const modal_traffic_extraction = ref(null);
const modal_snapshot = ref(null);
const range_picker = ref(null);
const permanent_link_button = ref(null);
const modal_alerts_filter = ref(null);
const modal_acknowledge = ref(null);
const modal_delete = ref(null);
const show_pcap_download = ref(false);

const current_alert = ref(null);
const default_ifid = props.context.ifid;
const page = ref("");
const table_config_id = ref("");
const table_id = computed(() => {
    if (selected_query_preset.value?.value == null) { return table_config_id.value; }
    let id = `${table_config_id.value}_${selected_query_preset.value.value}`;
    return id;
});

const href_download_records = computed(() => {
    // add impossible if on ref variable to reload this expression every time count_page_components_reloaded.value change
    if (count_page_components_reloaded.value < 0) { throw "never run"; }
    const download_endpoint = props.context.download.endpoint;
    let params = ntopng_url_manager.get_url_object();
    let columns = table_flows.value.get_columns_defs();
    let visible_columns = columns.filter((c) => c.visible).map((c) => c.id).join(",");
    params.format = "txt";
    params.visible_columns = visible_columns;
    const url_params = ntopng_url_manager.obj_to_url_params(params);
    return `${location.origin}/${download_endpoint}?${url_params}`;
});

let chart_data_url = `${http_prefix}/lua/pro/rest/v2/get/db/ts.lua`;

const chart_style = computed(() => {
    if (props.context?.chart_type == "topk-timeseries") {
        return "height:450px!important";
    }
    return "height:300px!important";

});
const chart_type = computed(() => {
    /* Chart type defined the json template (defaults in db_search.lua) */
    if (props.context?.chart_type == "topk-timeseries") {
        return ntopChartApex.typeChart.TS_STACKED;
    }
    return ntopChartApex.typeChart.TS_COLUMN;
});

const top_table_array = ref([]);
const top_table_dropdown_array = ref([]);

const selected_query_preset = ref({});
const query_presets = ref([]);
const query_presets_copy = ref([]);
const mount_range_picker = ref(false);

const flows_aggregated = ref(false);
const flow_type_label = ref(_i18n("datatable.aggregated"));
const min_time_interval_id = ref(null);
const round_time = ref(false);
const count_page_components_reloaded = ref(0)

onBeforeMount(async () => {
    init_params();
    init_url_params();
    await set_query_presets();
    ntopng_events_manager.on_event_change('range_picker', ntopng_events.EPOCH_CHANGE, (new_status) => {update_show_download_pcap(new_status);}, true);
    mount_range_picker.value = true;
});

onMounted(async () => {
    register_components_on_status_update();
    load_top_table_array_overview();
});

function init_params() {
    page.value = ntopng_url_manager.get_url_entry("page");
    if (page.value == null) { page.value = "overview"; }
    chart_data_url = `${http_prefix}/lua/pro/rest/v2/get/db/ts.lua`;

    selected_query_preset.value = {
        value: ntopng_url_manager.get_url_entry("query_preset"),
    };
    if (selected_query_preset.value.value == null) {
        selected_query_preset.value.value = "";
    }
    table_config_id.value = `flow_historical`;
    const aggregated = ntopng_url_manager.get_url_entry("aggregated");
    if (aggregated == "true") {
        table_config_id.value = `flow_historical_aggregated`;
        flows_aggregated.value = true;
        min_time_interval_id.value = "hour";
        round_time.value = true;
    }
}

function init_url_params() {
    if (ntopng_url_manager.get_url_entry("ifid") == null) {
        ntopng_url_manager.set_key_to_url("ifid", default_ifid);
    }
    // 30 min default
    // chiamare set default_time interval
    if (flows_aggregated.value == false) {
        ntopng_utility.check_and_set_default_time_interval();
    }
    else {
        const f_check_last_minute_epoch_end = (epoch) => {
            let min_time_interval = ntopng_utility.get_timeframe_from_timeframe_id(min_time_interval_id.value);
            return epoch.epoch_end - epoch.epoch_begin < min_time_interval;
        };
        const epoch_interval = ntopng_utility.check_and_set_default_time_interval(min_time_interval_id.value, f_check_last_minute_epoch_end);
        if (epoch_interval != null) {
            epoch_interval.epoch_begin = ntopng_utility.round_time_by_timeframe_id(epoch_interval.epoch_begin, min_time_interval_id.value);
            epoch_interval.epoch_end = ntopng_utility.round_time_by_timeframe_id(epoch_interval.epoch_end, min_time_interval_id.value);
            ntopng_url_manager.set_key_to_url("epoch_begin", epoch_interval.epoch_begin);
            ntopng_url_manager.set_key_to_url("epoch_end", epoch_interval.epoch_end);
        }
    }

    if (ntopng_url_manager.get_url_entry("page") == "flow"
        && ntopng_url_manager.get_url_entry("status") == "engaged") {
        ntopng_url_manager.set_key_to_url("status", "historical");
    }
    if (ntopng_url_manager.get_url_entry("aggregated") == null) {
        ntopng_url_manager.set_key_to_url("aggregated", "false");
    }

}

function get_chart_config_from_preset_const(preset_const) {
    let chart = preset_const?.chart;
    if (chart != null && chart.length > 0) {
        return chart[0];
    }
    return {};
}

async function set_query_presets() {
    let url_request = `${http_prefix}/lua/pro/rest/v2/get/db/preset/consts.lua?page=${page.value}&aggregated=${flows_aggregated.value}`;
    let res = await ntopng_utility.http_request(url_request);

    query_presets.value = res[0].list.map((el) => {
        let chart_config = get_chart_config_from_preset_const(el);
        return {
            value: el.id, //== null ? "flow" : el.id,
            name: el.name,
            count: chart_config?.params?.count,
            chart_config: chart_config,
            builtin: true,
        };
    });
    if (res.length > 1) {
        res[1].list.forEach((el) => {
            let chart_config = get_chart_config_from_preset_const(el);
            let query = {
                value: el.id,
                name: el.name,
                count: chart_config?.params?.count,
                chart_config: chart_config,
                is_preset: true,
            };
            query_presets.value.push(query);
        });
    }
    if (selected_query_preset.value == null || selected_query_preset.value.value == "") {
        selected_query_preset.value = query_presets.value[0];
    } else {
        let q = query_presets.value.find((i) => i.value == selected_query_preset.value.value);
        selected_query_preset.value = q || query_presets.value[0];
    }
    ntopng_url_manager.set_key_to_url("query_preset", selected_query_preset.value.value);
    ntopng_url_manager.set_key_to_url("count", selected_query_preset.value.count);
    ntopng_sync.ready(get_query_presets_sync_key());
}

const f_map_chart_options = async (chart_options) => {
    await ntopng_sync.on_ready(get_query_presets_sync_key());
    let formatter_type = selected_query_preset.value.chart_config?.unit_measure;
    if (formatter_type == null) {
        formatter_type = "number";
    }
    chart_options.yaxis.labels.formatter = FormatterUtils.getFormatter(formatter_type);
    return chart_options;
};

function change_flow_type() {
    // if (flows_aggregated.value == false) {
    // 	ntopng_url_manager.delete_params(["aggregated"]);	
    // 	table_config_id.value = "flow_historical";
    // } else {
    // 	ntopng_url_manager.set_key_to_url("aggregated", "true");
    // 	table_config_id.value = "flow_historical_aggregated";
    // }
    // refresh_page_components(true);
    // load_top_table_array_overview();

    // currently we can't refresh component without reload the page because we need refresh props.context
    if (flows_aggregated.value == false) {
        ntopng_url_manager.delete_params(["aggregated"]);
    } else {
        ntopng_url_manager.set_key_to_url("aggregated", "true");
    }
    ntopng_url_manager.reload_url();
}

function update_select_query_presets() {
    let url = ntopng_url_manager.get_url_params();
    ntopng_url_manager.set_key_to_url("query_preset", selected_query_preset.value.value);
    ntopng_url_manager.set_key_to_url("count", selected_query_preset.value.count);
    ntopng_url_manager.reload_url();
}

async function load_top_table_array_overview(action) {
    if (props.context.show_cards != true) { return; }
    top_table_array.value = await load_top_table_array("overview");
}

async function load_top_table_details(top, top_index) {
    top.show_spinner = true;
    await nextTick();
    if (top.data_loaded == false) {
        let new_top_array = await load_top_table_array(top.id, top);
        top.options = new_top_array.find((t) => t.id == top.id).options;
        await nextTick();
        let dropdown = top_table_dropdown_array.value[top_index];
        dropdown.load_menu();
    }
    top.show_spinner = false;
}

async function load_top_table_array(action, top) {
    // top_table.value = [];
    const url_params = ntopng_url_manager.get_url_params();
    const url = `${http_prefix}/lua/pro/rest/v2/get/flow/top.lua?${url_params}&action=${action}`;
    let res = await ntopng_utility.http_request(url);
    return res.map((t) => {
        return {
            id: t.action || t.name,
            label: t.label,
            title: t.tooltip,
            show_spinner: false,
            data_loaded: action != 'overview',
            options: t.value,
        };
    });
}

const get_open_top_table_dropdown = (top, top_index) => {
    return (d) => {
        load_top_table_details(top, top_index);
    };
};
function update_show_download_pcap(new_status) {
   const tmp_begin_epoch = new_status.epoch_begin;
   const tmp_end_epoch = new_status.epoch_end;
   const w_first_epoch = props.context.n2disk_window_first_epoch;
   const w_last_epoch = props.context.n2disk_window_last_epoch;
   show_pcap_download.value = tmp_begin_epoch >= w_first_epoch && 
                              tmp_begin_epoch <= w_last_epoch && 
                              tmp_end_epoch >= w_first_epoch && 
                              tmp_end_epoch <= w_last_epoch;
}

async function register_components_on_status_update() {
    await ntopng_sync.on_ready("range_picker");
    if (props.context.show_chart) {
        chart.value.register_status();
    }
    //updateDownloadButton();
    ntopng_status_manager.on_status_change(page.value, (new_status) => {
        let url_params = ntopng_url_manager.get_url_params();
        table_flows.value.refresh_table();
        load_top_table_array_overview();
        count_page_components_reloaded.value += 1;
    }, false);
}

function on_table_loaded() {
    register_table_flows_events();
}

function register_table_flows_events() {
    let jquery_table_flows = $(`#${table_id.value}`);
    jquery_table_flows.on('click', `a.tag-filter`, async function (e) {
        add_table_row_filter(e, $(this));
    });
}

const map_table_def_columns = async (columns) => {
    await ntopng_sync.on_ready(get_query_presets_sync_key());
    let html_ref = '';
    let location = '';
    const f_print_asn = (key, asn, row) => {
        if (asn !== undefined && asn.value != 0) {
            return `<a class='tag-filter' data-tag-key='${key}' data-tag-value='${asn.value}' title='${asn.title}' href='javascript:void(0)'>${asn.label}</a>`;
        }
        return "";
    };
    const f_print_latency = (key, latency, row) => {
        if (latency == null || latency == 0) { return ""; }
        return `<a class='tag-filter' data-tag-key='${key}' data-tag-value='${latency}' href='javascript:void(0)'>${NtopUtils.msecToTime(latency)}</a>`;
    };
    const f_print_state = (key, state, row) => {
        if (state == null || state == 0) { return ""; }
        return `<a class='tag-filter' data-tag-key='${key}' data-tag-value='${state.value}' href='javascript:void(0)'>${state.title}</a>`;

    }
    let map_columns = {
        "first_seen": (first_seen, row) => {
            if (first_seen !== undefined)
                return first_seen.time;
        },
        "DURATION": (duration, row) => {
            return NtopUtils.secondsToTime(duration)
        },
        "THROUGHPUT": (throughput, row) => {
            return FormatterUtils.getFormatter("bps_no_scale")(throughput);
        },
        "l7proto": (proto, row) => {
            let confidence = "";
            if (proto.confidence !== undefined) {
                const title = proto.confidence;
                (title == "DPI") ? confidence = `<span class="badge bg-success" title="${title}">${title}</span>` : confidence = `<span class="badge bg-warning" title="${title}">${title}</span>`
            }
            return DataTableRenders.filterize('l7proto', proto.value, proto.label) + " " + `${confidence}`;
        },
        "asn": (asn, row) => f_print_asn("asn", asn, row),
        "cli_asn": (cli_asn, row) => f_print_asn("cli_asn", cli_asn, row),
        "srv_asn": (srv_asn, row) => f_print_asn("srv_asn", srv_asn, row),
        "flow_risk": (flow_risks, row) => {
            if (flow_risks == null) { return ""; }
            let res = [];

            for (let i = 0; i < flow_risks.length; i++) {
                const flow_risk = flow_risks[i];
                const flow_risk_label = (flow_risk.label || flow_risk.value);
                const flow_risk_help = (flow_risk.help);
                const flow_risk_remediation = (flow_risk.remediation);
                console.log(flow_risk_remediation);
                res.push(`${flow_risk_label} ${flow_risk_help} ${flow_risk_remediation}`);
            }
            return res.join(', ');
        },
        "cli_nw_latency": (cli_nw_latency, row) => f_print_latency("cli_nw_latency", cli_nw_latency, row),
        "srv_nw_latency": (srv_nw_latency, row) => f_print_latency("srv_nw_latency", srv_nw_latency, row),
        "major_connection_state": (major_connection_state, row) => f_print_state("major_connection_state", major_connection_state , row),
        "minor_connection_state": (minor_connection_state, row) => f_print_state("minor_connection_state", minor_connection_state , row),
        "pre_nat_ipv4_src_addr": (value, row) => { return DataTableRenders.filterize('pre_nat_ipv4_src_addr', value.value, value.label) },
        "pre_nat_src_port": (value, row) => { return DataTableRenders.filterize('pre_nat_src_port', value.value, value.label) },
        "pre_nat_ipv4_dst_addr": (value, row) => { return DataTableRenders.filterize('pre_nat_ipv4_dst_addr', value.value, value.label) },
        "pre_nat_dst_port": (value, row) => { return DataTableRenders.filterize('pre_nat_dst_port', value.value, value.label) },
        "post_nat_ipv4_src_addr": (value, row) => { return DataTableRenders.filterize('post_nat_ipv4_src_addr', value.value, value.label) },
        "post_nat_src_port": (value, row) => { return DataTableRenders.filterize('post_nat_src_port', value.value, value.label) },
        "post_nat_ipv4_dst_addr": (value, row) => { return DataTableRenders.filterize('post_nat_ipv4_dst_addr', value.value, value.label) },
        "post_nat_dst_port": (value, row) => { return DataTableRenders.filterize('post_nat_dst_port', value.value, value.label) },
        "info": (info, row) => {
            if (info == null) { return ""; }
            return `<a class='tag-filter' data-tag-key='info' data-tag-value='${info.title}' title='${info.title}' href='javascript:void(0)'>${info.label}</a>`;
        },
    };
    columns = columns.filter((c) => props.context?.visible_columns[c.data_field] != false);
    if (selected_query_preset.value.is_preset && columns.length > 0) {
        // add action button that is the first button
        columns = [columns[0]].concat(props.context.columns_def);
    }

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];

        if (c.id == "actions") {
            const visible_dict = {
                info: props.context.actions.show_info,
                historical_data: props.context.actions.show_historical,
                flow_alerts: props.context.actions.show_alerts,
                pcap_download: props.context.actions.show_pcap_download,
                row_data: props.context.is_enterprise_xl && flows_aggregated.value,
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class) => {
                    // if is not defined is enabled
                    if (b.id == 'pcap_download' && show_pcap_download.value === false) {
                        current_class.push("link-disabled");
                    } else if (visible_dict[b.id] != null && visible_dict[b.id] == false) {
                        current_class.push("link-disabled");
                    }
                    return current_class;
                }
            });
        }
    });
    // console.log(columns);
    return columns;
};

const add_table_row_filter = (e, a) => {
    e.stopPropagation();

    let key = undefined;
    let displayValue = undefined;
    let realValue = undefined;
    let operator = 'eq';

    // Read tag key and value from the <a> itself if provided
    if (a.data('tagKey') != undefined) key = a.data('tagKey');
    if (a.data('tagRealvalue') != undefined) realValue = a.data('tagRealvalue');
    else if (a.data('tagValue') != undefined) realValue = a.data('tagValue');
    if (a.data('tagOperator') != undefined) operator = a.data('tagOperator');

    let filter = {
        id: key,
        value: realValue,
        operator: operator,
    };
    add_filter(filter);
}

function add_top_table_filter(opt, event) {
    event.stopPropagation();
    let filter = {
        id: opt.key,
        value: opt.value,
        operator: opt.operator,
    };
    add_filter(filter);
}

function add_filter(filter) {
    if (range_picker.value.is_filter_defined(filter)) {
        ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_MODAL_FILTERS, filter);
    } else {
        ntopng_url_manager.set_key_to_url("query_preset", "");
        ntopng_url_manager.set_key_to_url(filter.id, `${filter.value};${filter.operator}`);
        ntopng_url_manager.reload_url();
    }
}

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

function click_navbar_item(item) {
    ntopng_url_manager.set_key_to_url('page', item.page_name);
    ntopng_url_manager.reload_url();
}

function show_modal_alerts_filter(alert) {
    current_alert.value = alert;
    modal_alerts_filter.value.show();
}

function get_permanent_link() {
    const $this = $(permanent_link_button.value);
    const placeholder = document.createElement('input');
    placeholder.value = location.href;
    document.body.appendChild(placeholder);
    placeholder.select();

    // copy the url to the clipboard from the placeholder
    document.execCommand("copy");
    document.body.removeChild(placeholder);
    $this.attr("title", `${_i18n('copied')}!`)
        .tooltip("dispose")
        .tooltip()
        .tooltip("show");
}

function show_modal_traffic_extraction() {
    modal_traffic_extraction.value.show();
}

function show_modal_snapshot() {
    modal_snapshot.value.show();
}

async function add_exclude(params) {
    params.csrf = props.context.csrf;
    let url = `${http_prefix}/lua/pro/rest/v2/add/alert/exclusion.lua`;
    try {
        let headers = {
            'Content-Type': 'application/json'
        };
        await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
        let url_params = ntopng_url_manager.get_url_params();
        setTimeout(() => {
            //todo reloadTable($table, url_params);
            ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_GLOBAL_ALERT_INFO, { text_html: _i18n('check_exclusion.disable_warn'), type: "alert-info", timeout: 2 });
        }, 1000);
    } catch (err) {
        console.error(err);
    }
}

function refresh_page_components(not_refresh_table) {
    let t = table_flows.value;
    let c = chart.value;
    setTimeout(() => {
        if (!not_refresh_table) {
            t.refresh_table();
        }
        c.update_chart();
    }, 1 * 1000);
}

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_info": click_button_info,
        "click_button_flow_alerts": click_button_flow_alerts,
        "click_button_historical_flows": click_button_historical_flows,
        "click_button_pcap_download": click_button_pcap_download,
        "click_button_flows": click_button_flows,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

function click_button_info(event) {
    const flow = event.row;
    const href = `${http_prefix}/lua/pro/db_flow_details.lua?row_id=${flow.rowid}&tstamp=${flow.tstamp}&instance_name=${flow.NTOPNG_INSTANCE_NAME}`;
    window.open(href, "_blank");
}

function click_button_pcap_download(event) {
    const flow = event.row;
    const epoch_interval = { epoch_begin: flow?.filter?.epoch_begin, epoch_end: flow?.filter?.epoch_end };
    modal_traffic_extraction.value.show(flow?.filter?.bpf, epoch_interval);
}

function click_button_historical_flows(event) {
    const flow = event.row;
    let filters_params_object = {};
    for (let key in flow) {
        let filter_key = key;
        if (flow[key].tag_key != null && flow[key].tag_key != "") {
            filter_key = flow[key].tag_key;
        }
        if (flow[key].value == null && flow[key].value != "") { continue; }
        let filter = `${flow[key].value};eq`;
        filters_params_object[filter_key] = filter;
    }
    ntopng_url_manager.set_key_to_url("query_preset", "");
    ntopng_url_manager.add_obj_to_url(filters_params_object);
    ntopng_url_manager.reload_url();
}

function click_button_flow_alerts(event) {
    const flow = event.row;
    if (flow.alerts_url) {
        ntopng_url_manager.go_to_url(flow.alerts_url);
    }
}

function click_button_flows(event) {
    const row_data = event.row;
    const epoch_begin = row_data.filter.epoch_begin;
    const epoch_end = row_data.filter.epoch_end;
    const cli_ip = row_data.flow.cli_ip.value;
    const srv_ip = row_data.flow.srv_ip.value;
    const srv_port = row_data.flow.srv_port;
    const probe_ip = row_data.probe_ip.value;
    const instance_name = row_data.NTOPNG_INSTANCE_NAME;

    const vlan_id = row_data.vlan_id.value;
    let as_vlan = vlan_id != 0;

    const output_snmp = row_data.output_snmp.value;
    let as_output_snmp = output_snmp != 0;
    const input_snmp = row_data.input_snmp.value;
    let as_input_snmp = input_snmp != 0;

    let url = `${http_prefix}/lua/pro/db_search.lua?aggregated=false&epoch_begin=${epoch_begin}&epoch_end=${epoch_end}&cli_ip=${cli_ip};eq&srv_ip=${srv_ip};eq&srv_port=${srv_port};eq&probe_ip=${probe_ip};eq&instance_name=${instance_name}`;
    if (as_vlan) {
        url = url + `&vlan_id=${vlan_id};eq`;
    }

    if (as_input_snmp) {
        url = url + `&input_snmp=${input_snmp};eq`;
    }

    if (as_output_snmp) {
        url = url + `&output_snmp=${output_snmp};eq`;
    }

    ntopng_url_manager.go_to_url(url);
}

function get_query_presets_sync_key() {
    return `${page_id}_query_presets`;
}

function get_status_view() {
    let status_view = ntopng_url_manager.get_url_entry("status");
    if (status_view == null || status_view == "") {
        status_view = "historical";
    }
    return status_view;
}

</script>

<style scoped></style>
