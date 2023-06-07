<template>
  <table class="table table-hover table-borderless mb-0">
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
  rows: Array,
  print_html_title: Function,
  print_html_row: Function,
});

</script>
