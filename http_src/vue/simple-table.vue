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

const render_row = function (column, row) {
  if (row[column.id]) {

    /* Rendering fields by guessing content (TODO pass rendering function with the data) */
    if (column.id == 'name' && row['url']) {
      return `<a href='${row.url}'>${row[column.id]}</a>`;
    } else if (column.id == 'throughput' && row['throughput_type']) {
      if (row['throughput_type'] == 'pps') {
        return NtopUtils.fpackets(row[column.id]);
      } else if (row['throughput_type'] == 'bps') {
        return NtopUtils.bitsToSize(row[column.id]);
      }
    }

    return row[column.id];
  }

  return "";
}

async function refresh_table() {
  const extra_params = ntopng_url_manager.get_url_object();
  extra_params['ifid'] = props.ifid;
  const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const data = await ntopng_utility.http_request(`${http_prefix}${props.params.url}?${url_params}`);
  const max_rows = props.max_height ? ((props.max_height/4) * 6) : 6;
  const rows = data.slice(0, max_rows);
    table_rows.value = rows;
}
</script>
