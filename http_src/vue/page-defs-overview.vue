<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="page-defs-overview">
    <TableWithConfig
      table_config_id="defs_overview"
      :f_map_columns="mapColumns"
    />
  </div>
</template>

<script setup>
import { default as TableWithConfig } from "./table-with-config.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

function mapColumns(columns) {
  const renderers = {
    has_attacker: (value) => value === true ? "<i class='fas fa-check text-success'></i>" : "",
    has_victim:   (value) => value === true ? "<i class='fas fa-check text-success'></i>" : "",
    name: (value, row) => {
      if (row.to_be_migrated) return "<small><i>*To be migrated</i></small>";
      return value || "";
    },
    status_key: (value) => (value != null ? String(value) : ""),
  };

  columns.forEach((c) => {
    if (renderers[c.data_field]) {
      c.render_func = renderers[c.data_field];
    }
  });

  return columns;
}
</script>
