<!--
  (C) 2013-24 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="mt-4 card card-shadow">
        <div class="card-body">
          <BootstrapTable :horizontal="true" :id="table_id" :rows="stats_rows" :print_html_title="print_html_title"
            :print_html_row="print_stats_row" :head_width="8" :row_width="2" :text_align="'text-end'">
          </BootstrapTable>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

const url = "/lua/rest/v2/get/ntopng/limits.lua";
const stats_rows = ref([]);
const table_id = ref('limits_table')

const print_html_title = function (name) {
  return (i18n("limits_page." + name) || name);
}

const print_stats_row = function (value) {
  if (value.current < value.max) {
    return `<span class="text-success">${value.current} / ${value.max}</span>`;
  } else {
    return `<span class="text-danger">! ${value.current} / ${value.max}</span>`;
  }
}

onMounted(async () => {
  const limits = await ntopng_utility.http_request(`${http_prefix}${url}`);
  stats_rows.value = limits
});

</script>
