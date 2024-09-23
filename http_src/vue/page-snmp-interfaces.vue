<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_snmp_interfaces" :table_id="table_id" :csrf="csrf"
            :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
            :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
            <template v-slot:custom_header>
                <Dropdown v-for="(t, t_index) in filter_table_array" :f_on_open="get_open_filter_table_dropdown(t, t_index)"
                    :ref="el => { filter_table_dropdown_array[t_index] = el }" :hidden="t.hidden">
                    <!-- Dropdown columns -->
                    <template v-slot:title>
                        <Spinner :show="t.show_spinner" size="1rem" class="me-1"></Spinner>
                        <a class="ntopng-truncate" :title="t.title">{{ t.label }}</a>
                    </template>
                    <template v-slot:menu>
                        <a v-for="opt in t.options" style="cursor:pointer; display: block;"
                            @click="add_table_filter(opt, $event)" class="ntopng-truncate tag-filter" :title="opt.value">

                            <template v-if="opt.count == null">{{ opt.label }}</template>
                            <template v-else>{{ opt.label + " (" + opt.count + ")" }}</template>
                        </a>
                    </template>
                </Dropdown>
            </template> <!-- Dropdown filters -->
        </TableWithConfig>
    </div>

    <div class="card-footer">
        <NoteList :note_list="note_list"> </NoteList>
    </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as Spinner } from "./spinner.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as dataUtils } from "../utilities/data-utils.js";
import formatterUtils from "../utilities/formatter-utils";

/* ************************************** */

const props = defineProps({
    context: Object,
});

/* ************************************** */

/* The same exact page is used for both, the interfaces page for all SNMP devices
 * and the interfaces page for a specific device. Having different columns, simply switch between 
 * those two tables.
 */
const table_id = props.context?.inside_a_device ? ref('snmp_device_interfaces') : ref('snmp_interfaces');
const table_snmp_interfaces = ref(null);
const csrf = props.context.csrf;
const filter_table_array = ref([]);
const filter_table_dropdown_array = ref([]);

const note_list = [
    i18n("snmp.snmp_note_periodic_interfaces_polling"),
    i18n("snmp.snmp_note_thpt_calc"),
    i18n("snmp.snmp_note_avg_usage")
];
const interface_status = {
    ["1"]: "<font color=green>" + i18n("snmp.status_up") + "</font>",
    ["101"]: "<font color=green>" + i18n("snmp.status_up_in_use") + "</font>",
    ["2"]: "<font color=red>" + i18n("snmp.status_down") + "</font>",
    ["3"]: i18n("snmp.testing"),
    ["4"]: i18n("snmp.status_unknown"),
    ["5"]: i18n("snmp.status_dormant"),
    ["6"]: i18n("status_notpresent"),
    ["7"]: "<font color=red>" + i18n("snmp.status_lowerlayerdown") + "</font>",
}
const duplex_status = {
    ["1"]: i18n("unknown"),
    ["2"]: "<font color=orange>" + i18n("flow_devices.half_duplex") + "</font>",
    ["3"]: "<font color=green>" + i18n("flow_devices.full_duplex") + "</font>"
}

/* ************************************** */

const map_table_def_columns = (columns) => {
    const formatter = formatterUtils.getFormatter("percentage");
    let map_columns = {
        "device_name": (value, row) => {
            let url = `<a href='${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?ip=${row.device_ip}'>${value}</a>`
            if (dataUtils.isEmptyOrNull(value)) {
                url = row.device_ip
            }
            return url
        },
        "interface_name": (value, row) => {
            value = value.replace(/</g, "&lt;").replace(/>/g, "&gt;");
            const url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.device_ip}&snmp_port_idx=${row.interface_id}`
            return `<a href=${url}>${value}</a>`
        },
        "vlan": (value, row) => {
            let vlan_name = ''
            if (row.vlan_name != '') {
                vlan_name = '[' + row.vlan_name + ']'
            }
            return `${value} ${vlan_name}`
        },
        "admin_status": (value, row) => {
            return `${interface_status[value] || ''}`
        },
        "status": (value, row) => {
            return `${interface_status[value] || ''}`
        },
        "duplex_status": (value, row) => {
            return `${duplex_status[value] || ''}`
        },
        "num_macs": (value, row) => {
            if (value > 0) {
                const url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.device_ip}&snmp_port_idx=${row.interface_id}&page=layer_2`
                return `<a href=${url}>${value}</a>`
            }
            return ''
        },
        "in_bytes": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("bytes")(value)
            }
            return ''
        },
        "out_bytes": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("bytes")(value)
            }
            return ''
        },
        "in_errors": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value)
            }
            return ''
        },
        "in_discards": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value)
            }
            return ''
        },
        "throughput": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("bps")(value)
            }
            return ''
        },
        "uplink_speed": (value, row) => {
            const formatted_speed = formatterUtils.getFormatter("speed")(value);
            return `${formatted_speed} <a href='${create_config_url_link(row, true)}'><i class="fas fa-cog"></i></a>`
        },
        "downlink_speed": (value, row) => {
            const formatted_speed = formatterUtils.getFormatter("speed")(value);
            return `${formatted_speed} <a href='${create_config_url_link(row, true)}'><i class="fas fa-cog"></i></a>`
        },
        "last_in_usage": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("percentage")(value)
            }
            return ''
        },
        "last_out_usage": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("percentage")(value)
            }
            return ''
        },
        "last_change": (value, row) => {
            return row.last_change_string
        },
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

function set_filter_array_label() {
    filter_table_array.value.forEach((el, index) => {
        if (el.basic_label == null) {
            el.basic_label = el.label;
        }

        const url_entry = ntopng_url_manager.get_url_entry(el.id)
        if (url_entry != null) {
            el.options.forEach((option) => {
                if (option.value.toString() === url_entry) {
                    el.label = `${el.basic_label}: ${option.label || option.value}`
                }
            })
        }
    })
}

/* ************************************** */

function add_table_filter(opt, event) {
    event.stopPropagation();
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    set_filter_array_label();
    table_snmp_interfaces.value.refresh_table();
}

/* ************************************** */

const get_open_filter_table_dropdown = (filter, filter_index) => {
    return (_) => {
        load_table_filters(filter, filter_index);
    };
};

/* ************************************** */

async function load_table_filters(filter, filter_index) {
    filter.show_spinner = true;
    await nextTick();
    filter.options = filter_table_array.value.find((t) => t.id == filter.id).options;
    await nextTick();
    let dropdown = filter_table_dropdown_array.value[filter_index];
    dropdown.load_menu();
    filter.show_spinner = false;
}

/* ************************************** */

async function load_table_filters_array() {
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/pro/rest/v2/get/snmp/metric/interfaces_filters.lua?${url_params}`;
    let res = await ntopng_utility.http_request(url);
    return res.map((t) => {
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

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function create_config_url_link(row, add_interface) {
    if (add_interface) {
        return `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.device_ip}&snmp_port_idx=${row.interface_id}&page=config`
    } else {
        return `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.device_ip}&page=config`
    }
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    const epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
    const epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
    window.open(`${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.ip}&snmp_port_idx=${row.ifid}&page=historical&ifid=-1&epoch_end=${epoch_end}&epoch_begin=${epoch_begin}&timeseries_groups_mode=1_chart_x_metric&timeseries_groups=snmp_interface;-1%2B${row.ip}%2B${row.ifid};snmp_if:usage;uplink=true:false:false:false|downlink=true:false:false:false`);
}

/* ************************************** */

function click_button_configuration(event) {
    const row = event.row;
    window.open(create_config_url_link(row, true));
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_timeseries": click_button_timeseries,
        "click_button_configuration": click_button_configuration
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

onMounted(async () => {
    filter_table_array.value = await load_table_filters_array();
    set_filter_array_label();
});

</script>
