<template>
    <div class="m-2 mb-3">
        <div class="mb-2" style="height: 30vh;">
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
            <Loading v-if="loading"></Loading>
            <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data"
                @node_click="on_node_click">
            </Sankey>
        </div>
        <TableWithConfig ref="table_probes" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" :get_extra_params_obj="get_extra_params_obj">
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
import { default as formatterUtils} from "../utilities/formatter-utils";
import { default as dataUtils} from "../utilities/data-utils.js";

const props = defineProps({
    context: Object,
});

let note_snmp_i18n = i18n("flow_devices.note_snmp_device");

const _i18n = (t) => i18n(t);
const sankey_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/sankey.lua`;
const sankey_chart = ref(null)
const sankey_data = ref({});
const loading = ref(false);
const no_data_message = i18n("no_nprobes_message")
const active_sankey_type = ref({})
const sankey_format_list = [
    { key: "criteria", value: 'flow_volume_criteria', label: _i18n('exporters_page.flow_volume_criteria') },
    { key: "criteria", value: 'flow_drops_criteria', label: _i18n('exporters_page.flow_drops_criteria') },
];
let note_snmp_device_url = note_snmp_i18n.replace("%{url}", `${http_prefix}/lua/pro/enterprise/snmpdevices_stats.lua`);


const note_list = [
    note_snmp_device_url
]

const first_open = ref(true);
const table_id = ref('exporters');
const table_probes = ref(null);
const csrf = props.context.csrf;

const chart_url = `${http_prefix}/lua/pro/enterprise/exporters.lua?`
const exporter_url = `${http_prefix}/lua/pro/enterprise/exporters.lua?`
const host_url = `${http_prefix}/lua/pro/enterprise/exporter_details.lua?`

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
    }, 10000 /* 10 sec refresh */)    
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
        if (ntopng_url_manager.get_url_entry("criteria") == "flow_drops_criteria") {
            link.label = formatterUtils.getFormatter("drops")(link.value)
        } else {
            link.label = formatterUtils.getFormatter("number")(link.value)
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
            let returnValue = value;

            // Add interface name if defined
            if (!dataUtils.isEmptyOrNull(row['interface_name'])) {
            returnValue = `${returnValue} ${row['interface_name']}`;
            }

            // Add timeseries icon if timeseries are enabled
            if (row['timeseries_enabled']) {
                let timeseriesUrl = `${chart_url}ip=${value}&page=historical&ifid=${row['ifid']}`;
                returnValue += `&nbsp;<a href="${timeseriesUrl}"><i class="fas fa-chart-area fa-lg"></i></a>`;
            }

            return `<a href="${host_url}ip=${value}&exporter_uuid=${row.exporter_uuid}&probe_uuid=${row.probe_uuid}">${returnValue}</a>`;
        },
        "probe_ip": (value, row) => {
            return value;
        },
        "name": (value, row) => {
            return value
        },
        "ntopng_interface": (value, row) => {
            return value
        },
        "exported_flows": (value, row) => {
            let diff_value = value
            if(!first_open.value) {
                const old_value = localStorage.getItem("exporter_exported_flows." + row.exporter_uuid + row.ip)
                diff_value = (value - Number(old_value)) / 10
            }
            localStorage.setItem("exporter_exported_flows." + row.exporter_uuid + row.ip, value)
            if (!value)
                return '';
            let formatted_value = formatterUtils.getFormatter("number")(value)
            if(!first_open.value) {
                let updated_counter = ''
                if(diff_value > 0 ) {
                    updated_counter = '<i class="fas fa-arrow-up"></i>'
                } else {
                    updated_counter = "<i class='fas fa-minus'></i>"
                }
                formatted_value = `${formatted_value} [ ${formatterUtils.getFormatter("fps_short")(diff_value)} ] ${updated_counter}`
            }
            return formatted_value
        },
        "dropped_flows": (value, row) => {
            let diff_value = value
            if(!first_open.value) {
                const old_value = localStorage.getItem("exporter_dropped_flows." + row.exporter_uuid + row.ip)
                diff_value = (value - Number(old_value)) / 10
            }
            localStorage.setItem("exporter_dropped_flows." + row.exporter_uuid + row.ip, value)
            if (!value)
                return '';
            let formatted_value = formatterUtils.getFormatter("number")(value)
            if(!first_open.value) {
                let updated_counter = ''
                if(diff_value > 0 ) {
                    updated_counter = '<i class="fas fa-arrow-up"></i>'
                } else {
                    updated_counter = "<i class='fas fa-minus'></i>"
                }
                formatted_value = `${formatted_value} [ ${formatterUtils.getFormatter("drops")(diff_value)} ] ${updated_counter}`
            }
            return formatted_value
        },
        "dropped_flows_last_24_h": (value, row) => {
            let diff_value = value
            if(!first_open.value) {
                const old_value = localStorage.getItem("exporter_dropped_flows_last_24_h." + row.exporter_uuid + row.ip)
                diff_value = (value - Number(old_value)) / 10
            }
            localStorage.setItem("exporter_dropped_flows_last_24_h." + row.exporter_uuid + row.ip, value)
            if (!value)
                return '';
            let formatted_value = formatterUtils.getFormatter("number")(value)
            if(!first_open.value) {
                let updated_counter = ''
                if(diff_value > 0 ) {
                    updated_counter = '<i class="fas fa-arrow-up"></i>'
                } else {
                    updated_counter = "<i class='fas fa-minus'></i>"
                }
                formatted_value = `${formatted_value} [ ${formatterUtils.getFormatter("drops")(diff_value)} ] ${updated_counter}`
            }
            return formatted_value
        },
        "flow_exporters": (value, row) => {
            if (!value) {
                return '';
            } else {
                return `<a href="${exporter_url}&ifid=${row.ifid}&ip=${row.probe_ip}"><i class="fas fa-file-export"></i> ${formatterUtils.getFormatter("number")(value)}</a>` 
            }
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "ip") {
            return sortingFunctions.sortByIP(r0.probe_ip, r1.probe_ip, col.sort);
        } else if (col.id == "name") {
            return sortingFunctions.sortByName(r0.probe_public_ip, r1.probe_public_ip, col.sort);
        } else if (col.id == "ntopng_interface") {
            return sortingFunctions.sortByName(r0.probe_public_ip, r1.probe_public_ip, col.sort);
        } else if (col.id == "exported_flows") {
            return sortingFunctions.sortByNumber(r0.probe_uuid, r1.probe_uuid, col.sort);
        } else if (col.id == "interface_name") {
            return sortingFunctions.sortByName(r0.probe_interface, r1.probe_interface, col.sort);
        } 
    }
}

</script>
