<!--
  (C) 2013-22 - ntop.org
-->

<template>
<BootstrapTable
  :id="table_id" 
  :columns="params.columns"
  :rows="table_rows"
  :print_html_column="render_column"
  :print_html_row="render_row">
</BootstrapTable>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";

const _i18n = (t) => i18n(t);

const table_id = ref('simple_table');
const table_rows = ref([]);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: Number,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end], (cur_value, old_value) => {
    refresh_table();
}, { flush: 'pre'});

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
  throughput: function (column, row) {
    if (column.id == 'name') {
      if (row['url'])
        return `<a href='${row.url}'>${row.name}</a>`;
      else
        return row.name;
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

  db_search: function (column, row) {
    if (column.data_type == 'host') {
      return NtopUtils.formatHost(row[column.id], row, (column.id == 'cli_ip'));
    } else if (formatterUtils.types[column.data_type]) {
      // 'bytes', 'bps', 'pps', ...
      let formatter = formatterUtils.getFormatter(column.data_type);
      return formatter(row[column.id]);
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
  //const params = ntopng_url_manager.get_url_object();
  const url_params = {
     ifid: props.ifid,
     epoch_begin: props.epoch_begin,
     epoch_end: props.epoch_end,
     ...props.params.url_params
  }
  const query_params = ntopng_url_manager.obj_to_url_params(url_params);

  let data = await ntopng_utility.http_request(`${http_prefix}${props.params.url}?${query_params}`);

  let rows = [];
  if (props.params.table_type == 'db_search') {
    rows = data.records;
  } else {
    rows = data;
  }

  const max_rows = props.max_height ? ((props.max_height/4) * 6) : 6;
  rows = rows.slice(0, max_rows);

  table_rows.value = rows;
}
</script>
