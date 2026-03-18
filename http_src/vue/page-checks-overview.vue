<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="page-checks-overview">
    <TableWithConfig
      table_config_id="checks_overview"
      :get_extra_params_obj="getExtraParams"
      :f_map_columns="mapColumns"
    />
  </div>
</template>

<script setup>
import { default as TableWithConfig } from "./table-with-config.vue";
import formatterUtils from "../utilities/formatter-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

function getExtraParams() {
  return { ifid: props.context.ifid };
}

function mapColumns(columns) {
  const formatMs = formatterUtils.getFormatter("ms");

  columns.forEach((c) => {
    if (c.data_field === "num_filtered") {
      c.render_func = (value) => formatterUtils.getFormatter("number")(value ?? 0);
    } else if (c.data_field === "exec_time_ms") {
      c.render_func = (value) => (value != null ? formatMs(value) : "");
    }
  });

  return columns;
}
</script>
