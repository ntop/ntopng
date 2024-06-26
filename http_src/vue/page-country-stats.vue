<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_countries_stats" :table_id="table_id" :csrf="csrf"
            :f_map_columns="map_table_def_columns" 
        :f_sort_rows="columns_sorting">
        </TableWithConfig>
    </div>
</template>


<script setup>
import { ref } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const table_id = ref('countries_stats');
const table_countries_stats = ref(null);
const csrf = props.context.csrf;

const map_table_def_columns = (columns) => {
    //country_details.lua?country=IT&page=historical

    let map_columns = {
        "name": (value, row) => {
            const url = `${http_prefix}/lua/hosts_stats.lua?country=${value}`
            return `<img src='/dist/images/blank.gif' class='flag flag-${value.toLowerCase()}'>&nbsp&nbsp<a href=${url}>${value}</a>`
        },
        "charts_enabled": (value, row) => {
            // redirect to country details historical
            const url = `${http_prefix}/lua/country_details.lua?country=${row["name"]}&page=historical`
            return `<a href=${url}><i class="fas fa-chart-area fa-lg"></i></a>`
        },
        "hosts": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "seen_since": (value, row) => {
            // `seen_since` might require formatting, e.g., date formatting.
            console.log(value)
            const formattedDate = ntopng_utility.from_utc_to_server_date_format(value * 1000); // Example date formatting
            return formattedDate;
        },
        "score": (value, row) => {
            // Assuming `score` is a number that might require some formatting.
            return formatterUtils.getFormatter("number")(value);
        },
        "breakdown": (value, row) => {
            return NtopUtils.createBreakdown(value["bytes_sent"], value["bytes_rcvd"], "Sent", "Rcvd")
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
        if (c.id === "actions") {
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


function columns_sorting(col, r0, r1) {
    if (col != null) {
    if (col.id == "name") {
      return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
    } else if (col.id == "hosts") {
      return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
    } else if (col.id == "seen_since") {
      return sortingFunctions.sortByNumber(r0.seen_since, r1.seen_since, col.sort);
    } else if (col.id == "score") {
      return sortingFunctions.sortByNumber(r0.score, r1.score, col.sort);
    } else if (col.id == "throughput") {
      return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
    } else if (col.id == "traffic") {
      return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
    } 
  }
 
}
</script>
