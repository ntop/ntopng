<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="table_topology" :table_id="table_id" :csrf="context.csrf"
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
import NtopUtils from "../utilities/ntop-utils";

/* ******************************************************************** */

const snmp_interface_href = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=%host&snmp_port_idx=%interface`;
const snmp_device_href = `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?ip=%ip`
const mac_href = `${http_prefix}/lua/mac_details.lua?ip=%ip`

/* Consts */
const _i18n = (t) => i18n(t);

const note_list = [
  _i18n("snmp.snmp_note_periodic_interfaces_polling"),
  _i18n("snmp.snmp_note_thpt_calc"),
  _i18n("snmp.snmp_lldp_cdp_descr")
]
const snmp_status = {
  "1": "<font color=green>" + _i18n("snmp.status_up") + "</font>",
  "2": "<font color=red>" + _i18n("snmp.status_down") + "</font>",
  "3": _i18n("snmp.testing"),
  "4": _i18n("snmp.status_unknown"),
  "5": _i18n("snmp.status_dormant"),
  "6": _i18n("status_notpresent"),
  "7": "<font color=red>" + _i18n("snmp.status_lowerlayerdown") + "</font>",
  "101": "<font color=green>" + _i18n("snmp.status_up_in_use") + "</font>",
}

const lldp_span = `<span class="badge bg-info">${_i18n('snmp.lldp')}</span>`
const cdp_span = `<span class="badge bg-info">${_i18n('snmp.cdp')}</span>`
const trunk_span = `<span class="badge bg-info">${_i18n('trunk')}</span>`

const table_id = ref("snmp_topology");
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
    if (col.id == "thpt") {
      return sortingFunctions.sortByNumber(r0.port.thpt, r1.port.thpt, col.sort);
    } else if (col.id == "vlan") {
      return sortingFunctions.sortByName(r0.port.vlan, r1.port.vlan, col.sort);
    } else if (col.id == "interface") {
      return sortingFunctions.sortByName(r0.port.interface_name, r1.port.interface_name, col.sort);
    } else if (col.id == "device") {
      return sortingFunctions.sortByName(r0.port.device_name, r1.port.device_name, col.sort);
    } else if (col.id == "port_status") {
      return sortingFunctions.sortByNumber(r0.port.port_status, r1.port.port_status, col.sort);
    } else if (col.id == "lldp_remote_sys_name") {
      return sortingFunctions.sortByName(r0.remote_port.sys_name, r1.remote_port.sys_name, col.sort);
    } else if (col.id == "lldp_remote_port_id") {
      let r0_val = r0.remote_port.port_id;
      let r1_val = r1.remote_port.port_id;
      if (typeof (r0.remote_port.port_id) == 'object')
        r0_val = r0.remote_port.port_id.mac;
      if (typeof (r1.remote_port.port_id) == 'object')
        r1_val = r1.remote_port.port_id.mac;
      return sortingFunctions.sortByName(r0_val, r1_val, col.sort);
    } else if (col.id == "lldp_remote_port_descr") {
      return sortingFunctions.sortByName(r0.remote_port.port_descr, r1.remote_port.port_descr, col.sort);
    } else if (col.id == "lldp_remote_sys_descr") {
      return sortingFunctions.sortByName(r0.remote_port.sys_descr, r1.remote_port.sys_descr, col.sort);
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
    "thpt": (_, row) => {
      if(!row.port.thpt)
        return ''
      return NtopUtils.bitsToSize(row.port.thpt);
    },
    "interface": (_, row) => {
      const local_port = row.port;
      return `<a href='${snmp_interface_href.replace('%host', local_port.device_ip).replace('%interface', local_port.interface)}'>${local_port.interface_name}</a>${local_port.is_lldp ? ' ' + lldp_span : ''}${local_port.is_cdp ? ' ' + cdp_span : ''}${local_port.is_trunk ? ' ' + trunk_span : ''}`;
    },
    "vlan": (_, row) => {
      return row.port.vlan || '';
    },
    "device": (_, row) => {
      const local_port = row.port;
      return `<a href='${snmp_device_href.replace('%ip', local_port.device_ip)}'>${local_port.device_name}</a>`;
    },
    "port_status": (_, row) => {
      return snmp_status[row.port.port_status];
    },
    "lldp_remote_sys_name": (_, row) => {
      return row.remote_port.sys_name;
    },
    "lldp_remote_port_id": (_, row) => {
      if (typeof (row.remote_port.port_id) == 'object') {
        if (row.remote_port.port_id.in_memory)
          return `<a href='${mac_href.replace('%mac', row.remote_port.port_id.mac)}'>${row.remote_port.port_id.mac}</a>`;
        else
          return row.remote_port.port_id.mac
      } else
        return row.remote_port.port_id
    },
    "lldp_remote_port_descr": (_, row) => {
      return row.remote_port.port_descr;
    },
    "lldp_remote_sys_descr": (_, row) => {
      return row.remote_port.sys_descr;
    },
  };
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });

  return columns;
};

</script>