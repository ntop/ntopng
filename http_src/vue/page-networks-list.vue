<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_networks_stats" :table_id="table_id" :csrf="csrf"
            :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting">
        </TableWithConfig>
    </div>
    <NoteList :note_list="note_list"></NoteList>
</template>


<script setup>
import { ref } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NoteList } from "./note-list.vue";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";
import { RefreshCwOff } from "lucide";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const note_list = [
    _i18n("network_stats.note_overlapping_networks"),
    _i18n("network_stats.note_see_both_network_entries"),
    _i18n("network_stats.note_broader_network")
];

const areTsEnabled = props.context.areTsEnabled;
const csrf = props.context.csrf;
const table_networks_stats = ref(null);
const table_id = ref('networks_list');

const map_table_def_columns = (columns) => {

    let map_columns = {
        "networkName": (value, row) => {
            const network_url = `${http_prefix}/lua/hosts_stats.lua?network=${row.networkId}`;
            const network_config_url = `${http_prefix}/lua/network_details.lua?network=${row.networkId}&page=config`;
            const network_ts_url = `${http_prefix}/lua/network_details.lua?network=${row.networkId}&page=historical`;

            // Create href with network name and icons
            let href = `<a href="${network_url}">${value}</a>`;
            const net_config_href = `&nbsp;<a href="${network_config_url}"><i class="fas fa-cog"></i></a>`;
            const ts_icon_href = `&nbsp;<a href="${network_ts_url}"><i class="fas fa-chart-area"></i></a>`;

            href += net_config_href;
            href += ts_icon_href;
            return href
        },
        "hosts": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "score": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "hostsScoreRatio": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "alertedFlows": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "breakdown": (value, row) => {
            return NtopUtils.createBreakdown(row.breakdown.percentage_bytes_sent, row.breakdown.percentage_bytes_rcvd, "Sent", "Rcvd")
        },
        "throughput": (value, row) => {
            return formatterUtils.getFormatter("bps")(value);
        },
        "traffic": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id === "charts_enabled") {
            const visible_dict = {
                historical_data: props.context.show_historical,
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


function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "network_name") {
            return sortingFunctions.sortByName(r0.networkName, r1.networkName, col.sort);
        } else if (col.id == "hosts") {
            return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
        } else if (col.id == "score") {
            return sortingFunctions.sortByNumber(r0.score, r1.score, col.sort);
        } else if (col.id == "hosts_score_ratio") {
            return sortingFunctions.sortByNumber(r0.hostsScoreRatio, r1.hostsScoreRatio, col.sort);
        } else if (col.id == "alerted_flows") {
            return sortingFunctions.sortByNumber(r0.alertedFlows, r1.alertedFlows, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
    }

}
</script>
