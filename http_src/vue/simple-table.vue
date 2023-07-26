<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="mt-4 card card-shadow">
        <div class="card-body">
          <BootstrapTable :id="table_id" :columns="params.columns" :rows="table_rows"
            :print_html_column="(col) => render_column(col)"
            :print_html_row="(col, row) => render_row(col, row)">
          </BootstrapTable>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('simple_table');
const table_rows = ref([]);

const props = defineProps({
  //ifid: Number,
  //csrf: String,
  i18n_title: String,
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
  const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const data = await ntopng_utility.http_request(`${http_prefix}${props.params.url}?${url_params}`);
  table_rows.value = data;
}

onMounted(async () => {
  refresh_table();
  setTimeout(() => refresh_table(), 5000);
});

</script>
