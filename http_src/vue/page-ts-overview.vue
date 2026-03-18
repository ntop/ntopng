<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="page-ts-overview">
    <TableWithConfig table_config_id="ts_overview" />
  </div>
</template>

<script setup>
import { default as TableWithConfig } from "./table-with-config.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});
</script>
