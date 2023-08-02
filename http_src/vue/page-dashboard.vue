<!-- (C) 2023 - ntop.org -->
<template>
<div class='row'>
  <DateTimeRangePicker v-if="enable_date_time_range_picker"
		       id="dashboard-date-time-picker"
		       @epoch_change="set_components_epoch_interval">
  </DateTimeRangePicker>
  
  <template v-for="c in components">
    <Box :title="_i18n(c.i18n_name)" 
         :title_gray="c.time_offset ? _i18n('dashboard.time_ago.' + c.time_offset) : ''"
         :col_width="c.width" 
         :col_height="c.height"
         :epoch_begin="c.epoch_begin"
         :epoch_end="c.epoch_end">
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
  </template>
</div> <!-- div row -->
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility, ntopng_events_manager } from "../services/context/ntopng_globals_services";

import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as SimpleTable } from "./simple-table.vue";
import { default as EmptyComponent } from "./empty-component.vue";
import { default as Box } from "./box.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const components_dict = {
    "simple-table": SimpleTable,
    "empty": EmptyComponent,
}
const components = ref([]);
const page_id = "page-dashboard";
const default_ifid = props.context.ifid;
const page = ref("");

const enable_date_time_range_picker = computed(() => {
    return props.context.page == "report";
});

onBeforeMount(async () => {
    let epoch_interval = null;
    if (props.context.page == "report") {
	epoch_interval = ntopng_utility.check_and_set_default_time_interval(undefined, undefined, true);
    }
    await load_components(epoch_interval);
});

onMounted(async () => {
    if (props.context.page == "dashboard") {
	start_dashboard_refresh_loop();
    }
});

let dasboard_loop_interval;
const loop_interval = 5 * 1000;
function start_dashboard_refresh_loop() {
    dasboard_loop_interval = setInterval(() => {
	set_components_epoch_interval();
    }, loop_interval);
}

function set_components_epoch_interval(epoch_interval) {
    const timeframes_dict = ntopng_utility.get_timeframes_dict();
    components.value.forEach((c, i) => {
	update_component_epoch_interval(timeframes_dict, c, epoch_interval);
    });
}

async function load_components(epoch_interval) {
    let url_request = `${http_prefix}/lua/pro/rest/v2/get/dashboard/template.lua?template=${props.context.template}`;
    let res = await ntopng_utility.http_request(url_request);
    const timeframes_dict = ntopng_utility.get_timeframes_dict();
    components.value = res.list.filter((c) => components_dict[c.component] != null)
	.map((c, index) => {
	    let c2 = {
		component_id: get_component_id(c.id, index),
		...c
	    };
	    update_component_epoch_interval(timeframes_dict, c2, epoch_interval);
	    return c2;
	});
    await nextTick();
}

function update_component_epoch_interval(timeframes_dict, c, epoch_interval) {
    const interval_seconds = timeframes_dict[c.time_window || "5_min"];
    if (epoch_interval == null) {
	const epoch_end = ntopng_utility.get_utc_seconds();
	epoch_interval = { epoch_begin: epoch_end - interval_seconds, epoch_end: epoch_end };
    }
    const utc_offset = timeframes_dict[c.time_offset] || 0;
    c.epoch_begin = epoch_interval.epoch_begin - utc_offset;
    c.epoch_end = epoch_interval.epoch_end - utc_offset;
}

function get_component_id(id, index) {
    return `${page_id}_${id}_${index}`;
}
</script>

<style scoped>
</style>
