<!-- (C) 2024 - ntop.org     -->
<template>
    <template v-if="(!props.context.is_am_active)">
        <div class="alert alert-warning" role="alert" id='error-alert' v-html:="error_message">
        </div>
    </template>
    <div class="m-2 mb-3" :class="[(!props.context.is_am_active) ? 'ntopng-gray-out' : '']">
        <TableWithConfig ref="table_active_monitoring" :table_id="table_id" :csrf="context.csrf"
            :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
            :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" @click="add_monitoring">
                    <i class="fas fa-plus"></i>
                </button>
            </template>
        </TableWithConfig>
        <div class="card-footer mt-3">
            <button v-if="props.context.is_admin" type="button" class="btn btn-secondary ms-1"
                :href="manage_configurations_url">
                <i class="fas fa-tasks"></i>
                {{ _i18n("manage_configurations.manage_configuration") }}
            </button>
        </div>
    </div>
    <ModalAddActiveMonitoring ref="modal_add_active_monitoring" :interfaces="interfaces_list"
        :measurements="measurements_list" :context="context" :url_request="new_measurement_url" @add="refresh_table">
    </ModalAddActiveMonitoring>
    <ModalDeleteActiveMonitoring ref="modal_delete" :interfaces="interfaces_list" :measurements="measurements_list"
        :context="context" :url_request="new_measurement_url" @delete="refresh_table">
    </ModalDeleteActiveMonitoring>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as visualizationUtils } from "../utilities/visualization-utils.js";
import { default as activeMonitoringUtils } from "../utilities/map/active-monitoring-utils.js";
import { default as dataUtils } from "../utilities/data-utils.js";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as ModalAddActiveMonitoring } from "./modal-add-active-monitoring.vue";
import { default as ModalDeleteActiveMonitoring } from "./modal-delete-active-monitoring.vue";
import { default as interfaceUtils } from "../utilities/map/interface-utils.js";

const _i18n = (t) => i18n(t);

const host_filters_key = ref(0);
const table_id = ref('infrastructure-monitoring');
const filter_table_array = ref([]);
const date_format = ref(null);
const table_active_monitoring = ref();
const measurements_list = ref([]);
const interfaces_list = ref([]);
const modal_add_active_monitoring = ref(null);
const modal_delete = ref(null);
const error_message = ref(i18n('host_config.active_monitor_enable'))
const manage_configurations_url = ref(http_prefix + '/lua/admin/manage_configurations.lua?item=infrastructure')
const measurements_url = ref(http_prefix + '/lua/rest/v2/get/active_monitoring/measurements.lua')
const interfaces_url = ref(http_prefix + '/lua/rest/v2/get/ntopng/interfaces.lua')
const new_measurement_url = ref(http_prefix + '/lua/rest/v2/set/active_monitoring/measurement.lua')

/* ************************************** */

const props = defineProps({
    context: Object,
});

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "name": (value, row) => {
            return value;
        },
        "url": (value, row) => {
            const label = value.replace(/(http(s)?)\:\/\//, '');
            return `<a class="ntopng-external-link" href='${url}' target='_self'>${label} <i class='fas fas fa-external-link-alt'></i></a>`
        },
        "status": (value, row) => {
            return value
        },
        "throughput": (value, row) => {
            return value
        },
        "hosts": (value, row) => {
            return value;
        },
        "threshold": (value, row) => {
            return value + " " + i18n(row.metadata.unit);
        },
        "flows": (value, row) => {
            return value
        },
        "engaged_alerts": (value, row) => {
            return value
        },
        "flow_alerts": (value, row) => {
            return value
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                edit: props.context.is_admin,
                delete: props.context.is_admin,
                timeseries: props.context.timeseries_enabled,
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
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

function column_data(col, row) {
    return row[col.data.data_field];
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        let r0_col = column_data(col, r0);
        let r1_col = column_data(col, r1);
        const lower_value = 0;

        /* In case the values are the same, sort by IP */
        if (col.id == "name") {
            return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
        } else if (col.id == "status") {
            return sortingFunctions.sortByNumber(r0_col, r1_col, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "hosts") {
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "flows") {
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "engaged_alerts") {
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "flow_alerts") {
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "last_update") {
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        }
    }
}

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    extra_params.stats = true;
    return extra_params;
};

/* ************************************** */

function add_monitoring() {
    modal_add_active_monitoring.value.show();
}

/* ************************************** */

function click_button_delete(event) {
    const row = event.row;
    modal_delete.value.show(row);
}

/* ************************************** */

function click_button_edit(event) {
    const row = event.row;
    modal_add_active_monitoring.value.show(row);
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    window.open(`${http_prefix}/lua/active_monitoring.lua?am_host=${row.target.host},metric:${row.last_measurement.measurement_type}&page=historical`);
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_edit": click_button_edit,
        "click_button_delete": click_button_delete,
        "click_button_timeseries": click_button_timeseries,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

function refresh_table() {
    table_active_monitoring.value.refresh_table();
}

/* ************************************** */

onMounted(async () => {
    filter_table_array.value = await load_table_filters_array();
    set_filter_array_label()
});

/* ************************************** */

onBeforeMount(async () => {
    measurements_list.value = await ntopng_utility.http_request(measurements_url.value);
    interfaces_list.value = await ntopng_utility.http_request(interfaces_url.value);
    date_format.value = await ntopng_utility.get_date_format(false, props.context.csrf, http_prefix);
})

/* ************************************** */

</script>
