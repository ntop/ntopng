<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_exporters_list" :table_id="table_id" :csrf="csrf"
            :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
        </TableWithConfig>
    </div>
</template>


<script setup>

import { ref } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";

import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";


const props = defineProps({
    context: Object
});

const table_id = ref('flow_exporters_list');
const table_exporters_list = ref(null);
const csrf = props.context.csrf;

const exporter_info_url = `${http_prefix}/lua/pro/db_search.lua?probe_ip=`
const exporter_url = `${http_prefix}/lua/pro/enterprise/flowdevice_details.lua?ip=`

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

const map_table_def_columns = (columns) => {
    let map_columns = {
        "exporter_device": (value, row) => {
            if (!value)
                return '';

            let exporters_formatted_url = exporter_url + value;
            return `<a href=${exporters_formatted_url}>${value}</a>`
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};


function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "exporter_device") {
            return sortingFunctions.sortByName(r0.exporter_device, r1.exporter_device, col.sort);
        } else if (col.id == "exporters") {
            return sortingFunctions.sortByNumber(r0.exporters, r1.exporters, col.sort);
        }
    }
}

function create_config_url_link(row) {
    return exporter_info_url + row.exporter_device + ";eq&observation_point_id=" + props.context.observation_point + ";eq"
}

function click_button_live_flows(event) {
    const row = event.row;
    window.open(create_config_url_link(row));
}

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_live_flows": click_button_live_flows,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

</script>