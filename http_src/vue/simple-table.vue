<!--
  (C) 2013-22 - ntop.org
-->

<template>
    <BootstrapTable :id="table_id" 
        :columns="params.columns"
        :rows="table_rows"
        :print_html_column="(col) => render_column(col)"
        :print_html_row="(col, row) => render_row(col, row)">
    </BootstrapTable>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('simple_table');
const table_rows = ref([]);

const props = defineProps({
  i18n_title: String,
  ifid: Number,
  max_width: Number,
  max_height: Number,
  params: Object,
});

const render_column = function (column) {
  if (column.i18n_name) return _i18n(column.i18n_name)
  return "";
}

const render_row = function (column, row) {
  if (row[column.id])
    return row[column.id];
  else
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

onMounted(async () => {
  refresh_table();
});

</script>
