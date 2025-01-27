<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="table-responsive" style="margin-left:-1rem;margin-right:-1rem;">
  <BootstrapTable
    :id="table_id" 
    :columns="columns"
    :rows="table_rows"
    :print_html_column="render_column"
    :print_html_row="render_row"
    :wrap_columns="true">
  </BootstrapTable>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";
import { scan_type_f,last_scan_f, duration_f, scan_frequency_f, is_ok_last_scan_f, tcp_ports_f, tcp_port_f, hosts_f, host_f, cves_f, max_score_cve_f, udp_ports_f, num_vuln_found_f, tcp_udp_ports_list_f, discoverd_hosts_list_f  } from "../utilities/vs_report_formatter.js"; 

const _i18n = (t) => i18n(t);

const table_id = ref('simple_table');
const table_rows = ref([]);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    filters: Object
});

const columns = computed(() => {
    let columns = props.params.columns.map((c) => {
        if (!c.style && c.data_type) {
            if (c.data_type == "bytes" || c.data_type == "date") {
                c.style = "text-align: right";
            } else  if (c.data_type == "count_score") {
                c.style = "text-align: center"
            }
        }

	return {
	    ...c,
	};
    });

    columns[0].class = (columns[0].class ? (columns[0].class + " ") : "") 
      + "first-col-width";

    return columns;
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    refresh_table();
}, { flush: 'pre', deep: true });

onBeforeMount(() => {
    init();
});

onMounted(() => {
});

function init() {
    refresh_table();
}

const render_column = function (column) {
  if (column.i18n_name) { return _i18n(column.i18n_name); }
  return "";
}

const row_render_functions = {
  /* Render function for 'throughput' table type */
  throughput: function (column, row) {
    if (column.id == 'name') {
      let name = row.name;
      if (row['instance_name'])
        name = `${row.name} [${row.instance_name}]`;
      if (row['url'])
        return `<a href='${row.url}'>${name}</a>`;
      else
        return name;
    } else if (column.id == 'throughput') {
      if (row['throughput_type'] && row['throughput_type'] == 'pps') {
        return NtopUtils.fpackets(row[column.id]);
      } else if (row['throughput_type'] && row['throughput_type'] == 'bps') {
        return NtopUtils.bitsToSize(row[column.id]);
      } else {
        return row['throughput'];
      }
    } else {
      return "";
    }
  },

  /* Render function for 'db_search' table type */
  db_search: function (column, row) {
    if (column.data_type == 'host') {
      return NtopUtils.formatHost(row[column.id], row, (column.id == 'cli_ip'));
    } else if (column.data_type == 'network') {
      return NtopUtils.formatNetwork(row[column.id], row);
    } else if (column.data_type == 'asn') {
      return NtopUtils.formatASN(row[column.id], row);
    } else if (column.data_type == 'country') {
      return NtopUtils.formatCountry(row[column.id], row);
    } else if (formatterUtils.types[column.data_type]) {
      // 'bytes', 'bps', 'pps', ...
      let formatter = formatterUtils.getFormatter(column.data_type);
      return formatter(row[column.id]);
    } else if (typeof row[column.id] === 'object') {
      return NtopUtils.formatGenericObj(row[column.id], row);
    } else {
      return row[column.id];
    }
  },

  vs_scan_result: function(column, row) {
    if(column.id == "host") {
      return host_f(row[column.id], row, props.ifid);
    } else if(column.id == "last_scan") {
      return last_scan_f(row[column.id], row);
    } else if(column.id == "duration") {
      return duration_f(row[column.id], row);
    } else if(column.id == "scan_frequency") {
      return scan_frequency_f(row[column.id]);
    } else if(column.id == "is_ok_last_scan") {
      return is_ok_last_scan_f(row[column.id]);
    } else if(column.id == "tcp_ports") {
      return tcp_ports_f(row[column.id], row);
    } else if(column.id == "udp_ports") {
      return udp_ports_f(row[column.id], row);
    }  else if(column.id == "scan_type") {
      return scan_type_f(row[column.id], true, row);
    } else if (column.id == "hosts") {
      return hosts_f(row[column.id], row);
    } else if (column.id == "cve" || column.id == "cve_list") {
      return cves_f(row[column.id], row);
    } else if (column.id == "port") {
      return tcp_port_f(row[column.id],row);
    } else if (column.id == "max_score_cve") {
      return max_score_cve_f(row[column.id],row);
    } else if (column.id == "num_vulnerabilities_found") {
      return num_vuln_found_f(row[column.id],row);
    } else if (column.id == "tcp_udp_ports_list") {
      return tcp_udp_ports_list_f(row["tcp_ports_list"], row["udp_ports_list"], row);
    } else if (column.id == "discovered_hosts") {
      return discoverd_hosts_list_f(row[column.id]);
    } else {
      return row[column.id];
    }
  }
};

const render_row = function (column, row) {
  if (props.params && 
      props.params.table_type && 
      row_render_functions[props.params.table_type]) {
    const render_func = row_render_functions[props.params.table_type];
    return render_func(column, row);
  } else if (row[column.id]) {
    return row[column.id];
  } else {
    return "";
  }
}

async function refresh_table() {
  const url_params = {
     ifid: props.ifid,
     epoch_begin: props.epoch_begin,
     epoch_end: props.epoch_end,
     ...props.params.url_params,
        ...props.filters
  }
 
  let data = await props.get_component_data(`${http_prefix}${props.params.url}`, url_params, undefined, props.epoch_begin);

  let rows = [];
  if (props.params.table_type == 'db_search') {
    rows = data.records; /* db_search: read data from data.records */
  } else {
    rows = data; /* default: data is the array of records */
  }

  if ( props.params.table_type != 'vs_scan_result') {
    const max_rows = props.max_height ? ((props.max_height/4) * 6) : 6;
    rows = rows.slice(0, max_rows);
  } 

  table_rows.value = rows;
}
</script>

<style>
.first-col-width {
    /* max-width: 100% !important; */
}

@media print and (max-width: 210mm) {
    td.first-col-width {
	max-width: 55mm !important;
    }
}
@media print and (min-width: 211mm) {
    td.first-col-width {
	max-width: 95mm !important;
    }
}

/* @media print and (max-width: 148mm){ */
/* } */

</style>
