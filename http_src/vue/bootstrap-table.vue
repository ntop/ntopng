<template>
  <!-- Normal table -->
  <table v-if="!horizontal" class="table table-hover table-borderless mb-0">
    <thead>
      <tr>
        <th v-for="col in columns" scope="col" v-html="print_html_column(col)"></th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in rows">
        <td v-for="col in columns" scope="col" v-html="print_html_row(col, row)"></td>
      </tr>
    </tbody>
  </table>
  <!-- Horizontal table, with th on the rows -->
  <table v-else class="table table-hover table-borderless mb-0">
    <tbody>
      <tr v-for="row in rows">
        <th class="col 5" v-html="print_html_title(row.name)"></th>
        <td v-for="value in row.values" v-html="print_html_row(value)"></td>
      </tr>
    </tbody>
  </table>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

const props = defineProps({
  id: String,
  columns: Array,
  rows: Array,
  print_html_column: Function,
  print_html_row: Function,
  horizontal: Boolean,
});

</script>
