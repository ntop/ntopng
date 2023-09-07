<!--
  (C) 2013-22 - ntop.org
-->

<template>
   <div class="row">
      <BootstrapTable
      id="about_table"
	   :columns="stats_columns"
      :rows="stats_rows"
      :print_html_row="(col, row) => print_stats_row(col, row)">
      </BootstrapTable>
   </div>
</template>

<script setup>
import { ref } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";

const stats_rows = ref([]);
const stats_columns = [
   { id: "info", hidden: true },
   { id: "data", hidden: true },
];
get_stats();

async function get_stats() {
   let url = `${http_prefix}/lua/rest/v2/get/ntopng/about.lua`;
   
   let info_obj = await ntopng_utility.http_request(url);
   let info = ntopng_utility.object_to_array(info_obj);
   stats_rows.value = info
}

function print_stats_row(col, row) {
   // debugger;
   return row;
}

</script>