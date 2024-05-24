<!-- (C) 2022 - ntop.org     -->
<template>
    <div class="col-12 mb-2 mt-2">
        <AlertInfo></AlertInfo>
        <div class="card h-100 overflow-hidden">
            <DateTimeRangePicker style="margin-top:0.5rem;" class="ms-1" :id="id_date_time_picker" :enable_refresh="true"
                ref="date_time_picker" @epoch_change="epoch_change" :min_time_interval_id="min_time_interval_id"
                :custom_time_interval_list="time_preset_list">
                <template v-slot:begin>
                </template>
                <template v-slot:extra_buttons>
                    <button v-if="enable_snapshots" class="btn btn-link btn-sm" @click="show_modal_snapshot"
                        :title="_i18n('page_stats.manage_snapshots_btn')"><i class="fas fa-lg fa-camera-retro"></i></button>
                    <button v-if="traffic_extraction_permitted" class="btn btn-link btn-sm"
                        @click="show_modal_traffic_extraction" :title="_i18n('traffic_recording.pcap_download')"><i
                            class="fas fa-lg fa-download"></i></button>
                    <button :disabled="is_safari" class="btn btn-link btn-sm" @click="show_modal_download_file"
                        :title="image_button_title"><i
                            class="fas fa-lg fa-file-image"></i></button>
                    <button v-if="is_history_enabled" class="btn btn-link btn-sm" @click="jump_to_historical_flows"
                        :title="_i18n('page_stats.historical_flows')"><i class="fas fa-search-plus"></i></button>
                </template>
            </DateTimeRangePicker>
            <!-- select metric -->
            <div v-show="ts_menu_ready" class="form-group ms-1 mt-2 d-flex align-items-center">
                <div class="inline select2-size me-2">
                    <SelectSearch v-model:selected_option="selected_metric" :options="metrics"
                        @select_option="select_metric">
                    </SelectSearch>
                </div>
                <div class="inline select2-size me-2">
                    <SelectSearch v-model:selected_option="current_groups_options_mode" :options="groups_options_modes"
                        @select_option="change_groups_options_mode">
                    </SelectSearch>
                </div>
                <button type="button" @click="show_manage_timeseries" class="btn btn-sm btn-primary inline"
                    style='vertical-align: super;' v-if="is_ntop_pro">
                    Manage Timeseries
                </button>

            </div>

            <template v-for="(item, i) in charts_options_items" :key="item.key">
                <TimeseriesChart :id="id_chart + i" :ref="el => { charts[i] = el }" :chart_type="chart_type"
                    :register_on_status_change="false" :get_custom_chart_options="get_f_get_custom_chart_options(i)"
                    @zoom="epoch_change" @chart_reloaded="chart_reloaded">
                </TimeseriesChart>
            </template>
        </div>

        <div class="mt-4 card card-shadow" v-if="enable_stats_table">
            <div class="card-body">
                <BootstrapTable id="page_stats_bootstrap_table" :columns="stats_columns" :rows="stats_rows"
                    :print_html_column="(col) => print_stats_column(col)"
                    :print_html_row="(col, row) => print_stats_row(col, row)">
                </BootstrapTable>
            </div>
        </div>

        <div class="mt-4 card card-shadow" v-if="is_ntop_pro">
            <div class="card-body">
                <div v-if="selected_top_table?.table_config_def" class="inline select2-size me-2 mt-2">
                    <SelectSearch v-model:selected_option="selected_top_table" :options="top_table_options">
                    </SelectSearch>
                </div>
                <Datatable v-if="selected_top_table?.table_config_def" :key="selected_top_table?.value" ref="top_table_ref"
                    :table_buttons="selected_top_table.table_config_def.table_button"
                    :columns_config="selected_top_table.table_config_def.columns_config"
                    :data_url="selected_top_table.table_config_def.data_url"
                    :enable_search="selected_top_table.table_config_def.enable_search"
                    :table_config="selected_top_table.table_config_def.table_config">
                </Datatable>
            </div>
        </div>
    </div>

    <ModalSnapshot v-if="enable_snapshots" ref="modal_snapshot" :csrf="csrf" :page="page_snapshots"
        @added_snapshot="refresh_snapshots" @deleted_snapshots="refresh_snapshots"
        @deleted_all_snapshots="refresh_snapshots">
    </ModalSnapshot>

    <ModalTimeseries v-if="is_ntop_pro" ref="modal_timeseries" :sources_types_enabled="sources_types_enabled"
        @apply="apply_modal_timeseries">
    </ModalTimeseries>

    <ModalTrafficExtraction id="page_stats_modal_traffic_extraction" ref="modal_traffic_extraction">
    </ModalTrafficExtraction>

    <ModalDownloadFile ref="modal_download_file" :title="_i18n('page_stats.title_modal_download_file')" ext="png"
        @download="download_chart_png">
    </ModalDownloadFile>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, watch } from "vue";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as ModalDownloadFile } from "./modal-download-file.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as dataUtils } from "../utilities/data-utils.js";

import { default as SelectSearch } from "./select-search.vue";
import { default as Datatable } from "./datatable.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";
import timeseriesUtils from "../utilities/timeseries-utils.js";
import metricsManager from "../utilities/metrics-manager.js";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";

const props = defineProps({
    csrf: String,
    is_ntop_pro: Boolean,
    source_value_object: Object,
    sources_types_enabled: Object,
    sources_types_top_enabled: Object,
    enable_snapshots: Boolean,
    is_history_enabled: Boolean,
    traffic_extraction_permitted: Boolean,
    is_dark_mode: Boolean,
});

//ntopng_utility.check_and_set_default_time_interval();

const _i18n = (t) => i18n(t);
let id_chart = "chart";
let id_date_time_picker = "date_time_picker";
let chart_type = ntopChartApex.typeChart.TS_LINE;
const config_app_table = ref({});
const init_config_table = ref(false);
const charts = ref([]);
const date_time_picker = ref(null);
const top_table_ref = ref(null);
const modal_timeseries = ref(null);
const modal_snapshot = ref(null);
const modal_download_file = ref(null);

const is_safari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
const image_button_title = is_safari ? _i18n('page_stats.download_image_disabled') : _i18n('page_stats.title_modal_download_file');

const min_time_interval_id = ref(null);
const metrics = ref([]);
const selected_metric = ref({});
const source_type = metricsManager.get_current_page_source_type();

const enable_stats_table = ref(false);
const enable_top_table = ref(false);

/**
 * { key: identifier of Chart component, if change Chart will be destroyed and recreated,
 *  chart_options: chart options }[]
 **/
const charts_options_items = ref([]);

/**
 * Modes that represent how it's possible display timeseries.
 */
const groups_options_modes = ntopng_utility.object_to_array(timeseriesUtils.groupsOptionsModesEnum);
/**
 * Current display timeseries mode.
 */
const current_groups_options_mode = ref(init_groups_option_mode());

let last_timeseries_groups_loaded = null;

const custom_metric = { label: i18n('page_stats.custom_metrics'), currently_active: false };

const page_snapshots = "timeseries";

const ts_menu_ready = ref(false);
const time_preset_list = [
    { value: "10_min", label: i18n('show_alerts.presets.10_min'), currently_active: false },
    { value: "30_min", label: i18n('show_alerts.presets.30_min'), currently_active: true },
    { value: "hour", label: i18n('show_alerts.presets.hour'), currently_active: false },
    { value: "2_hours", label: i18n('show_alerts.presets.2_hours'), currently_active: false },
    { value: "6_hours", label: i18n('show_alerts.presets.6_hours'), currently_active: false },
    { value: "12_hours", label: i18n('show_alerts.presets.12_hours'), currently_active: false },
    { value: "day", label: i18n('show_alerts.presets.day'), currently_active: false },
    { value: "week", label: i18n('show_alerts.presets.week'), currently_active: false },
    { value: "month", label: i18n('show_alerts.presets.month'), currently_active: false },
    { value: "year", label: i18n('show_alerts.presets.year'), currently_active: false },
    { value: "custom", label: i18n('show_alerts.presets.custom'), currently_active: false, disabled: true, },
];

function init_groups_option_mode() {
    let groups_mode = ntopng_url_manager.get_url_entry("timeseries_groups_mode");
    if (groups_mode != null && groups_mode != "") {
        return timeseriesUtils.getGroupOptionMode(groups_mode);
    }
    return groups_options_modes[0];
}

function set_default_source_object_in_url() {
    if (props.source_value_object == null) { return; }
    let source_type = metricsManager.get_current_page_source_type();
    metricsManager.set_source_value_object_in_url(source_type, props.source_value_object);
}

onBeforeMount(async () => {
    
    if (ntopng_url_manager.get_url_entry("page") == "va_historical") {
        let columns_tmp = [];
        stats_columns.forEach((item) => {
            if (item.va) {
                columns_tmp.push(item);
            }
        })
        
        stats_columns = columns_tmp;
    }
    
    if (props.source_value_object.is_va) {
        min_time_interval_id.value = "hour";
        ntopng_utility.check_and_set_default_time_interval("day");
    };
    
    set_default_source_object_in_url();
});

onMounted(async () => {
    init();
    await Promise.all([
        ntopng_sync.on_ready(id_date_time_picker),
    ]);
    // chart.value.register_status();
});

async function init() {
    //get_default_timeseries_groups
    let push_custom_metric = true;
    let timeseries_groups = await metricsManager.get_timeseries_groups_from_url(http_prefix);
    let metric_ts_schema;
    let metric_query;
    if (timeseries_groups == null) {
        push_custom_metric = false;
        metric_ts_schema = ntopng_url_manager.get_url_entry("ts_schema");
        let ts_query = ntopng_url_manager.get_url_entry("ts_query");
        if (ts_query != null && ts_query != "") {
            metric_query = metricsManager.get_metric_query_from_ts_query(ts_query);
        }
        if (metric_ts_schema == "") { metric_ts_schema = null; }
        timeseries_groups = await metricsManager.get_default_timeseries_groups(http_prefix, metric_ts_schema, metric_query);
    }
    metrics.value = await get_metrics(push_custom_metric);
    
    if (push_custom_metric == true) {
        selected_metric.value = custom_metric;
    } else {
        selected_metric.value = metricsManager.get_default_metric(metrics.value, metric_ts_schema, metric_query);
    }
    ts_menu_ready.value = true;
    await load_page_stats_data(timeseries_groups, true, true);
}

let last_push_custom_metric = null;
async function get_metrics(push_custom_metric, force_refresh) {
    let metrics = await metricsManager.get_metrics(http_prefix);
    if (!force_refresh && last_push_custom_metric == push_custom_metric) { return metrics.value; }
    
    if (push_custom_metric) {
        metrics.push(custom_metric);
    }
    if (cache_snapshots == null || force_refresh) {
        cache_snapshots = await get_snapshots_metrics();
    }
    if (props.enable_snapshots) {
        let snapshots_metrics = cache_snapshots;
        snapshots_metrics.forEach((sm) => metrics.push(sm));
    }
    /* Order Metrics */
    if (metrics.length > 0)
        metrics.sort(NtopUtils.sortAlphabetically);
    
    return metrics;
}

async function get_snapshots_metrics() {
    if (!props.enable_snapshots) { return; }
    let url = `${http_prefix}/lua/pro/rest/v2/get/filters/snapshots.lua?page=${page_snapshots}`;
    
    let snapshots_obj = await ntopng_utility.http_request(url);
    let snapshots = ntopng_utility.object_to_array(snapshots_obj);
    let metrics_snapshots = snapshots.map((s) => {
        return {
            ...s,
            is_snapshot: true,
            label: `${s.name}`,
            group: "Snapshots",
        };
    });
    return metrics_snapshots;
}

async function get_selected_timeseries_groups() {
    let metric = selected_metric.value;
    return get_timeseries_groups_from_metric(metric);
}

async function get_timeseries_groups_from_metric(metric) {
    let source_type = metricsManager.get_current_page_source_type();
    let source_array = await metricsManager.get_default_source_array(http_prefix, source_type);
    let ts_group = metricsManager.get_ts_group(source_type, source_array, metric);
    let timeseries_groups = [ts_group];
    return timeseries_groups;
}

const add_ts_group_from_source_value_dict = async (source_type_id, source_value_dict, metric_schema) => {
    let source_type = metricsManager.get_source_type_from_id(source_type_id);
    let source_array = await metricsManager.get_source_array_from_value_dict(http_prefix, source_type, source_value_dict);
    let metric = await metricsManager.get_metric_from_schema(http_prefix, source_type, source_array, metric_schema);
    let ts_group = metricsManager.get_ts_group(source_type, source_array, metric);
    add_ts_group(ts_group);
};

const add_metric_from_metric_schema = async (metric_schema, metric_query) => {
    let metric = metrics.value.find((m) => m.schema == metric_schema && m.query == metric_query);
    if (metric == null) {
        console.error(`metric = ${metric_schema}, query = ${metric_query} not found.`);
        return;
    }
    let timeseries_groups = await get_timeseries_groups_from_metric(metric);
    // modal_timeseries.value.set_timeseries_groups(last_timeseries_groups_loaded);
    // modal_timeseries.value.add_ts_group(timeseries_groups[0], true);
    add_ts_group(timeseries_groups[0]);
};

function add_ts_group(ts_group) {
    modal_timeseries.value.set_timeseries_groups(last_timeseries_groups_loaded);
    modal_timeseries.value.add_ts_group(ts_group, true);
}

async function select_metric(metric) {
    if (metric.is_snapshot == true) {
        let url_parameters = metric.filters;
        let timeseries_url_params = ntopng_url_manager.get_url_entry("timeseries_groups", url_parameters);
        let timeseries_groups = await metricsManager.get_timeseries_groups_from_url(http_prefix, timeseries_url_params);
        current_groups_options_mode.value = timeseriesUtils.getGroupOptionMode(ntopng_url_manager.get_url_entry("timeseries_groups_mode", url_parameters));
        await load_page_stats_data(timeseries_groups, true, false);
    } else {
        await load_selected_metric_page_stats_data();
        refresh_metrics(false);
    }
}

async function load_selected_metric_page_stats_data() {
    let timeseries_groups = await get_selected_timeseries_groups();
    await load_page_stats_data(timeseries_groups, true, false);
}

function epoch_change(new_epoch) {
    let push_custom_metric = selected_metric.value.label == custom_metric.label;
    load_page_stats_data(last_timeseries_groups_loaded, true, false, new_epoch.refresh_data);
    refresh_top_table();
    refresh_metrics(push_custom_metric, true);
}

function chart_reloaded(chart_options) {
}

function show_modal_snapshot() {
    modal_snapshot.value.show();
}

function show_manage_timeseries() {
    if (last_timeseries_groups_loaded == null) { return; }
    modal_timeseries.value.show(last_timeseries_groups_loaded);
};

/**
 * Function called by Chart component to draw or update that return chart options.
 **/
function get_f_get_custom_chart_options(chart_index) {
    return async (url) => {
        return charts_options_items.value[chart_index].chart_options;
    }
}

let cache_snapshots = null;
function refresh_snapshots() {
    let push_custom_metric = selected_metric.value.label == custom_metric.label;
    refresh_metrics(push_custom_metric, true);
}

async function refresh_metrics(push_custom_metric, force_refresh) {
    metrics.value = await get_metrics(push_custom_metric, force_refresh);
    if (push_custom_metric) {
        selected_metric.value = custom_metric;
    }
}

async function apply_modal_timeseries(timeseries_groups) {
    refresh_metrics(true);
    await load_page_stats_data(timeseries_groups, true, true);
}

function change_groups_options_mode() {
    load_page_stats_data(last_timeseries_groups_loaded, false, false);
}

let ts_charts_options;
/* This function load the chart data and options, doing the request and then setting the options */
async function load_page_stats_data(timeseries_groups, reload_charts_data, reload_top_table_options, refreshed_time_interval) {
    /* Get the information necessary for the request, like epoch ecc. */
    let status = ntopng_status_manager.get_status();
    let ts_compare = get_ts_compare(status);
    if (reload_charts_data) {
        /* Do the request to the backend; the answer is formatted as
         *  [  
         *      {   
         *          metadata: { ... }       // Containing various info regarding the series returned
         *          series: { ... }         // Containing the series with the data, labels and statistics
         *      }
         *  ]
         */
        if (timeseries_groups == null) {
            timeseries_groups = [];
            console.warn("Empty timeseries_groups request");
            return;
        }
        ts_charts_options = await timeseriesUtils.getTsChartsOptions(http_prefix, status, ts_compare, timeseries_groups, props.is_ntop_pro);
    }

    /* Update timeseries label to display */
    set_timeseries_groups_source_label(timeseries_groups, ts_charts_options);

    /* Format the options for the timeseries library */
    let charts_options = timeseriesUtils.tsArrayToOptionsArray(ts_charts_options, timeseries_groups, current_groups_options_mode.value, ts_compare);
    if (refreshed_time_interval) {
        update_charts(charts_options);
    } else {
        set_charts_options_items(charts_options);
    }
    set_stats_rows(ts_charts_options, timeseries_groups, status);
    if (reload_top_table_options) {
        set_top_table_options(timeseries_groups, status);
    }
    // set last_timeseries_groupd_loaded
    last_timeseries_groups_loaded = timeseries_groups;
    // update url params
    update_url_params();
}

/* This function returns set the label of the timeseries; if available it should be
 * found in response.metadata.label field
 */
function set_timeseries_groups_source_label(timeseries_groups, ts_charts_options) {
    timeseries_groups.forEach((ts_group, i) => {
        let ts_options = ts_charts_options[i];
        let label = ts_options?.metadata?.label;
        if (label != null) {
            let source_index = timeseriesUtils.getMainSourceDefIndex(ts_group);
            let source = ts_group.source_array[source_index];
            source.label = label;
        }
    });
}

function update_url_params() {
    ntopng_url_manager.set_key_to_url("timeseries_groups_mode", current_groups_options_mode.value.value);
    metricsManager.set_timeseries_groups_in_url(last_timeseries_groups_loaded);
}

function update_charts(charts_options) {
    charts_options.forEach((options, i) => {
        // charts.value[i].update_chart_options({ yaxis: options.yaxis });
        charts.value[i].update_chart_series(options?.serie);
    });
}

function set_charts_options_items(charts_options) {
    charts_options_items.value = charts_options.map((options, i) => {
        return {
            key: ntopng_utility.get_random_string(),
            chart_options: options,
        };
    });
}

function get_ts_compare(status) {
    // 5m, 30m, 1h, 1d, 1w, 1M, 1Y
    let r = Number.parseInt((status.epoch_end - status.epoch_begin) / 60);
    if (r <= 5) {
        return "5m";
    } else if (r <= 30) {
        return "30m";
    } else if (r <= 60) {
        return "1h";
    } else if (r <= 60 * 24) {
        return "1d";
    } else if (r <= 60 * 24 * 7) {
        return "1w";
    } else if (r <= 60 * 24 * 30) {
        return "1M";
    } else {
        return "1Y";
    }
}

function get_top_table_url(ts_group, table_value, table_view, table_source_def_value_dict, status) {
    if (status == null) {
        status = ntopng_status_manager.get_status();
    }
    let ts_query = timeseriesUtils.getTsQuery(ts_group, true, table_source_def_value_dict);
    let v = table_value;
    let data_url = `${http_prefix}/lua/pro/rest/v2/get/${v}/top/ts_stats.lua`;
    //todo: get ts_query
    let p_obj = {
        zoom: '5m',
        ts_query,
        // ts_query: `ifid:${ntopng_url_manager.get_url_entry('ifid')}`,
        epoch_begin: `${status.epoch_begin}`,
        epoch_end: `${status.epoch_end}`,
        detail_view: `${table_view}`,
        new_charts: `true`
    };

    let p_url_request = ntopng_url_manager.add_obj_to_url(p_obj, '');
    return `${data_url}?${p_url_request}`;
}

async function refresh_top_table() {
    if (!props.is_ntop_pro) { return; }
    let table_config = selected_top_table.value?.table_config_def;
    if (table_config == null) { return; }
    // NtopUtils.showOverlays();
    let data_url = get_top_table_url(table_config.ts_group, table_config.table_def.table_value, table_config.table_def.view, table_config.table_source_def_value_dict);
    top_table_ref.value.update_url(data_url);
    top_table_ref.value.reload();
    // NtopUtils.hideOverlays();

}

const top_table_options = ref([]);
const selected_top_table = ref({});
function set_top_table_options(timeseries_groups, status) {
    if (!props.is_ntop_pro) { return; }
    if (timeseries_groups == null) {
        timeseries_groups = last_timeseries_groups_loaded;
    }
    if (status == null) {
        status = ntopng_status_manager.get_status();
    }

    let sources_types_tables = metricsManager.sources_types_tables;
    let ts_group_dict = {}; // dictionary with 1 ts_group for each (source_type, source_array)
    timeseries_groups.forEach((ts_group) => {
        let source_type = ts_group.source_type;
        // let source_type_tables = sources_types_tables[source_type.id];
        // let table_source_def_value_dict = source_type_tables.table_source_def_value_dict

        let id = metricsManager.get_ts_group_id(ts_group.source_type, ts_group.source_array);
        ts_group_dict[id] = ts_group;
    });
    let top_table_id_dict = {};
    top_table_options.value = [];
    for (let id in ts_group_dict) {
        let ts_group = ts_group_dict[id];
        let main_source_index = timeseriesUtils.getMainSourceDefIndex(ts_group);
        let main_source = ts_group.source_array[main_source_index];
        let source_type = ts_group.source_type;
        let source_type_tables = sources_types_tables[source_type.id];
        if (source_type_tables == null) { continue; }

        source_type_tables.forEach((table_def) => {
            let enables_table_value = props.sources_types_top_enabled[table_def.table_value];
            if (enables_table_value == null) { return; }
            let enable_table_def = enables_table_value[table_def.view];
            if (!enable_table_def) { return; }
            let table_source_def_value_dict = table_def.table_source_def_value_dict

            let data_url = get_top_table_url(ts_group, table_def.table_value, table_def.view, table_source_def_value_dict, status);
            let table_id = metricsManager.get_ts_group_id(ts_group.source_type, ts_group.source_array, null, table_source_def_value_dict, true);
            table_id = `${table_id}_${table_def.view}`;
            if (top_table_id_dict[table_id] != null) { return; }
            top_table_id_dict[table_id] = true;

            let value = `${table_def.table_value}_${table_def.view}_${table_id}`;
            let label;
            if (table_def.f_get_label == null) {
                label = `${table_def.title} - ${source_type.label} ${main_source.label}`;
            } else {
                label = table_def.f_get_label(ts_group)
            }
            const table_config_def = {
                ts_group,
                table_def,
                // table_value: table_def.table_value,
                // table_view: table_def.view,

                table_buttons: [],
                data_url,
                enable_search: true,
                table_config: {
                    serverSide: false,
                    order: [[table_def.default_sorting_columns, 'desc']],
                    columnDefs: table_def.columnDefs || [],
                }
            };
            // it should be here in this instance the vuetify object with its properties
            table_config_def.columns_config = table_def.columns.map((column) => {
                let render_if_context = {
                    is_history_enabled: props.is_history_enabled
                };
                let c = {
                    visible: !column.render_if || column.render_if(render_if_context),
                    ...column,
                };
                if (c.className == null) { c.className = "text-nowrap"; }
                if (c.responsivePriority == null) { c.responsivePriority = 1; }
                c.render = column.render.bind({
                    add_metric_from_metric_schema,
                    add_ts_group_from_source_value_dict,
                    sources_types_enabled: props.sources_types_enabled,
                    status, source_type, source_array: ts_group.source_array,
                });
                return c;
            });
            let option = { value, label, table_config_def };
            top_table_options.value.push(option);
        });
    }
    if (selected_top_table.value != null && top_table_options.value.find((option) => option.value == selected_top_table.value.value)) {
        return;
    }

    selected_top_table.value = top_table_options.value.find((option) => option.table_config_def.default == true);
    if (selected_top_table.value == null) {
        selected_top_table.value = top_table_options.value[0];
    }
}

let stats_columns = [
    { id: "metric", label: _i18n("page_stats.metric"), va: true},
    { id: "avg", label: _i18n("page_stats.average"), class: "text-end", va: true },
    { id: "perc_95", label: _i18n("page_stats.95_perc"), class: "text-end", va: true },
    { id: "max", label: _i18n("page_stats.max"), class: "text-end", va: true},
    { id: "min", label: _i18n("page_stats.min"), class: "text-end", va: true },
    { id: "total", label: _i18n("page_stats.total"), class: "text-end", va: false },
];

const stats_rows = ref([]);

function set_stats_rows(ts_charts_options, timeseries_groups, status) {
    const extend_serie_name = ts_charts_options.length > 1;
    enable_stats_table.value = timeseries_groups.map((ts_group) => !ts_group.source_type.disable_stats).reduce((res, el) => res | el, false);
    if (!enable_stats_table.value) { return; }
    const f_get_total_formatter_type = (type) => {
        let map_type = {
            "bps": "bytes",
            "fps": "flows",
            "alertps": "alerts",
            "hitss": "hits",
            "pps": "packets",
        };
        if (map_type[type] != null) {
            return map_type[type];
        }
        return type;
    };
    stats_rows.value = [];
    ts_charts_options.forEach((options, i) => {
        let ts_group = timeseries_groups[i];
        if (ts_group.source_type.disable_stats == true) { return; }
        options.series?.forEach((s, j) => {
            let ts_id = timeseriesUtils.getSerieId(s);
            let s_metadata = ts_group.metric.timeseries[ts_id];
            let formatter = formatterUtils.getFormatter(ts_group.metric.measure_unit);
            let ts_stats;
            let name = s_metadata.label;
            if (s_metadata.hidden) {
                /* Skip in case it's requested to hide the Timeserie */
                return;
            }
            if (s_metadata.use_serie_name == true) {
                name = s.name;
            }
            if (s?.data.length > j) {
                ts_stats = s.statistics;
            }
            if (ts_stats == null) {
                return;
            }
            if (s.ext_label) {
                name = s.ext_label
            }
            name = timeseriesUtils.getSerieName(name, ts_id, ts_group, extend_serie_name);
            let total_formatter_type = f_get_total_formatter_type(ts_group.metric.measure_unit);
            let total_formatter = formatterUtils.getFormatter(total_formatter_type);
            let row = {
                metric: name,
                total: total_formatter(ts_stats.total),
                perc_95: formatter(ts_stats["95th_percentile"]),
                avg: formatter(ts_stats.average),
                max: formatter(ts_stats.max_val),
                min: formatter(ts_stats.min_val),
            };
            stats_rows.value.push(row);
        });
    });
}

function print_stats_column(col) {
    return col.label;
}

function print_stats_row(col, row) {
    let label = row[col.id];
    return label;
}

function jump_to_historical_flows() {
    let status = ntopng_status_manager.get_status();
    let params = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };
    debugger;
    /* Add the source elements to the redirect, like host, snmp, ecc. */
    if (last_timeseries_groups_loaded && last_timeseries_groups_loaded.length > 0) {
        /* Use the first element */
        const source_array = last_timeseries_groups_loaded[0].source_array
        const source_def = last_timeseries_groups_loaded[0].source_type.source_def_array
        if (source_array) {
            source_array.forEach((elem, i) => {
                if (!dataUtils.isEmptyOrNull(elem.label) && source_def[i]) {
                    const value = source_def[i].value
                    switch (value) {
                        case 'device':
                            params["probe_ip"] = `${elem.value};eq` 
                            break;
                        case 'if_index':
                        case 'port':
                            params["snmp_interface"] = `${elem.value};eq` 
                            break;
                        case 'host':
                            params["ip"] = `${elem.value};eq` 
                            break;
                        case 'mac':
                            params["mac"] = `${elem.value};eq` 
                            break;
                        case 'subnet':
                            params["network"] = `${elem.value};eq` 
                            break;
                        case 'asn':
                            params["asn"] = `${elem.value};eq` 
                            break;
                        case 'country':
                            params["country"] = `${elem.value};eq` 
                            break;
                        case 'vlan':
                            params["vlan_id"] = `${elem.value};eq` 
                            break;
                        case 'pool':
                            params["host_pool_id"] = `${elem.value};eq` 
                            break;
                        default:
                            break;
                    }
                }
            })
        }
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    const historical_url = `${http_prefix}/lua/pro/db_search.lua?${url_params}`;
    ntopng_url_manager.go_to_url(historical_url);
}

const modal_traffic_extraction = ref(null);
function show_modal_traffic_extraction() {
    modal_traffic_extraction.value.show();
}

function show_modal_download_file() {
    if (!ts_charts_options?.length) { return; }
    let ts_group = last_timeseries_groups_loaded[0];
    let filename = timeseriesUtils.getSerieName(null, null, ts_group);
    modal_download_file.value.show(filename);
}

async function download_chart_png(filename) {
    let chart_image_array_promise = charts.value.map(async (chart) => {
        let canvas = new Image();
        chart.get_image(canvas);
        return new Promise(async (resolve, reject) => {
            canvas.onload = function () {
                resolve(canvas);
            };
        });
    });
    let height = 0;
    let chart_image_array = await Promise.all(chart_image_array_promise);
    chart_image_array.forEach((image) => {
        height += image.height;
    });
    let canvas = document.createElement('canvas');
    let canvas_context = canvas.getContext('2d');
    canvas.width = chart_image_array[0].width;
    canvas.height = height;
    height = 0;
    chart_image_array.forEach((image) => {
        canvas_context.drawImage(image, 0, height, image.width, image.height);
        height += image.height;
    });
    ntopng_utility.download_URI(canvas.toDataURL(), filename);
}
</script>

<style scoped>
.inline {
    display: inline-block;
}

.select2-size {
    min-width: 18rem;
}
</style>
