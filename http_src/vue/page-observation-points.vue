<template>

    <div class="m-2 mb-3">
        <TableWithConfig ref="table_observation_points" :table_id="table_id" :csrf="csrf"
            :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
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
const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object
});

const note_list = ref([
    i18n("flow_devices.note_observation_points_fields1").replace("%{url}", `${http_prefix}/lua/admin/prefs.lua?tab=on_disk_ts`),
    i18n("flow_devices.note_observation_points_fields2").replace("%{url}", `https://www.ntop.org/guides/ntopng/using_with_other_tools/nprobe.html#observation-points`),
    i18n("flow_devices.note_observation_points_fields3")
]);
const snmp_port_idx = ref(null);
const table_id = ref('observation_points');
const table_observation_points = ref(null);
const csrf = props.context.csrf;

const observation_point_config_url = `${http_prefix}/lua/pro/enterprise/observation_points.lua?page=config&observation_point=`
const exporters_url = `${http_prefix}/lua/pro/enterprise/flowdevices_list.lua?obs_point=`
const timeseries_url = `${http_prefix}/lua/pro/enterprise/observation_points.lua?page=historical&observation_point=`

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

function get_ip_from_url() {
    return ntopng_url_manager.get_url_entry('ip')
}

const map_table_def_columns = (columns) => {
    let map_columns = {
        "observation_point": (value, row) => {
            // get table footer notes
            var returnValue = value;

            // Add timeseries icon if timeseries are enabled
            if (row['observation_point_name']) {
                returnValue = `&nbsp;${row['observation_point_name']}`
            }

            let config_url = observation_point_config_url + value;
            returnValue += `&nbsp;<a href=${config_url}><i class="fas fa-cog fa-lg"></i></a>`

            if (row["timeseries"]) {
                let timeseries_full_url = timeseries_url + value;
                returnValue += `&nbsp;<a href=${timeseries_full_url}><i class="fas fa-chart-area fa-lg"></i></a>`
            }

            return returnValue
        },
        "exporters": (value, row) => {
            if (!value)
                return '';

            let exporters_formatted_url = exporters_url + value + `&ifid=${props.context.ifid}`;
            return `<a href=${exporters_formatted_url}>${value}</a>`
        },
        "total_flows": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("number")(value);
        },
        "hosts": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("number")(value);
        },
        "throughput": (value, row) => {
            return formatterUtils.getFormatter("bps")(value);
        },
        "traffic": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};


function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "observation_point") {
            return sortingFunctions.sortByName(r0.observation_point, r1.observation_point, col.sort);
        } else if (col.id == "exporters") {
            return sortingFunctions.sortByNumber(r0.exporters, r1.exporters, col.sort);
        } else if (col.id == "total_flows") {
            return sortingFunctions.sortByNumber(r0.total_flows, r1.total_flows, col.sort);
        } else if (col.id == "hosts") {
            return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
    }
}

function create_config_url_link(row) {
    return `${http_prefix}/lua/pro/db_search.lua?observation_point_id=${row.observation_point};eq`
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