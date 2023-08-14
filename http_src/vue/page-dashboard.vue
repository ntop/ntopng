<!-- (C) 2023 - ntop.org -->
<template>
<div class='row'>
  <DateTimeRangePicker v-if="enable_date_time_range_picker"
                       id="dashboard-date-time-picker"
                       @epoch_change="set_components_epoch_interval">
    <template v-slot:extra_buttons>
      <button class="btn btn-link btn-sm"
              @click="print_report" :title="_i18n('dashboard.print')">
        <i class="fas fa-print"></i>
      </button>
    </template>
  </DateTimeRangePicker>
  
  <div ref="report_box" class="row">
    <template v-for="c in components">
      <Box style="min-width:20rem;"
           :color="c.color"
           :width="c.width" 
           :height="c.height">
        <template v-slot:box_title>
          <div v-if="c.i18n_name" class="dashboard-component-title">
            <h4>
              {{ _i18n(c.i18n_name) }}
              <span style="color: gray">
                {{ c.time_offset ? _i18n('dashboard.time_ago.' + c.time_offset) : '' }}
              </span>
            </h4>
          </div>
        </template>
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
        <template v-slot:box_footer>
          <span v-if="c.component != 'empty' && c.i18n_name" style="color: lightgray;font-size:12px;">
            {{ component_interval(c) }}
          </span>
        </template>
      </Box>
    </template>
  </div>
</div> <!-- div row -->
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility, ntopng_events_manager } from "../services/context/ntopng_globals_services";

import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as SimpleTable } from "./simple-table.vue";
import { default as EmptyComponent } from "./empty-component.vue";
import { default as Badge } from "./badge.vue";
import { default as Pie } from "./pie.vue";
import { default as Box } from "./box.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const components_dict = {
    "badge": Badge,
    "empty": EmptyComponent,
    "pie": Pie,
    "simple-table": SimpleTable,
}
const components = ref([]);
const page_id = "page-dashboard";
const default_ifid = props.context.ifid;
const report_box = ref(null);

const enable_date_time_range_picker = computed(() => {
    return props.context.page == "report";
});

const component_interval = computed(() => {
    return (c) => {
        const begin = ntopng_utility.from_utc_to_server_date_format(c.epoch_begin * 1000, 'DD/MM/YYYY HH:mm:ss');
        const end = ntopng_utility.from_utc_to_server_date_format(c.epoch_end * 1000, 'DD/MM/YYYY HH:mm:ss');
        return  `${begin} - ${end}`;
    };
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

/* Dashboard update interval/frequency */
const loop_interval = 10 * 1000;

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
    let url_request = `${http_prefix}/lua/pro/rest/v2/get/dashboard/template.lua?page=${props.context.page}&template=${props.context.template}`;
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

function print_report() {
    $(report_box.value).print();
}

</script>

<style scoped>
/* @media print and (orientation: portrait) and (max-width: 297mm){ */
/*     .col-4 { */
/*         width: 50% !important; */
/*         flex: 0 0 auto; */
/*     } */
/* } */
@page {
    /* position:absolute; width:100%; top:0;left:0;right:0;bottom:0; padding:0; margin:-1px; */
}

/* Print on A4 */
@media print and (max-width: 297mm) and (min-width: 210mm) {
    /* .row { */
    /*         padding-left: 0; */
    /*         padding-right: 0; */
    /*         margin-left: -10rem; */
    /*         margin-right: 0; */
    /* } */
   .col-4 {
        width: 50% !important;
        flex: 0 0 auto;
    }
}

/* Print on A5 (commented out as this is not working on Chrome/Safari) */
/*
@media print and (max-width: 148mm){
    .col-4 {
        width: 100% !important;
        flex: 0 0 auto;
    }
    .col-6 {
        width: 100% !important;
        flex: 0 0 auto;
    }
}
*/

.align-center {
}
</style>
