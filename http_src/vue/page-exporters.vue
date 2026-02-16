<template>
    <div class="m-2 mb-3">
        <div class="mb-3 d-flex flex-column" style="height: 30vh;">
            <div class="d-flex align-items-center mb-2">
                <div class="d-flex no-wrap">
                    <div class="m-1">
                        <div style="min-width: 16rem;">
                            <label class="me-1">{{ _i18n('criteria') }}: </label>
                            <SelectSearch v-model:selected_option="active_sankey_type" :options="sankey_format_list"
                                @select_option="add_sankey_filter">
                            </SelectSearch>
                        </div>
                    </div>
                </div>
            </div>
            <Loading :isLoading="loading"></Loading>
            <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data"
                @node_click="on_node_click">
            </Sankey>
        </div>
        <TableWithConfig ref="table_probes" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" :get_extra_params_obj="get_extra_params_obj"
            @custom_event="on_table_custom_event">
        </TableWithConfig>

        <NoteList :note_list="note_list"> </NoteList>
    </div>
</template>


<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as Loading } from "./loading.vue"
import { default as Sankey } from "./sankey.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NoteList } from "./note-list.vue";
import { default as formatterUtils } from "../utilities/formatter-utils";
import { default as dataUtils } from "../utilities/data-utils.js";
import linksUtils from "../utilities/links-utils.js";

const props = defineProps({
    context: Object,
});

let note_snmp_i18n = i18n("flow_devices.note_snmp_device");

const _i18n = (t) => i18n(t);
const sankey_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/sankey.lua`;
const sankey_chart = ref(null)
const sankey_data = ref({});
const loading = ref(true);
const no_data_message = i18n("no_nprobes_message")
const active_sankey_type = ref({})
const sankey_format_list = [
    { key: "criteria", value: 'flow_volume_criteria', label: _i18n('exporters_page.flow_volume_criteria') },
    { key: "criteria", value: 'flow_drops_criteria', label: _i18n('exporters_page.flow_drops_criteria') },
];
let note_snmp_device_url = note_snmp_i18n.replace("%{url}", `${http_prefix}/lua/pro/enterprise/snmpdevices_stats.lua`);


const note_list = [
    note_snmp_device_url,
    _i18n("exporters_page.failed_exports_descr")
]

const first_open = ref(true);
const table_id = ref('exporters');
const table_probes = ref(null);
const csrf = props.context.csrf;

const chart_url = `${http_prefix}/lua/pro/enterprise/exporters.lua?`
const exporter_url = `${http_prefix}/lua/pro/enterprise/exporters.lua?`
const exporter_interfaces_url = `${http_prefix}/lua/pro/enterprise/exporter_interfaces.lua?`

/* ************************************** */

onBeforeMount(() => {
    const criteria = ntopng_url_manager.get_url_entry("criteria");
    active_sankey_type.value = sankey_format_list[0];
    if (criteria) {
        sankey_format_list.forEach((element) => {
            if (element.value == criteria) {
                active_sankey_type.value = element
            }
        })
    }
})

onMounted(() => {
    update_sankey_data();
    setInterval(() => {
        first_open.value = false;
        table_probes.value.refresh_table()
        update_sankey_data()
    }, 60000 /* 60 sec refresh */)
})

/* ************************************** */

const add_sankey_filter = async (opt) => {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    update_sankey_data();
}

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

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

const map_table_def_columns = (columns) => {
    let map_columns = {
        "ip": (value, row) => {
            return value;
        },
        "probe_ip": (value, row) => {
            let probe_ip = value;
            if (!dataUtils.isEmptyOrNull(row['probe_name'])) {
                probe_ip = `${row['probe_name']}`;
            }

            return probe_ip;
        },
        "name": (value, row) => {
            return `<a href="${exporter_interfaces_url}ip=${row.ip}&exporter_source_id=${row.exporter_source_id}&probe_source_id=${row.probe_source_id}&probe_ip=${row.probe_ip}">${value}</a> `;
        },
        "ntopng_interface": (value, row) => {
            return value
        },
        "exporter_interfaces": (value, row) => {
            if (!value) {
                return '';
            } else {
                return formatterUtils.getFormatter("number")(value)
            }
        },
        "time_last_used": (value, row) => {
            if (!value)
                return '';
            else
                return (NtopUtils.secondsToTime((Math.round(new Date().getTime() / 1000)) - value) + " ago");
        },
        "exported_flows": (value, row) => {
            let diff_value = value
            if (!first_open.value) {
                const old_value = localStorage.getItem("exporter_exported_flows." + row.exporter_source_id + row.ip)
                diff_value = (value - Number(old_value)) / 60 // keep in sync with table refresh
            }
            localStorage.setItem("exporter_exported_flows." + row.exporter_source_id + row.ip, value)
            if (!value)
                return '';
            let formatted_value = formatterUtils.formatAccounting(value)
            if (!first_open.value) {
                let updated_counter = ''
                if (diff_value > 0) {
                    updated_counter = '<i class="fas fa-arrow-up"></i>'
                } else {
                    updated_counter = "<i class='fas fa-minus'></i>"
                }
                // change in exported flows since the last refresh
                if (diff_value > 0)
                    formatted_value = `${formatted_value} [ ${formatterUtils.getFormatter("fps_short")(diff_value)}] ${updated_counter}`
                else
                    formatted_value = `${formatted_value} ${updated_counter}`
            }
            return formatted_value
        },
        "dropped_flows": (value, row) => {
            let diff_value = value
            if (!first_open.value) {
                const old_value = localStorage.getItem("exporter_dropped_flows." + row.exporter_source_id + row.ip)
                diff_value = (value - Number(old_value)) / 60
            }
            localStorage.setItem("exporter_dropped_flows." + row.exporter_source_id + row.ip, value)
            if (!value)
                return '';
            let formatted_value = formatterUtils.formatAccounting(Math.abs(value))
            if (!first_open.value) {
                let updated_counter = ''
                if (diff_value > 0) {
                    updated_counter = '<i class="fas fa-arrow-up"></i>'
                } else {
                    updated_counter = "<i class='fas fa-minus'></i>"
                }
                if (diff_value > 0)
                    formatted_value = `${formatted_value} [ ${formatterUtils.getFormatter("fps_short")(diff_value)} ] ${updated_counter}`
                else
                    formatted_value = `${formatted_value} ${updated_counter}`
            }
            return formatted_value
        },
        "dropped_packets": (value, row) => {
            let diff_value = value
            if (!first_open.value) {
                const old_value = localStorage.getItem("exporter_dropped_packets." + row.exporter_source_id + row.ip)
                diff_value = (value - Number(old_value)) / 10
            }
            localStorage.setItem("exporter_dropped_packets." + row.exporter_source_id + row.ip, value)
            if (!value)
                return '';
            let formatted_value = formatterUtils.formatAccounting(Math.abs(value))
            if (!first_open.value) {
                let updated_counter = ''
                if (diff_value > 0) {
                    updated_counter = '<i class="fas fa-arrow-up"></i>'
                } else {
                    updated_counter = "<i class='fas fa-minus'></i>"
                }
                formatted_value = `${formatted_value} [ ${formatterUtils.formatAccounting(diff_value)} ] ${updated_counter}`
            }
            return formatted_value
        },
        "flow_exporters": (value, row) => {
            if (!value) {
                return '';
            } else {
                return `<a href="${exporter_url}&ifid=${row.ifid}&ip=${row.probe_ip}"><i class="fas fa-file-export"></i> ${formatterUtils.formatAccounting(value)}</a>`
            }
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                live_hosts: true,
                live_flows: true,
                configuration: true,
                timeseries: props.context.showTimeseries
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

function click_button_configuration(event) {
    const row = event.row;
    const url = linksUtils.getExporterDetailsPageURL({ ip: row.ip, probe_source_id: row.probe_source_id }, http_prefix)
    window.location.href = `${url}&page=config`
}

/* ************************************** */

function click_button_live_flows(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/flows_stats.lua?deviceIP=${row["ip"]}`;
}

/* ************************************** */

function click_button_live_hosts(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/hosts_stats.lua?deviceIP=${row["ip"]}`;
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    debugger;
    const url = linksUtils.getExporterTimeseriesPageURL({ ip: row.ip, ifid: row.ifid, probe_source_id: row.probe_source_id }, http_prefix)
    window.location.href = url;
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_live_flows": click_button_live_flows,
        "click_button_configuration": click_button_configuration,
        "click_button_timeseries": click_button_timeseries,
        "click_button_live_hosts": click_button_live_hosts,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "ip") {
            return sortingFunctions.sortByIP(r0.ip, r1.ip, col.sort);
        } else if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        } else if (col.id == "ntopng_interface") {
            return sortingFunctions.sortByIP(r0.ntopng_interface, r1.ntopng_interface, col.sort);
        } else if (col.id == "probe_ip") {
            return sortingFunctions.sortByIP(r0.probe_ip, r1.probe_ip, col.sort);
        } else if (col.id == "export_type") {
            return sortingFunctions.sortByName(r0.export_type, r1.export_type, col.sort);
        } else if (col.id == "exporter_interfaces") {
            return sortingFunctions.sortByNumber(r0.exporter_interfaces, r1.exporter_interfaces, col.sort);
        } else if (col.id == "time_last_used") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        } else if (col.id == "exported_flows") {
            return sortingFunctions.sortByNumber(r0.exported_flows, r1.exported_flows, col.sort);
        } else if (col.id == "dropped_flows") {
            return sortingFunctions.sortByNumber(r0.dropped_flows, r1.dropped_flows, col.sort);
        } else if (col.id == "interface_name") {
            return sortingFunctions.sortByName(r0.interface_name, r1.interface_name, col.sort);
        }
    }
}

</script>
