<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
        <div v-if="!props.context.is_polling_enabled" class="alert alert-warning alert-dismissable">
            <span v-html="active_alert_text"></span>
        </div>

        <div v-if="props.context.devices_limit_crossed" class="alert alert-danger alert-dismissable">
            <span v-html="max_num_reached_alert_text"></span>
        </div>
        <div class="card card-shadow">
            <div class="card-body">
                <div v-if="import_with_success" class="alert alert-success alert-dismissable">
                    <span class="text-success me-1"></span>
                    <span> {{ import_ok_text }}</span>
                </div>

                <TableWithConfig ref="table_snmp_devices" :table_id="table_id" :csrf="csrf" :showLoading="true"
                    :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
                    :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event"
                    @rows_loaded="change_filter_labels">
                    <template v-slot:custom_buttons>
                        <ModalDeleteSNMPDevice ref="modal_delete_snmp_device" @delete="delete_row"
                            @ping_all="exec_ping_all" @prune="delete_unresponsive" @delete_all="delete_all">
                        </ModalDeleteSNMPDevice>
                        <button class="btn btn-link" type="button" @click="add_snmp_device">
                            <i class="fas fa-plus"></i>
                        </button>
                        <button class="btn btn-link" type="button" @click="import_snmp_devices">
                            <i class="fa-solid fa-file-arrow-down" data-bs-toggle="tooltip" data-bs-placement="top"
                                :title="_i18n('snmp.import_devices')"></i>
                        </button>
                        <a class="btn btn-link" download="snmp_config.json" :href="config_export_url">
                            <i class="fa-solid fa-file-arrow-up" data-bs-toggle="tooltip" data-bs-placement="top"
                                :title="_i18n('snmp.export_devices')"></i>
                        </a>
                    </template>
                    <template v-slot:custom_header>
                        <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
                            <span class="no-wrap d-flex align-items-center filters-label"><b>{{ item["basic_label"]
                            }}</b></span>
                            <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5"
                                dropdown_size="small" :disabled="loading" :options="item['options']"
                                @select_option="add_table_filter">
                            </SelectSearch>
                        </div>
                        <div class="d-flex justify-content-center align-items-center">
                            <div class="btn btn-sm btn-primary mt-2 me-3" type="button" @click="reset_filters">
                                {{ _i18n('reset') }}
                            </div>
                            <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
                        </div>
                    </template> <!-- Dropdown filters -->
                </TableWithConfig>
            </div>
        </div>

        <div class="card-footer mt-3">

            <a :href="manage_config_url" class="btn btn-secondary">
                <i class='fas fa-tasks'></i> {{ _i18n("manage_configurations.manage_configuration") }}
            </a>
            <template v-if="props.context.buttonsVisibility.pingDevices">
                <button type="button" ref="ping_all" @click="ping_all_devices" class="btn btn-warning ms-1"
                    :class="{ disabled: total_rows == 0 }">
                    <i class="fas fa-heartbeat"></i>
                    {{ _i18n("snmp.ping_devices") }}
                </button>
            </template>
            <template v-if="props.context.buttonsVisibility.isAdministrator">
                <button type="button" @click="delete_all_unresponsive_devices"
                    class="btn btn-danger ms-1"
                    :class="{ disabled: props.context.buttonsVisibility.pruneDevices == 0 }">
                    <i class="fas fa-trash"></i>
                    {{ _i18n("snmp.delete_unresponsive_devices") }}
                </button>
                <button type="button" @click="delete_all_devices" class="btn btn-danger ms-1"
                    :class="{ disabled: total_rows == 0 }">
                    <i class="fas fa-trash"></i>
                    {{ _i18n("snmp.delete_all_devices") }}
                </button>
            </template>
        </div>

    </div>

    <ModalAddSNMPDevice ref="modal_add_snmp_device" :context="context" @add="add_snmp_device_rest" @edit="edit">
    </ModalAddSNMPDevice>

    <ModalImportSNMPDevices ref="modal_import_snmp_devices" :context="context" @add="import_snmp_devices_rest">
    </ModalImportSNMPDevices>
</template>
<script setup>
import { ref, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as Spinner } from "./spinner.vue";
import NtopUtils from "../utilities/ntop-utils.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as ModalAddSNMPDevice } from "./modal-add-snmp-device.vue";
import { default as ModalDeleteSNMPDevice } from "./modal-delete-snmp-device.vue";
import { default as ModalImportSNMPDevices } from "./modal-import-snmp-devices.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import linksUtils from "../utilities/links-utils.js";


/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({
    context: Object,
});

/* ************************************** */

const table_id = ref("snmp_devices");
const table_snmp_devices = ref(null);
const csrf = props.context.csrf;
//const chart = ref(null);
const filter_table_array = ref([]);
const filters = ref([]);
const modal_add_snmp_device = ref();
const modal_import_snmp_devices = ref();
const import_with_success = ref(false);
const import_ok_text = ref(null);
const modal_delete_snmp_device = ref();
const row_to_delete = ref();
const total_rows = ref(0);
const config_export_url = `${http_prefix}/lua/rest/v2/export/snmp/config.lua?download=1`;
const delete_snmp_device_url = `${http_prefix}/lua/pro/rest/v2/delete/snmp/device.lua`;
const download_snmp_device_log_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/snmp_debug.lua`;
const add_snmp_device_url = `${http_prefix}/lua/pro/rest/v2/add/snmp/device.lua`;
const import_snmp_devices_url = `${http_prefix}/lua/pro/rest/v2/add/snmp/import_devices.lua`;
const edit_snmp_device_url = `${http_prefix}/lua/pro/rest/v2/edit/snmp/device/device.lua`;
const manage_config_url = `${http_prefix}/lua/admin/manage_configurations.lua?item=snmp`;
const ping_all_devices_url = `${http_prefix}/lua/pro/rest/v2/check/snmp/ping_all_devices.lua`;
const delete_snmp_unresponsive_devices_url = `${http_prefix}/lua/pro/rest/v2/delete/snmp/unresponsive_devices.lua`;
const delete_all_snmp_devices_url = `${http_prefix}/lua/pro/rest/v2/delete/snmp/all_devices.lua`;
const active_alert_text = _i18n('enable_snmp_polling_warning').replace("%{base_prefix}", `${http_prefix}`);
const max_num_reached_alert_text = _i18n('snmp_max_num_devices_configured').replace("%{max_num}", props.context.max_devices).replace("%{configured_devices}", props.context.devices_configured);

const loading = ref(false);

const timeoutId = ref(null);
const tableRefreshRate = 10000;

const rest_params = {
    csrf: props.context.csrf,
};

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "ip": (data, row) => {
            let rsp = ''
            if (row.polling_in_progress) {
                rsp = `<i class='fas fa-sync' data-bs-toggle='tooltip' data-bs-placement='top' title='${_i18n('snmp.polling_in_progress')}'></i>`
            }
            if (row.is_unreachable) {
                rsp = `<span class='badge bg-warning' data-bs-toggle='tooltip' data-bs-placement='top' title='${_i18n('snmp.snmp_device_does_not_respond')}'>
                            <i class="fas fa-exclamation-triangle"></i>
                        </span> ${rsp}`;
            }
            if (row.last_update) {
                return `<a href='${linksUtils.getSNMPDetailsPageURL(data, http_prefix)}'>${data}</a> ${rsp}`;
            }
            return `${data} ${rsp}`;
        },
        "interfaces_with_errors": (data, row) => {
            if (data === 0) return "";
            return `<a href='${linksUtils.getSNMPDetailsPageURL(row.ip, http_prefix)}&page=interfaces&err_counters_filter=errors_or_discards'>${data}</a>`;
        },
        "last_update": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime(value)
            }
            return ''
        },
        "last_poll_duration": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime(value)
            }
            return ''
        }

    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                edit: true,
                delete: true,
                timeseries: props.context.timeseriesAvailable,
                export: true,
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
    total_rows.value = table_snmp_devices.value.get_rows_num();
}

/* ************************************** */

function add_table_filter(opt, opt2) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    if (opt2) {
        ntopng_url_manager.set_key_to_url(opt2.key, `${opt2.value}`);
    }
    table_snmp_devices.value.refresh_table();
    load_table_filters_array()
}

/* ************************************** */

function set_filters_list(res) {
    if (!res) {
        filter_table_array.value = filters.value.filter((t) => {
            if (t.show_with_key) {
                const key = ntopng_url_manager.get_url_entry(t.show_with_key)
                if (key !== t.show_with_value) {
                    return false
                }
            }
            return true
        })
    } else {
        filters.value = res.map((t) => {
            const key_in_url = ntopng_url_manager.get_url_entry(t.name);
            if (key_in_url === null) {
                ntopng_url_manager.set_key_to_url(t.name, ``);
            }
            return {
                id: t.name,
                label: t.label,
                title: t.tooltip,
                options: t.value,
                show_with_key: t.show_with_key,
                show_with_value: t.show_with_value,
            };
        });
        set_filters_list();
        return;
    }
    set_filter_array_label();
}

/* ************************************** */

async function load_table_filters_array() {
    loading.value = true;
    set_filters_list(props.context.filters)
    loading.value = false;
}

/* ************************************** */

function reset_filters() {
    filter_table_array.value.forEach((el, index) => {
        /* Getting the currently selected filter */
        ntopng_url_manager.set_key_to_url(el.id, ``);
    })
    load_table_filters_array();
    table_snmp_devices.value.refresh_table();
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "ip") {
            return sortingFunctions.sortByIP(r0.ip, r1.ip, col.sort);
        } else if (col.id == "snmp_version") {
            return sortingFunctions.sortByName(r0.snmp_version, r1.snmp_version, col.sort);
        } else if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        } else if (col.id == "description") {
            return sortingFunctions.sortByName(r0.description, r1.description, col.sort);
        } else if (col.id == "interfaces_with_errors") {
            return sortingFunctions.sortByNumber(r0.interfaces_with_errors, r1.interfaces_with_errors, col.sort);
        } else if (col.id == "last_poll_duration") {
            return sortingFunctions.sortByNumber(r0.last_poll_duration, r1.last_poll_duration, col.sort);
        } else if (col.id == "last_update") {
            return sortingFunctions.sortByNumber(r0.last_update, r1.last_update, col.sort);
        }
        // Default option
        return sortingFunctions.sortByName(r0.ip, r1.ip, col.sort);
    }
}

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function import_snmp_devices() {
    modal_import_snmp_devices.value.show();
}

function refresh_feedback_messages() {
    import_with_success.value = false;
    import_ok_text.value = null;
}

const import_snmp_devices_rest = async function (params) {
    const url = import_snmp_devices_url;
    const result = await ntopng_utility.http_post_request(url, { ...rest_params, ...params }, false, true);

    if (result == null) {
        modal_import_snmp_devices.value.show_bad_feedback(_i18n("import_snmp_devices_error"));
    } else if (result.rsp?.err && result.rsp?.err < 0) {
        modal_import_snmp_devices.value.show_bad_feedback(result.rsp.feedback);
    } else {
        import_with_success.value = true;
        modal_import_snmp_devices.value.close();
        import_ok_text.value = result.rsp.feedback;
        setTimeout(refresh_feedback_messages, 10000);

        table_snmp_devices.value.refresh_table();
    }
}

/* ************************************** */
/* Functions to handle the add of devices */

function add_snmp_device() {
    modal_add_snmp_device.value.show();
}

const add_snmp_device_rest = async function (params) {
    const url = add_snmp_device_url;

    const result = await ntopng_utility.http_post_request(url, { ...rest_params, ...params }, false, true);
    if (result.rc < 0) {
        modal_add_snmp_device.value.show_bad_feedback(result.rc_str_hr);
        table_snmp_devices.value.refresh_table();
    } else {
        modal_add_snmp_device.value.close();
        table_snmp_devices.value.refresh_table();
    }
}

const edit = async function (params) {
    const url = edit_snmp_device_url;

    const result = await ntopng_utility.http_post_request(url, { ...rest_params, ...params }, false, true);
    if (result.rc < 0) {
        modal_add_snmp_device.value.show_bad_feedback(result.rc_str_hr);
    } else {
        modal_add_snmp_device.value.close();
        table_snmp_devices.value.refresh_table();
    }
}

/* ************************************** */
/* Functions to handle the deletes */

/* Function to handle delete button */
function click_button_delete(event) {
    row_to_delete.value = event.row;
    modal_delete_snmp_device.value.show(1, row_to_delete.value);
}

/* Function to delete host to scan */
const delete_row = async function () {

    const row = row_to_delete.value;
    const url = delete_snmp_device_url;
    rest_params.host = row.ip;
    await ntopng_utility.http_post_request(url, rest_params);
    table_snmp_devices.value.refresh_table();
};

/* ************************************** */

function click_button_export_snmp_device_data(event) {
    const row = event.row;
    const params = {
        host: row.ip
    }
    ntopng_url_manager.go_to_url(`${download_snmp_device_log_url}?host=${row.ip}`, params);
};

/* ************************************** */

function click_button_edit(event) {
    const row_to_edit = event.row;
    modal_add_snmp_device.value.show(row_to_edit);
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    window.location.href = `${linksUtils.getSNMPDetailsPageURL(row.ip, http_prefix)}&page=historical`
}

/* ************************************** */
/* Table Buttons handler */
function on_table_custom_event(event) {
    let events_managed = {
        "click_button_edit": click_button_edit,
        "click_button_delete": click_button_delete,
        "click_button_export_snmp_device_data": click_button_export_snmp_device_data,
        "click_button_timeseries": click_button_timeseries
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */
/* Functions to handle footer buttons */

// function to open modal
function ping_all_devices() {
    modal_delete_snmp_device.value.show(2);
}

// function to exec command
const exec_ping_all = async function () {
    const url = ping_all_devices_url;
    await ntopng_utility.http_post_request(url, rest_params);
}

// function to open modal
function delete_all_unresponsive_devices() {
    modal_delete_snmp_device.value.show(3);
}

// function to open modal
function delete_all_devices() {
    modal_delete_snmp_device.value.show(4);
}

// function to exec command
const delete_unresponsive = async function () {
    const url = delete_snmp_unresponsive_devices_url;
    await ntopng_utility.http_post_request(url, rest_params);
    table_snmp_devices.value.refresh_table();
}

// function to exec command
const delete_all = async function () {
    const url = delete_all_snmp_devices_url;
    await ntopng_utility.http_post_request(url, rest_params);
    table_snmp_devices.value.refresh_table();
}

// function to periodically refresh table content
const refreshTableContent = function () {
    table_snmp_devices.value.refresh_table(true);

    // set next refresh timeout
    timeoutId.value = setTimeout(() => {
        refreshTableContent();
    }, tableRefreshRate);
}

/* ************************************** */

onBeforeMount(() => {
    ntopng_url_manager.set_key_to_url("verbose", true);
    load_table_filters_array();

    // start table refresh
    timeoutId.value = setTimeout(() => {
        refreshTableContent();
    }, tableRefreshRate);
})

</script>
