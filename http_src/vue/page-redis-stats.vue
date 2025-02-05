<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_redis_stats" :table_id="table_id" :csrf="props.context.csrf"
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

const table_id = ref('redis_stats');
const table_redis_stats = ref(null);

const map_table_def_columns = (columns) => {

    let map_columns = {
        "column_command": (value, row) => {
            return value
        },
        "column_chart": (value, row) => {
            return value
        },
        "column_hits": (value, row) => {
            return value
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id === "actions") {
            const visible_dict = {};
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
    if (col.id == "column_command") {
      return sortingFunctions.sortByName(r0.column_command, r1.column_command, col.sort);
    } else if (col.id == "column_hits") {
      return sortingFunctions.sortByNumber(r0.column_hits, r1.column_hits, col.sort);
    }
  }
 
}
</script>
