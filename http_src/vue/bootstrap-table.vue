<!--
    (C) 2013-22 - ntop.org
-->
<template>
  <!-- Normal table -->
  <table v-if="!(horizontal) || (horizontal == false)" class="ntopng-table">
    <thead v-if="!hide_head">
      <tr>
        <th v-for="col in columns" scope="col" :class="col.class" v-html="print_html_column(col)"></th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in rows">
        <td v-if="wrap_columns" v-for="col in columns" scope="col" :class="col.class">
          <div class="wrap-column" :style="col.style" v-html="print_html_row(col, row)"></div>
        </td>
        <td v-else v-for="col in columns" scope="col" :class="col.class" class="wrap-column" :style="col.style"
          v-html="print_html_row(col, row)">
        </td>
      </tr>
    </tbody>
  </table>
  <table v-else class="ntopng-table">
    <tbody>
      <tr v-for="row in rows">
        <th v-if="head_width" :class="'col-' + head_width" v-html="print_html_title(row.name)"></th>
        <th v-else class="col-2" v-html="print_html_title(row.name)"></th>
        <td :class="row_class" style="overflow-wrap:anywhere; max-width: 500px;"
          :colspan="[(row.values.length <= 1) ? 2 : 1]" v-for="value in row.values" v-html="print_html_row(value)">
        </td>
      </tr>
    </tbody>
  </table>
</template>

<script setup>
import { ref, onBeforeMount } from "vue";

const row_class = ref();
const props = defineProps({
  id: String,
  columns: Array,
  rows: Array,
  print_html_column: Function,
  print_html_row: Function,
  print_html_title: Function,
  horizontal: Boolean,
  wrap_columns: Boolean,
  hide_head: Boolean,
  no_background: Boolean,
  head_width: Number,
  row_width: Number,
  text_align: String
});

onBeforeMount(() => {
  let classes = ''
  if (props.row_width) {
    classes = classes + ' col-' + props.row_width
  }
  if (props.text_align) {
    classes = classes + ' ' + props.text_align
  }
  row_class.value = classes
})
</script>

<style scoped>
.ntopng-table {
  border: none;
  border-collapse: separate;
  border-spacing: 0;
  width: 100%;
  margin-bottom: 1rem;
  color: #212529;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
}
.ntopng-table thead th {
  background-color: #f8f9fa;
  color: #495057;
  font-weight: 600;
  border: none;
  padding: 0.75rem;
  border-bottom: 1px solid #e9ecef;
  text-transform: capitalize;
  position: relative;
}
.ntopng-table tbody tr {
  transition: background-color 0.2s ease;
  height: 2.75rem;
}
.ntopng-table tbody tr td {
  padding: 0.5rem 0.75rem;
  vertical-align: middle;
  border: none;
  border-bottom: 1px solid #e9ecef;
  height: 2.75rem;
}
.ntopng-table tbody tr:last-child td {
  border-bottom: none;
}
.ntopng-table tbody tr:hover {
  background-color: rgba(0, 123, 255, 0.03);
}
.wrap-column {
  text-overflow: ellipsis;
  white-space: nowrap;
  overflow: hidden;
  width: 100%;
  color: #212529;
  font-size: 0.9rem;
  line-height: 1.4;
  padding: 0;
  margin: 0;
}
@media (max-width: 768px) {
  .ntopng-table {
    display: block;
    overflow-x: auto;
  }
}
</style>
