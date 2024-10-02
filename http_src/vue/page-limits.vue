<!--
  (C) 2013-24 - ntop.org
-->

<template>
  <div class="card h-100 overflow-hidden">
    <div class="m-2 mb-3">
      <TableWithConfig :table_id="table_id" :f_map_columns="map_table_def_columns"
        :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting">
      </TableWithConfig>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

const table_id = ref('limits_table')

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

const map_table_def_columns = (columns) => {
  let map_columns = {
    "limit": (value, row) => {
      return (i18n("limits_page." + value) || value);
    },
    "current": (value, row) => {
      if (value < row.max) {
        return `<span class="text-success">${value}</span>`;
      } else {
        return `<span class="text-danger">! ${value}</span>`;
      }
    },
    "max": (value, row) => {
      if (row.current < value) {
        return `<span class="text-success">${value}</span>`;
      } else {
        return `<span class="text-danger">! ${value}</span>`;
      }
    },
  };
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });

  return columns;
};

/* ************************************** */

function columns_sorting(col, r0, r1) {
  if (col != null) {
    const r0_col = r0[col.data.data_field];
    const r1_col = r1[col.data.data_field];

    /* In case the values are the same, sort by Name */
    if (r0_col == r1_col) {
      return sortingFunctions.sortByName(r0.device, r1.device, col ? col.sort : null);
    } else if (col.id == "limit") {
      return sortingFunctions.sortByName(r0.device, r1.device, col ? col.sort : null);
    } else if (col.id == "current") {
      const lower_value = -1;
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
    } else if (col.id == "max") {
      const lower_value = -1;
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
    }
  }

  return sortingFunctions.sortByName(r0.device, r1.device, col ? col.sort : null);
}

</script>
