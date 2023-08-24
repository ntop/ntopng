<!-- (C) 2023 - ntop.org -->
<template>
<div class='row'>

  <ModalSave ref="modal_store_report"
             :get_suggested_file_name="get_suggested_report_name"
             :store_file="store_report"
             :csrf="context.csrf"
             :title="_i18n('dashboard.store')">
  </ModalSave>
  <ModalOpen ref="modal_open_report"
             :list_files="list_reports"
             :open_file="open_report"
             :delete_file="delete_report"
             :csrf="context.csrf"
             :title="_i18n('dashboard.open')"
             :file_title="_i18n('report.report_name')">
  </ModalOpen>

  <DateTimeRangePicker v-if="enable_date_time_range_picker"
                       id="dashboard-date-time-picker"
                       @epoch_change="set_components_epoch_interval">
    <template v-slot:extra_buttons>
      <button class="btn btn-link btn-sm"
              @click="show_store_report_modal" :title="_i18n('dashboard.store')">
        <i class="fa-solid fa-floppy-disk"></i>
      </button>
      <button class="btn btn-link btn-sm"
              @click="show_open_report_modal" :title="_i18n('dashboard.open')">
        <i class="fa-solid fa-folder-open"></i>
      </button>
      <button class="btn btn-link btn-sm"
              @click="print_report" :title="_i18n('dashboard.print')">
        <i class="fas fa-print"></i>
      </button>
    </template>
  </DateTimeRangePicker>
  
  <div ref="report_box" class="row">
    <template v-for="c in components" >
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
                     :params="c.params"
                     :get_component_data="get_component_data_func(c)">
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

import { default as ModalSave } from "./modal-save.vue";
import { default as ModalOpen } from "./modal-open.vue";

import { default as SimpleTable } from "./simple-table.vue";
import { default as EmptyComponent } from "./empty-component.vue";
import { default as Badge } from "./badge.vue";
import { default as Pie } from "./pie.vue";
import { default as Box } from "./box.vue";

const _i18n = (t) => i18n(t);
const timeframes_dict = ntopng_utility.get_timeframes_dict();

const props = defineProps({
    context: Object,
});

const components_dict = {
    "badge": Badge,
    "empty": EmptyComponent,
    "pie": Pie,
    "simple-table": SimpleTable,
}

const page_id = "page-dashboard";
const default_ifid = props.context.ifid;
const report_box = ref(null);

const modal_store_report = ref(null);
const modal_open_report = ref(null);

const main_epoch_interval = ref(null);

const components = ref([]);

let components_info = {};
let data_from_backup = false;

const enable_date_time_range_picker = computed(() => {
    return props.context.page == "report";
});

const component_interval = computed(() => {
    return (c) => {
        const epoch_begin_msec = c.epoch_begin * 1000;
        const epoch_end_msec = c.epoch_end * 1000;

        const begin_date = ntopng_utility.from_utc_to_server_date_format(epoch_begin_msec, 'DD/MM/YYYY');
        const begin_time = ntopng_utility.from_utc_to_server_date_format(epoch_begin_msec, 'HH:mm:ss');

        const end_date = ntopng_utility.from_utc_to_server_date_format(epoch_end_msec, 'DD/MM/YYYY');
        const end_time = ntopng_utility.from_utc_to_server_date_format(epoch_end_msec, 'HH:mm:ss');

        const begin = `${begin_date} ${begin_time}`;
        const end = (begin_date == end_date) ? `${end_time}` : `${end_date} ${end_time}`;

        return `${begin} - ${end}`;
    };
});

onBeforeMount(async () => {
    let epoch_interval = null;
    if (props.context.page == "report") {
        epoch_interval = ntopng_utility.check_and_set_default_time_interval(undefined, undefined, true);
        main_epoch_interval.value = epoch_interval;
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
    if (epoch_interval) {
        main_epoch_interval.value = epoch_interval;
    }

    components.value.forEach((c, i) => {
        update_component_epoch_interval(c, epoch_interval);
    });
}

async function load_components(epoch_interval, components_backup) {
    let url_request = `${http_prefix}/lua/pro/rest/v2/get/${props.context.page}/template.lua?template=${props.context.template}`;
    let res = await ntopng_utility.http_request(url_request);
    components.value = res.list.filter((c) => components_dict[c.component] != null)
        .map((c, index) => {
            let c_ext = {
                component_id: get_component_id(c.id, index),
                ...c
            };
            update_component_epoch_interval(c_ext, epoch_interval);
            return c_ext;
        });
    await nextTick();
}

function update_component_epoch_interval(c, epoch_interval) {
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

function show_store_report_modal() {
    modal_store_report.value.show();
}

function show_open_report_modal() {
    modal_open_report.value.show();
}

function get_suggested_report_name() {
    return ntopng_utility.from_utc_to_server_date_format(main_epoch_interval.value.epoch_end * 1000, 'DD-MM-YYYY');
}

const list_reports = async () => {
    let url = `${http_prefix}/lua/pro/rest/v2/get/report/backup/list.lua?ifid=${props.context.ifid}`;
    let files_obj = await ntopng_utility.http_request(url);
    let files = ntopng_utility.object_to_array(files_obj);

    /* Return array of [{ name: String, epoch: Number }, ...] */

    return files;
}

const open_report = async (file_name) => {
    let url = `${http_prefix}/lua/pro/rest/v2/get/report/backup/file.lua?ifid=${props.context.ifid}&report_name=${file_name}`;
    let content = await ntopng_utility.http_request(url);

    // console.log(content);

    let tmp_name = content.name;
    let tmp_epoch_interval = {
        epoch_begin: content.epoch_begin,
        epoch_end:   content.epoch_end
    };
    let tmp_template = content.template;
    let tmp_components_data = content.data;

    let tmp_components_info = {};
    for (let key in tmp_components_data) {
        let info = {
            data: tmp_components_data[key],
        };
        tmp_components_info[key] = info;
    }

    /* Disable REST calls */    
    data_from_backup = true;

    /* Set the cached data from the backup */
    components_info = tmp_components_info;

    /* Change the components (template) from the backup */
    components.value = tmp_template;

    /* Change the time interval on components */
    set_components_epoch_interval(tmp_epoch_interval);
}

const delete_report = async (file_name) => {
    let success = false;

    let params = {
        csrf: props.context.csrf,
        ifid: props.context.ifid,
    	report_name: file_name
    };

    let url = `${http_prefix}/lua/pro/rest/v2/delete/report/backup/file.lua`;
    try {
    	let headers = {
    	    'Content-Type': 'application/json'
    	};
    	await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
        success = true;
    } catch(err) {
    	console.error(err);
    }

    return success;
}

const store_report = async (file_name) => {
    let success = false;

    let components_data = {};
    for (var key in components_info) {
        components_data[key] = await components_info[key].data;
    }

    let content = {
        version: "1.0", /* Report dump version */
        name: file_name,
        epoch_begin: main_epoch_interval.value.epoch_begin,
        epoch_end: main_epoch_interval.value.epoch_end,
        template: components.value,
        data: components_data
    };

    let data = {
        csrf: props.context.csrf,
        ifid: props.context.ifid,
	report_name: file_name,
        content: JSON.stringify(content)
    };

    let url = `${http_prefix}/lua/pro/rest/v2/add/report/backup/file.lua`;
    try {
	let headers = {
	    'Content-Type': 'application/json'
	};
	await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(data) });
        success = true;
    } catch(err) {
	console.error(err);
    }

    return success;
}

function print_report() {
    $(report_box.value).print();
}

/* Callback to request REST data from components */
function get_component_data_func(component) {
    const get_component_data = async (url, url_params) => {
        
        let info = {};

        if (data_from_backup) {
            if (!components_info[component.component_id]) { /* Safety check */
                console.log("No data for " + component.component_id);
                info.data = {};
            } else {
                // console.log("-------------------------");
                // console.log(_i18n(component.i18n_name));
                // console.log(component);
                info = components_info[component.component_id];
                // console.log(info.data);
                // console.log("-------------------------");
            }
        } else {
            const data_url = `${url}?${url_params}`;

            /* Check if there is already a promise for the same request */
            if (components_info[component.component_id]) {
                info = components_info[component.component_id];
                if (info.data) {
                    await info.data; /* wait in case of previous pending requests */
                }
            }

            info.data = ntopng_utility.http_request(`${data_url}`);
        
            components_info[component.component_id] = info;
        }

        return info.data;
    };
    return get_component_data;
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
