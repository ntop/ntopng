<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div></div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";

const _i18n = (t) => i18n(t);

const component_id = ref('empty_component');

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: Number,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end], (cur_value, old_value) => {
    refresh_component();
}, { flush: 'pre'});

onBeforeMount(() => {
    init();
});

onMounted(() => {
});

function init() {
    refresh_component();
}

async function refresh_component() {
  /* Refresh component */
}
</script>
