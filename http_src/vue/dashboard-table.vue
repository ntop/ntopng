<!--
  (C) 2013-22 - ntop.org
-->

<template>
    <div class="table-responsive" style="margin-left:-1rem;margin-right:-1rem;">
        <Loading v-if="!props.hideLoading" :isLoading="isLoading"></Loading>
        <BootstrapTable :id="table_id" :columns="columns" :rows="table_rows" :hide_head="hide_head"
            :no_background="no_background" :print_html_column="render_column" :print_html_row="render_row"
            :wrap_columns="true">
        </BootstrapTable>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";
import Loading from "./loading.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('simple_table');
const table_rows = ref([]);
const isLoading = ref(true);
const firstLoading = ref(true);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    filters: Object,
    hideLoading: Boolean, /* If false, no Loading animation is shown */
    showOnlyFirstLoading: Boolean, /* If true, shows only the first loading of the component, not the updates */
});

const hide_head = computed(() => {
    return props.params.no_bg;
});

const no_background = computed(() => {
    return props.params.no_bg;
});

const columns = computed(() => {
    let columns = props.params.columns.map((c) => {
        if (!c.style && c.data_type) {
            if (c.data_type == "bytes" || c.data_type == "date") {
                c.style = "text-align: right";
            } else if (c.data_type == "count_score") {
                c.style = "text-align: center"
            }
        }

        return {
            ...c,
        };
    });

    columns[0].class = (columns[0].class ? (columns[0].class + " ") : "")
        + "first-col-width";

    return columns;
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    refresh_table();
}, { flush: 'pre', deep: true });

onBeforeMount(() => {
    init();
});

onMounted(() => {
    firstLoading.value = false
});

function init() {
    refresh_table();
}

const render_column = function (column) {
    if (column.i18n_name) { return _i18n(column.i18n_name); }
    return "";
}

const row_render_functions = {

    /* Render function for 'throughput' table type */
    throughput: function (column, row) {
        if (column.id == 'name') {
            let name = row.name;
            if (row['instance_name'])
                name = `${row.name} [${row.instance_name}]`;
            if (row['url'])
                return `<a href='${row.url}'>${name}</a>`;
            else
                return name;
        } else if (column.id == 'throughput') {
            if (row['throughput_type'] && row['throughput_type'] == 'pps') {
                return NtopUtils.fpackets(row[column.id]);
            } else if (row['throughput_type'] && row['throughput_type'] == 'bps') {
                return NtopUtils.bitsToSize(row[column.id]);
            } else {
                return row['throughput'];
            }
        } else {
            return "";
        }
    },

    /* Render function for 'throughput' table type */
    assets: function (column, row) {
        if (column.id == 'server') {
            let name = row.server;
            if (row['url'])
                return `<a href='${row.url}'>${name}</a>`;
            else
                return name;
        } else {
            return NtopUtils.formatValue(row[column.id]);
        }
    },

    /* Render function for 'total_throughput' table type */
    total_throughput: function (column, row) {
        if (column.id == 'name') {
            let name = row.name;
            if (row['url'])
                return `<a href='${row.url}'>${name}</a>`;
            else
                return name;
        } else if (column.id == 'counters') {
            let label = '';
            if (row.counters) {
                if (row.counters.throughput) {
                    label += `<i class="fas fa-arrow-up"></i> ${NtopUtils.bitsToSize(row.counters.throughput.upload || 0)}</span></a> `;
                    label += `<i class="fas fa-arrow-down"></i> ${NtopUtils.bitsToSize(row.counters.throughput.download || 0)}</span></a> `;
                } else {
                    label += NtopUtils.bitsToSize(row.counters.throughput_bps || 0);
                }
            }
            return label;
        } else {
            return "";
        }
    },

    /* Render function for 'db_search' table type */
    db_search: function (column, row) {
        if (column.data_type == 'host') {
            return NtopUtils.formatHost(row[column.id], row, (column.id == 'cli_ip'));
        } else if (column.data_type == 'network') {
            return NtopUtils.formatNetwork(row[column.id], row);
        } else if (column.data_type == 'asn') {
            return NtopUtils.formatASN(row[column.id], row);
        } else if (column.data_type == 'country') {
            return NtopUtils.formatCountry(row[column.id], row);
        } else if (column.data_type == "l7_proto") {
            return row[column.id].label;
        } else if (formatterUtils.types[column.data_type]) {
            // 'bytes', 'bps', 'pps', ...
            let formatter = formatterUtils.getFormatter(column.data_type);
            return formatter(row[column.id]);
        } else if (typeof row[column.id] === 'object') {
            return NtopUtils.formatGenericObj(row[column.id], row);
        } else {
            return row[column.id];
        }
    },

    /* Render function for 'alert_count' table type */
    alert_count: function (column, row) {
        if (column.id == 'name') {
            let name = row.name;
            if (row['url'])
                return `<a href='${row.url}'>${name}</a>`;
            else
                return name;
        } else if (column.id == 'counters') {
            let total = row.counters.engaged_alerts || 0;
            let errors = row.counters.engaged_alerts_error || 0;
            let warnings = row.counters.engaged_alerts_warning || 0;
            let infos = 0;
            if (total > errors + warnings) infos = total - (errors + warnings);
            let label = '';
            if (infos > 0)
                label += `<a href="${row.url}"><span class="badge bg-success"><i class="fas fa-exclamation-triangle"></i> ${infos}</span></a> `;
            if (warnings > 0)
                label += `<a href="${row.url}"><span class="badge bg-warning"><i class="fas fa-exclamation-triangle"></i> ${warnings}</span></a> `;
            if (errors > 0)
                label += `<a href="${row.url}"><span class="badge bg-danger"><i class="fas fa-exclamation-triangle"></i> ${errors}</span></a> `;
            return label;
        } else {
            return "";
        }
    },

    /* Render function for 'uptime' table type */
    uptime: function (column, row) {
        if (column.id == 'name') {
            let name = row.name;
            if (row['url'])
                return `<a href='${row.url}'>${name}</a>`;
            else
                return name;
        } else if (column.id == 'counters') {
            let label = `${NtopUtils.secondsToTime(row.counters.uptime_sec || 0)}`;
            return label;
        } else {
            return "";
        }
    }

};

const render_row = function (column, row) {
    if (props.params &&
        props.params.table_type &&
        row_render_functions[props.params.table_type]) {
        const render_func = row_render_functions[props.params.table_type];
        return render_func(column, row);
    } else if (row[column.id]) {
        return row[column.id];
    } else {
        return "";
    }
}

async function refresh_table() {
    isLoading.value = (props?.showOnlyFirstLoading === true) ? (firstLoading.value && true) : true;
    const url_params = {
        ifid: props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        ...props.params.url_params,
        ...props.filters
    }

    let data = await props.get_component_data(`${http_prefix}${props.params.url}`, url_params, undefined, props.epoch_begin);

    let rows = [];
    if (props.params.table_type == 'db_search') {
        rows = data.records; /* db_search: read data from data.records */
    } else {
        rows = data; /* default: data is the array of records */
    }

    table_rows.value = rows;
    isLoading.value = false // Always false
}
</script>

<style>
.first-col-width {
    /* max-width: 100% !important; */
}

@media print and (max-width: 210mm) {
    td.first-col-width {
        max-width: 55mm !important;
    }
}

@media print and (min-width: 211mm) {
    td.first-col-width {
        max-width: 95mm !important;
    }
}

/* @media print and (max-width: 148mm){ */
/* } */
</style>
