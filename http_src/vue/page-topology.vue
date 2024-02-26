<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card card-shadow">
        <div class="card-body">
            <TableWithConfig
              ref="table_topology"
              :table_id="table_id"
              :csrf="context.csrf"
              :f_map_columns="map_table_def_columns"
              :get_extra_params_obj="get_extra_params_obj"
              :f_sort_rows="columns_sorting"
              @rows_loaded="on_table_loaded"
            >
            </TableWithConfig>
        </div>
        <div class="card-footer">
          <NoteList :note_list="note_list"> </NoteList>
        </div>
      </div>
    </div>
  </div>
</template>
  
<script setup>
/* Imports */
import { ref } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { columns_formatter } from "../utilities/vs_report_formatter.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import NtopUtils from "../utilities/ntop-utils";

/* ******************************************************************** */

/* Consts */
const _i18n = (t) => i18n(t);

const note_list = [
  _i18n("snmp.snmp_note_periodic_interfaces_polling"),
  _i18n("snmp.snmp_note_thpt_calc"),
  _i18n("snmp.snmp_lldp_cdp_descr")
]

const table_id = ref("topology");
const table_topology = ref();
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

    
    if (col.id == "port_id") {
      return sortingFunctions.sortByNumber(r0_col, r1_col, col.sort);
    } else if (col.id == "port_thpt_value") {
      return sortingFunctions.sortByNumber(r0_col, r1_col, col.sort);
    } else {  
      return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
    }
  }

}

/* Get the number of rows of the table */
function on_table_loaded() {
  total_rows.value = table_topology.value.get_rows_num();
}

/* ******************************************************************** */

/* Function to map columns data */
const map_table_def_columns = (columns) => {
  let map_columns = {
    "uplink_speed": (data, row) => {
      return NtopUtils.bitsToSize(data);
    },
    "downlink_speed": (data, row) => {
      return NtopUtils.bitsToSize(data);
    },
    "port_thpt_value": (data, row) => {
      return NtopUtils.bitsToSize(data);
    }
  };
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });
  
  return columns;
};

</script>
  