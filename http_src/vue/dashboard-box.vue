<!--
  (C) 2013-22 - ntop.org
ntopng_utility.from_utc_to_server_date_format(epoch_begin * 1000, 'DD/MM/YYYY HH:mm') + ' - ' + ntopng_utility.from_utc_to_server_date_format(epoch_end * 1000, 'DD/MM/YYYY HH:mm')
-->
<template>
  <div :class="width_class" class="widget-box-main-dashboard">
    <div :class="height_class" class="widget-box" style="position:relative;">
      <!-- title -->
      <slot name="box_title"></slot>

      <!-- content -->
      <slot name="box_content"></slot>

      <!-- footer -->
      <div class="mb-1 me-3" style="position:absolute;bottom:0px;right:0px;">
        <slot name="box_footer"></slot>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from "vue";

const props = defineProps({
  color: String,
  width: Number,
  height: Number,
});

const width_class = computed(() => {
  return `col-${props.width || 4}`;
});

const height_class = computed(() => {
  let color_class = ``;

  if (props.color) {
    /* Accepted colors: primary, secondary, success, danger, warning, info, light, dark, white */
    color_class = `bg-${props.color}`;
  }

  return `row-${props.height || 4} ${color_class}`;
});
</script>

