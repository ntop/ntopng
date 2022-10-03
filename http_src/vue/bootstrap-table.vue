<template>
<table class="table">
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
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

const props = defineProps({
    id: String,
    columns: Array,
    rows: Array,
    print_html_column: Function,
    print_html_row: Function,
});

</script>
