<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="table_similarity" :table_id="table_id" :csrf="context.csrf"
      :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting"
      @rows_loaded="on_table_loaded">
    </TableWithConfig>
    <div class="card-footer">
      <NoteList :note_list="note_list"> </NoteList>
    </div>
  </div>
</template>

<script setup>
/* Imports */
import { ref } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import formatterUtils from "../utilities/formatter-utils";

/* ******************************************************************** */

/* Consts */
const _i18n = (t) => i18n(t);

const note_list = [
  _i18n("snmp.snmp_similarity_note"),
  _i18n("snmp.snmp_similarity_time_note")
]

const timestamp = Math.floor(Date.now() / 1000);
const device_href = `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?host=%host`;
const interface_href = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=%host&snmp_port_idx=%ifid&page=historical&epoch_begin=${timestamp - 86400}&epoch_end=${timestamp}`;
const table_id = ref("snmp_similarity");
const table_similarity = ref();
const total_rows = ref(0);

const props = defineProps({
  context: Object,
});

const context = ref({
  csrf: props.context.csrf,
  ifid: props.context.ifid,
});



const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};


/* This function simply return the data of the exact column and row requested */
function column_data(col, row) {
  let data = row[col.data.data_field];
  if (col.data.data_field == "port_id") {
    return Number(data.split(">")[1].split("<")[0]);
  }
  return data;
}


/* Function used to sort the columns of the table */
function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = column_data(col, r0);
    let r1_col = column_data(col, r1);


    if (col.id == "average_traffic_a" || col.id == "average_traffic_b" || col.id == "similarity") {
      return sortingFunctions.sortByNumber(r0_col, r1_col, col.sort);
    } else if (col.id == "device_a" || col.id == "device_b") {
      return sortingFunctions.sortByName(r0_col.name, r1_col.name, col.sort);
    } else if (col.id == "port_a" || col.id == "port_b") {
      return sortingFunctions.sortByName(r0_col.name, r1_col.name, col.sort);
    }
  }

}

/* Get the number of rows of the table */
function on_table_loaded() {
  total_rows.value = table_similarity.value.get_rows_num();
}

/* ******************************************************************** */

/* Function to map columns data */
const map_table_def_columns = (columns) => {
  let map_columns = {
    "device_a": (data, row) => {
      return `<a href='${device_href.replace('%host', data.ip)}'>${data.name}</a>`;
    },
    "device_b": (data, row) => {
      return `<a href='${device_href.replace('%host', data.ip)}'>${data.name}</a>`;
    },
    "port_a": (data, row) => {
      return `<a href='${interface_href.replace('%host', row.device_a.ip).replace('%ifid', data.port)}'>${data.name}</a>`;
    },
    "port_b": (data, row) => {
      return `<a href='${interface_href.replace('%host', row.device_b.ip).replace('%ifid', data.port)}'>${data.name}</a>`;
    },
    "average_traffic_a": (data, row) => {
      return formatterUtils.getFormatter("bps_no_scale")(data);
    },
    "average_traffic_b": (data, row) => {
      return formatterUtils.getFormatter("bps_no_scale")(data);
    },
  };
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });

  return columns;
};

</script>