<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="card h-100 overflow-hidden">
        <DateTimeRangePicker style="margin-top:0.5rem;" class="ms-1" :id="id_date_time_picker" :enable_refresh="false"
            ref="date_time_picker" @epoch_change="epoch_change" :custom_time_interval_list="time_preset_list">
        </DateTimeRangePicker>
        <div class="m-2 mt-0">
            <TimeseriesChart ref="chart" :id="chart_id" :chart_type="chart_type" :base_url_request="base_url"
                :get_custom_chart_options="get_chart_options" :register_on_status_change="false"
                :disable_pointer_events="false">
            </TimeseriesChart>
        </div>
        <div class="m-2 mb-3">
            <TableWithConfig ref="table_snmp_usage" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
                :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting"
                @custom_event="on_table_custom_event">
            </TableWithConfig>
        </div>

        <div class="card-footer">
            <NoteList :note_list="note_list"> </NoteList>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import timeseriesUtils from "../utilities/timeseries-utils.js";
import formatterUtils from "../utilities/formatter-utils";

/* ************************************** */

const props = defineProps({
    context: Object,
});

/* ************************************** */
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

const serie_name = "Congestion";
const table_snmp_usage = ref(null);
const date_time_picker = ref(null);
const table_id = ref('snmp_usage');
const chart_id = ref('snmp_usage_chart');
const csrf = props.context.csrf;
const system_interface_id = -1;
const chart = ref(null);
const chart_type = ref(ntopChartApex.typeChart.TS_LINE);
const base_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/metric/usage_chart.lua`
let id_date_time_picker = "date_time_picker";

const note_list = [
    i18n('snmp.chart_congestion_rate_note'),
    i18n('snmp.chart_congestion_link'),
    i18n('snmp.chart_congestion_configuration'),
    i18n('snmp.chart_congestion_rate_color'),
];

/* ************************************** */

const map_table_def_columns = (columns) => {
    const formatter = formatterUtils.getFormatter("percentage");
    let map_columns = {
        "ip": (value, row) => {
            const url = `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?ip=${value}`
            return `<a href=${url}>${value}</a>`
        },
        "interface": (value, row) => {
            const epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
            const epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
            const url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.ip}&snmp_port_idx=${row.ifid}&page=historical&ifid=-1&epoch_end=${epoch_end}&epoch_begin=${epoch_begin}&timeseries_groups_mode=1_chart_x_metric&timeseries_groups=snmp_interface;-1%2B${row.ip}%2B${row.ifid};snmp_if:usage;uplink=true:false:false:false|downlink=true:false:false:false`
            return `<a href=${url}>${value}</a>`
        },
        "type": (type, row) => {
            if (type == 'uplink') {
                return `${i18n('out_usage')} <i class="fa-solid fa-circle-arrow-up" style="color: #C6D9FD"></i>`
            } else {
                return `${i18n('in_usage')} <i class="fa-solid fa-circle-arrow-down" style="color: #90EE90"></i>`
            }
        },
        "speed": (value, row) => {
            const formatted_speed = formatterUtils.getFormatter("speed")(value);
            return `${formatted_speed} <a target="_blank" href='${create_config_url_link(row)}'><i class="fas fa-cog"></i></a>`
        },
        "min": (value, row) => {
            return formatter(value);
        },
        "max": (value, row) => {
            return formatter(value);
        },
        "average": (value, row) => {
            return formatter(value);
        },
        "last_value": (value, row) => {
            return formatter(value);
        },
        "congestion_rate": (value, row) => {
            return formatter(value);
        }
    };
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                historical_data: props.show_historical,
            };
            c.button_def_array.forEach((b) => {
                if (!visible_dict[b.id]) {
                    b.class.push("disabled");
                }
            });
        }
    });

    return columns;
};

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        const r0_col = r0[col.data.data_field];
        const r1_col = r1[col.data.data_field];

        /* In case the values are the same, sort by IP */
        if (r0_col == r1_col) {
            return sortingFunctions.sortByName(r0.device, r1.device, col ? col.sort : null);
        }
        if (col.id == "device_name") {
            return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
        } else if (col.id == "ip") {
            return sortingFunctions.sortByIP(r0_col, r1_col, col.sort);
        } else if (col.id == "interface") {
            return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
        } else if (col.id == "type") {
            return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
        } else if (col.id == "speed") {
            const lower_value = -1;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "min") {
            const lower_value = -1;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "max") {
            const lower_value = -1;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "average") {
            const lower_value = -1;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "congestion_rate") {
            const lower_value = -1;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "last_value") {
            const lower_value = -1;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        }
    }

    return sortingFunctions.sortByName(r0.device, r1.device, col ? col.sort : null);
}

/* ************************************** */

async function epoch_change() {
    if (table_snmp_usage.value) {
        table_snmp_usage.value.refresh_table(false);
    }

    if (chart.value) {
        const options = await get_chart_options();
        chart.value.update_chart_series(options?.data);
    }
}

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function create_config_url_link(row) {
    return `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.ip}&snmp_port_idx=${row.ifid}&page=config`
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    const epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
    const epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
    window.open(`${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.ip}&snmp_port_idx=${row.ifid}&page=historical&ifid=-1&epoch_end=${epoch_end}&epoch_begin=${epoch_begin}&timeseries_groups_mode=1_chart_x_metric&timeseries_groups=snmp_interface;-1%2B${row.ip}%2B${row.ifid};snmp_if:usage;uplink=true:false:false:false|downlink=true:false:false:false`);
}

/* ************************************** */

function click_button_device_configuration(event) {
    const row = event.row;
    window.open(`${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?host=${row.ip}&page=config`);
}

/* ************************************** */

function click_button_interface_configuration(event) {
    const row = event.row;
    window.open(`${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.ip}&snmp_port_idx=${row.ifid}&page=config`);
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_timeseries": click_button_timeseries,
        "click_button_device_configuration": click_button_device_configuration,
        "click_button_interface_configuration": click_button_interface_configuration
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* *************************************************** */

/* This function run the REST API with the data */
async function get_chart_options() {
    let result = null;
    const post_params = {
        csrf: csrf,
        ifid: system_interface_id,
        epoch_begin: ntopng_url_manager.get_url_entry("epoch_begin"),
        epoch_end: ntopng_url_manager.get_url_entry("epoch_end"),
        host: ntopng_url_manager.get_url_entry("host"),
    }

    result = await ntopng_utility.http_post_request(base_url, post_params);
    /* Format the result in the format needed by Dygraph */
    const config = timeseriesUtils.formatSimpleSerie(result, serie_name, "bar", ["percentage"], [0, 100]);

    /* Custom options for this chart */
    config.title = '<div style="font-size:18px;">' + i18n('snmp.top_congested_devices') + '</div>';
    config.titleHeight = 48;
    config.axes.y.axisLabelWidth = 40;
    config.xAxisHeight = 6;
    config.axes.x.axisLabelWidth = 120;
    config.axes.x.pixelsPerLabel = 20;
    config.xRangePad = 50;

    localStorage.setItem(`${serie_name}_x_axis_label`, JSON.stringify(result.labels));
    localStorage.setItem(`${serie_name}_metadata`, JSON.stringify(result.metadata));
    config.axes.x.axisLabelFormatter = function (value, granularity, opts, dygraph) {
        return ''
    };

    config.axes.x.valueFormatter = function (value, granularity, opts, dygraph) {
        /* Sometimes happens that X values are approximated in DyGraph, e.g. 5 becomes 5.000001
         * In this case no label is found even if it's present, su round the value before checking the label
         */
        if (value != null) {
            const rounded_value = Number(value.toFixed(4))
            const labels_json = localStorage.getItem(`${serie_name}_x_axis_label`)
            const labels_array = JSON.parse(labels_json);
            const label = labels_array[rounded_value - 1];
            if (label)
                return `<span style="white-space: pre-wrap">${label}</span>`

            return ''
        }
    };

    config.clickCallback = function (e, x, points) {
        // table_snmp_usage.value.search_value(x);
        const rounded_value = Number(x.toFixed(4))
        const metadata_json = localStorage.getItem(`${serie_name}_metadata`)
        const metadata_array = JSON.parse(metadata_json);
        const metadata = metadata_array[rounded_value - 1];
        if (metadata) {
            click_button_timeseries({ row: metadata });
        }
    }

    return config;
}

/* ************************************** */

onMounted(async () => {
    await Promise.all([
        ntopng_sync.on_ready(id_date_time_picker),
    ]);
});

</script>

<style scoped>
.dygraph-axis-label.dygraph-axis-label-x {
    font-size: 12px;
    transform: rotate(-90deg) translate(-20px, 0);
}
</style>
