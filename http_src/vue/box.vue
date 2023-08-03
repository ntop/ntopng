<!--
  (C) 2013-22 - ntop.org
-->
<template>
    <div :class="col_width_class" class="widget-box-main-dashboard">
      <div :class="row_height_class" class="widget-box">
        <h4 v-if="title" class="dashboard-component-title" 
            :title="ntopng_utility.from_utc_to_server_date_format(epoch_begin * 1000, 'DD/MM/YYYY HH:mm') + ' - ' + ntopng_utility.from_utc_to_server_date_format(epoch_end * 1000, 'DD/MM/YYYY HH:mm')">{{ title }} <span style="color: gray">{{ title_gray }}</span></h4>
	<slot name="box_content"></slot>
      </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility, ntopng_events_manager } from "../services/context/ntopng_globals_services";
  
const props = defineProps({
  title: String,
  title_gray: String,
  color: String,
  col_width: Number,
  row_height: Number,
  epoch_begin: Number,
  epoch_end: Number,
});

const col_width_class = computed(() => {
    return `col-${props.col_width || 4}`;
});

const row_height_class = computed(() => {
    let color_class = ``;

    if (props.color) {
        /* Accepted colors: primary, secondary, success, danger, warning, info, light, dark, white */
        color_class = `bg-${props.color}`;
    }

    return `row-${props.row_height || 4} ${color_class}`;
});
</script>

<style scoped>
</style>
