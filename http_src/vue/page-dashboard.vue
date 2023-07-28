<!-- (C) 2023 - ntop.org -->
<template>
<div class='row'>
  <template v-for="c in components">
    <Box :title="_i18n(c.i18n_name)" :col_width="c.width" :col_height="c.height">
      <template v-slot:box_content>
        <component :is="components_dict[c.component]"
		   :id="c.component_id"
		   :epoch_begin="c.epoch_begin"
		   :epoch_end="c.epoch_end"
                   :i18n_title="c.i18n_name"
                   :ifid="c.ifid ? c.ifid : context.ifid"
                   :max_width="c.width"
                   :max_height="c.height"
                   :params="c.params">
	</component>
      </template>
    </Box>
    <!-- <span v-if="c.component == 'live-chart'">(this is a live chart)</span> -->
    <!-- <span v-if="c.component == 'timeseries-chart'">(this is a timeseries chart)</span> -->
  </template>
</div> <!-- div row -->
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility, ntopng_events_manager } from "../services/context/ntopng_globals_services";

import { default as SimpleTable } from "./simple-table.vue";
import { default as Box } from "./box.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const components_dict = {
    "simple-table": SimpleTable,
}
const components = ref([]);
const page_id = "page-dashboard";
const default_ifid = props.context.ifid;
const page = ref("");

onBeforeMount(async () => {
    await load_components();
});

onMounted(async () => {
    if (!props.context.page || props.context.page != 'report')
        start_dashboard_refresh_loop();
});

let dasboard_loop_interval;
const loop_interval = 5 * 1000;
function start_dashboard_refresh_loop() {
    dasboard_loop_interval = setInterval(() => {
	set_components_epoch_interval();
    }, loop_interval);
}

function set_components_epoch_interval() {
    const timeframes_dict = ntopng_utility.get_timeframes_dict();
    components.value.forEach((c, i) => {
	update_component_epoch_interval(timeframes_dict, c);
    });
}

async function load_components() {
    let url_request = `${http_prefix}/lua/pro/rest/v2/get/dashboard/template.lua?template=${props.context.template}`;
    let res = await ntopng_utility.http_request(url_request);
    const timeframes_dict = ntopng_utility.get_timeframes_dict();
    components.value = res.list.filter((c) => components_dict[c.component] != null)
	.map((c, index) => {
	    let c2 = {
		component_id: get_component_id(c.id, index),
		...c
	    };
	    update_component_epoch_interval(timeframes_dict, c2);
	    return c2;
	});
    await nextTick();
}

function update_component_epoch_interval(timeframes_dict, c) {
    const interval_seconds = timeframes_dict[c.time_window || "5_min"];
    const utc_offset = timeframes_dict[c.time_offset] || 0;
    const epoch_end = ntopng_utility.get_utc_seconds() - utc_offset;
    const epoch_interval = { epoch_begin: epoch_end - interval_seconds, epoch_end };
    c.epoch_begin = epoch_interval.epoch_begin;
    c.epoch_end = epoch_interval.epoch_end;
}

function get_component_id(id, index) {
    return `${page_id}_${id}_${index}`;
}
</script>

<style scoped>
</style>
