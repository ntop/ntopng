<template>

    <div class="m-2 mb-3">
        <TableWithConfig ref="table_exporters_details" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" :get_extra_params_obj="get_extra_params_obj">
        </TableWithConfig>

    </div>
</template>


<script setup>
import { ref } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import formatterUtils from "../utilities/formatter-utils";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object
});

const table_id = ref('exporters_interfaces');
const table_exporters_details = ref(null);
const csrf = props.context.csrf;


const exporter_notes_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporter_notes.lua?`
const flowdevice_interface_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?`
const exporter_ip_url = `${http_prefix}/lua/pro/enterprise/exporter_details.lua?` // ip=192.168.2.73&exporter_uuid=&probe_uuid=
const nprobe_ip_url = `${http_prefix}/lua/pro/enterprise/exporters.lua?probe_uuid=`


const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

const map_table_def_columns = (columns) => {
    let map_columns = {
        "nprobe_ip": (value, row) => {
            return value
        },
        "exporter_ip": (value, row) => {
            return value
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
        "interface_id": (value, row) => {

            return value
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};



function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "nprobe_ip") {
            return sortingFunctions.sortByIP(r0.nprobe_ip, r1.nprobe_ip, col.sort);
        } else if (col.id == "exporter_ip") {
            return sortingFunctions.sortByName(r0.exporter_ip, r1.exporter_ip, col.sort);
        } else if (col.id == "interface_id") {
            return sortingFunctions.sortByNumber(r0.interface_id, r1.interface_id, col.sort);
        } else if (col.id == "in_bytes") {
            return sortingFunctions.sortByNumber(r0.in_bytes, r1.in_bytes, col.sort);
        } else if (col.id == "out_bytes") {
            return sortingFunctions.sortByNumber(r0.out_bytes, r1.out_bytes, col.sort);
        }
    }
}

</script>