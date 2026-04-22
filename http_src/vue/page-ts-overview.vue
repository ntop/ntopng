<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="page-ts-overview">
    <TableWithConfig table_config_id="ts_overview" :f_map_columns="map_table_def_columns" />
  </div>
</template>

<script setup>
import { default as TableWithConfig } from "./table-with-config.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});


const map_table_def_columns = (columns) => {
    //country_details.lua?country=IT&page=historical

    let map_columns = {
      "timeseries": (value, row) => {
        return `
          <div>
            <ul>
              ${Object.keys(value).map(key => `<li>${key}</li>`).join('')}
            </ul>
          </div>
        `;
      }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        
    });

    return columns;
};

</script>
