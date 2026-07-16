<!-- (C) 2026 - ntop.org -->
<template>
  <page-home-map
    :page_csrf="props.context.page_csrf"
    :base_url_params="props.context.url_params"
    :ifid="props.context.ifid"
    :is_admin="props.context.is_admin"
    :map_id="props.context.map_id"
    :view="props.context.view"
    :navbar_info="props.context.navbar_info"
    :service_acceptance="props.context.service_acceptance"
    :service_map_filter_list="props.context.service_map_filter_list"
    :service_table_filter_list="props.context.service_table_filter_list"
    :periodicity_map_filter_list="props.context.periodicity_map_filter_list"
    :periodicity_table_filter_list="props.context.periodicity_table_filter_list"
    :asset_map_filter_list="props.context.asset_map_filter_list"
    :asset_table_filter_list="props.context.asset_table_filter_list">
  </page-home-map>
</template>

<script setup>
import PageHomeMap from "./page-home-map.vue";

const props = defineProps({
  context: Object,
});
</script>
