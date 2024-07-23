<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_probes" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" :get_extra_params_obj="get_extra_params_obj">
        </TableWithConfig>
        
        <NoteList :note_list="note_list"> </NoteList>
    </div>
</template>


<script setup>
import { ref, onMounted } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NoteList } from "./note-list.vue";
import { default as formatterUtils} from "../utilities/formatter-utils";
import { default as dataUtils} from "../utilities/data-utils.js";

const props = defineProps({
    context: Object,
});

let note_snmp_i18n = i18n("flow_devices.note_snmp_device");

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

onMounted(() => {
    setInterval(() => {
        first_open.value = false;
        table_probes.value.refresh_table()
    }, 10000 /* 10 sec refresh */)    
})

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
