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
import formatterUtils from "../utilities/formatter-utils";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object
});

const note_list = ref([]);
const snmp_port_idx = ref(null);
const table_id = ref('exporters_details');
const table_probes = ref(null);
const csrf = props.context.csrf;


const exporter_notes_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporter_notes.lua?`
const flowdevice_interface_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?`
const snmp_interface_details_url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?`
const snmp_interface_config_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?`

// Function to display notes on the footer of the table
async function get_notes(snmp_port_idx) {
    let url = exporter_notes_url + `ip=${get_ip_from_url()}&snmp_port_idx=${snmp_port_idx}`
    const rsp = await ntopng_utility.http_request(url);

    note_list.value = rsp.map(el => el.content);
}

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

function get_ip_from_url() {
    return ntopng_url_manager.get_url_entry('ip')
}

const map_table_def_columns = (columns) => {
    let map_columns = {
        "ifindex": (value, row) => {
            get_notes(value)
            var snmp_interface_url = `${snmp_interface_details_url}ip=${get_ip_from_url()}&page=config&snmp_port_idx=${value}&ifid=${props.context.ifid}`
            return `<a href=${snmp_interface_url}>${value}</i></a>`
        },
        "snmp_ifname": (value, row) => {
            // get table footer notes
            var returnValue = value;

            // Add timeseries icon if timeseries are enabled
            if (row['timeseries_enabled']) {
                let timeseriesUrl = `${flowdevice_interface_url}ip=${get_ip_from_url()}&ts_schema=flowdev_port:traffic&page=historical&snmp_port_idx=${row.ifindex}&ifid=${props.context.ifid}`
                returnValue += `&nbsp;<a href=${timeseriesUrl}><i class="fas fa-chart-area fa-lg"></i></a>&nbsp;`
            }

            let snmp_config = `${snmp_interface_config_url}ip=${get_ip_from_url()}&page=config&snmp_port_idx=${row.ifindex}&ifid=${props.context.ifid}`
            returnValue += `<a href=${snmp_config}><i class="fas fa-cog"></i></a>`
            
            return returnValue
        },
        "in_bytes": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("bytes")(value);
        },
        "out_bytes": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("bytes")(value);
        },
        "throughput": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("bps")(value);
        },
        "ratio": (value, row) => {
            if (!value)
                return '';
            return value;
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
        } else if (col.id == "exported_flows") {
            return sortingFunctions.sortByNumber(r0.probe_uuid, r1.probe_uuid, col.sort);
        } else if (col.id == "interface_name") {
            return sortingFunctions.sortByName(r0.probe_interface, r1.probe_interface, col.sort);
        }
    }
}

</script>
