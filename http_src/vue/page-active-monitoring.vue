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
            <template v-slot:custom_header>
                <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
                    <span class="no-wrap d-flex align-items-center my-auto me-2 filters-label"><b>{{ item["basic_label"]
                            }}</b></span>
                    <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5"
                        dropdown_size="small" :options="item['options']" @select_option="add_table_filter">
                    </SelectSearch>
                </div>
            </template> <!-- Dropdown filters -->
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
const table_id = ref('active-monitoring');
const filter_table_array = ref([]);
const date_format = ref(null);
const table_active_monitoring = ref();
const measurements_list = ref([]);
const interfaces_list = ref([]);
const modal_add_active_monitoring = ref(null);
const modal_delete = ref(null);
const error_message = ref(i18n('host_config.active_monitor_enable'))
const manage_configurations_url = ref(http_prefix + '/lua/admin/manage_configurations.lua?item=active_monitoring')
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
        "target": (value, row) => {
            let target_interface = {}
            let interface_name = ''
            let is_infrastructure_instance = ''
            let is_alerted = ''
            if (interfaces_list.value.length > 0) {
                const tmp_iface = interfaces_list.value.find((el) => el.ifid == row.metadata.interface_id)
                if (tmp_iface) {
                    target_interface["is_pcap_interface"] = tmp_iface["is_pcap_interface"]
                    target_interface["is_packet_interface"] = tmp_iface["is_packet_interface"]
                    target_interface["is_zmq_interface"] = tmp_iface["is_zmq_interface"]
                    target_interface["is_view_interface"] = tmp_iface["is_view_interface"]
                    target_interface["is_dynamic_interface"] = tmp_iface["is_dynamic_interface"]
                    target_interface["is_dropping_interface"] = tmp_iface["is_dropping_interface"]
                    target_interface["is_recording_interface"] = tmp_iface["is_recording_interface"]
                }
            }
            if (!dataUtils.isEmptyOrNull(row.metadata.interface_name)) {
                interface_name = ` [ ${interfaceUtils.getInterfaceIcon(target_interface)} ${row.metadata.interface_name} ] `;
            }
            if (row.metadata.is_infrastructure_instance) {
                is_infrastructure_instance = " <i class='fas fa-building'></i> "
            }
            if (row.metadata.is_alerted) {
                is_alerted = ' <i class="fas fa-exclamation-triangle" style="color: #f0ad4e;"></i> '
            }
            return `<span data-bs-toggle='tooltip' data-bs-placement='bottom' title='${(row.ip_address !== value.name) ? row.ip_address : ''}'>${value.name}${is_infrastructure_instance}${is_alerted}${interface_name}</span>`;
        },
        "ip_address": (value, row) => {
            return value;
        },
        "measurement_type": (value, row) => {
            return activeMonitoringUtils.getActiveMonitoringName(row.last_measurement.measurement_type);
        },
        "hourly_stats": (value, row) => {
            return visualizationUtils.createHeatmap(value);
        },
        "last_measurement_time": (value, row) => {
            value = row.last_measurement.last_measurement_time;
            if (value > 0) {
                return ntopng_utility.from_utc_to_server_date_format(value * 1000, date_format.value)
            }
            return;
        },
        "threshold": (value, row) => {
            return value + " " + i18n(row.metadata.unit);
        },
        "measurement_value": (value, row) => {
            let measurement = row.last_measurement.measurement_value;
            if (!dataUtils.isEmptyString(measurement)) {
                measurement = measurement + " " + i18n(row.metadata.unit);
            }
            return measurement;
        },
        "extra_measurements": (value, row) => {
            if (dataUtils.isEmptyString(value.mean)) {
                value.mean = "-"
            }
            if (dataUtils.isEmptyString(value.jitter)) {
                value.jitter = "-"
            }
            return `${value.mean} / ${value.jitter} ms`;
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                edit: props.context.is_admin,
                delete: props.context.is_admin,
                timeseries: true,
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
                        current_class.push("d-none");
                    } else if (!row.metadata.timeseries && (b.id) == "timeseries") {
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

        /* In case the values are the same, sort by IP */
        if (col.id == "target") {
            let val0 = r0_col
            let val1 = r1_col
            if (r0_col) val0 = r0_col.name
            if (r1_col) val1 = r1_col.name
            return sortingFunctions.sortByName(val0, val1, col.sort);
        } else if (col.id == "ip_address") {
            return sortingFunctions.sortByIP(r0_col, r1_col, col.sort);
        } else if (col.id == "measurement_type") {
            let val0 = r0.last_measurement.measurement_type
            let val1 = r1.last_measurement.measurement_type
            return sortingFunctions.sortByName(val0, val1, col.sort);
        } else if (col.id == "last_measurement_time") {
            let val0 = r0.last_measurement.last_measurement_time
            let val1 = r1.last_measurement.last_measurement_time
            const lower_value = 0;
            return sortingFunctions.sortByNumberWithNormalizationValue(val0, val1, col.sort, lower_value);
        } else if (col.id == "threshold") {
            const lower_value = 0;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        } else if (col.id == "measurement_value") {
            let val0 = r0.last_measurement.measurement_value
            let val1 = r1.last_measurement.measurement_value
            const lower_value = 0;
            return sortingFunctions.sortByNumberWithNormalizationValue(val0, val1, col.sort, lower_value);
        }
    }
}

/* ************************************** */

function set_filter_array_label() {
    filter_table_array.value.forEach((el, index) => {
        /* Setting the basic label */
        if (el.basic_label == null) {
            el.basic_label = el.label;
        }

        /* Getting the currently selected filter */
        const url_entry = ntopng_url_manager.get_url_entry(el.id)
        el.options.forEach((option) => {
            if (option.value.toString() === url_entry) {
                el.current_option = option;
            }
        })
    })
}

/* ************************************** */

function change_filter_labels() {
    set_filter_array_label()
}

/* ************************************** */

async function add_table_filter(opt) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    set_filter_array_label();
    table_active_monitoring.value.refresh_table();
    //  filter_table_array.value = await load_table_filters_array()
}

/* ************************************** */

async function load_table_filters_array() {
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/active_monitoring/filters.lua?${url_params}`;
    let res = await ntopng_utility.http_request(url);
    host_filters_key.value = host_filters_key.value + 1

    return res.map((t) => {
        const key_in_url = ntopng_url_manager.get_url_entry(t.name);
        if (dataUtils.isEmptyOrNull(key_in_url)) {
            ntopng_url_manager.set_key_to_url(t.name, ``);
        }
        return {
            id: t.name,
            label: t.label,
            title: t.tooltip,
            options: t.value,
            hidden: (t.value.length == 1)
        };
    });
}

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
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
    window.open(`${http_prefix}/lua/active_monitoring.lua?host=${row.target.host}&measurement=${row.last_measurement.measurement_type}&page=historical`);
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
