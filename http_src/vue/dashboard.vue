<!-- (C) 2023 - ntop.org -->
<template>
    <div class='row'>
        <!-- <Dropdown v-for="(t, t_index) in top_table_array" -->
        <!--           :ref="el => { top_table_dropdown_array[t_index] = el }"> -->
        <!--   <template v-slot:title> -->
        <!--     <Spinner :show="t.show_spinner" size="1rem" class="me-1"></Spinner> -->
        <!--     <a class="ntopng-truncate" :title="t.title">{{ t.label }}</a> -->
        <!--   </template> -->
        <!--   <template v-slot:menu> -->
        <!--     <a v-for="opt in t.options" style="cursor:pointer; display: block;" -->
        <!--        @click="add_top_table_filter(opt, $event)" class="ntopng-truncate tag-filter " -->
        <!--        :title="opt.value">{{ opt.label }}</a> -->
        <!--   </template>     -->
        <!-- </Dropdown> -->

        <DateTimeRangePicker v-if="enable_date_time_range_picker" class="dontprint"
            :disabled_date_picker="disable_date_time_picker" id="dashboard-date-time-picker" :round_time="true"
            min_time_interval_id="min" @epoch_change="set_components_epoch_interval">
            <template v-slot:begin>
                <div class="me-2">
                    <SelectSearch v-model:selected_option="selected_report_template" :options="reports_templates"
                        @select_option="select_report_template">
                    </SelectSearch>
                </div>
            </template>
            <template v-slot:extra_buttons>
                <button class="btn btn-link btn-sm" type="button" @click="show_store_report_modal"
                    :title="_i18n('dashboard.store')">
                    <i class="fa-solid fa-floppy-disk"></i>
                </button>
                <button class="btn btn-link btn-sm" type="button" @click="show_open_report_modal"
                    :title="_i18n('dashboard.open')">
                    <i class="fa-solid fa-folder-open"></i>
                </button>
                <button class="btn btn-link btn-sm" type="button" @click="download_report" :title="_i18n('download')">
                    <i class="fa-solid fa-file-arrow-down"></i>
                </button>
                <button class="btn btn-link btn-sm" type="button" @click="show_upload_report_modal"
                    :title="_i18n('upload')">
                    <i class="fa-solid fa-file-arrow-up"></i>
                </button>
                <button class="btn btn-link btn-sm" type="button" @click="print_report" :title="_i18n('dashboard.print')">
                    <i class="fas fa-print"></i>
                </button>
            </template>
        </DateTimeRangePicker>

        <div class="btn-group me-auto mt-2 btn-group-sm flex-wrap d-flex">
            <template v-for="filter_id in filters_to_show">
                <div class="me-2">
                    <SelectSearch v-model:selected_option="selected_filters[filter_id]"
                        :options="filtered_filters[filter_id]"
                        @select_option="select_filter(selected_filters[filter_id], filter_id)">
                    </SelectSearch>
                </div>
            </template>
            <template v-if="Object.keys(filters_to_show).length > 0">
                <div class="d-flex align-items-center ms-2">
                    <button type="button" class="btn btn-sm btn-primary" @click="reset_filters">{{ _i18n('reset')
                    }}</button>
                </div>
            </template>
        </div>

        <div v-if="enable_report_title" class="mt-3" style="margin-bottom:-0.5rem; display: inline">
            <h3 style="text-align:center;">{{ report_title }}
                <span v-if="enable_small_picker">
                    <template v-if="enable_small_picker_actions">
                        <button class="btn btn-link btn-sm" type="button" @click="download_report"
                            :title="_i18n('download')">
                            <i class="fa-solid fa-file-arrow-down"></i>
                        </button>
                        <button class="btn btn-link btn-sm" type="button" @click="show_upload_report_modal"
                            :title="_i18n('upload')">
                            <i class="fa-solid fa-file-arrow-up"></i>
                        </button>
                    </template>
                    <button class="btn btn-link btn-sm" type="button" @click="print_report"
                        :title="_i18n('dashboard.print')">
                        <i class="fas fa-print"></i>
                    </button>
                </span>
            </h3>
        </div>

        <div ref="report_box" class="row" :key="components">

            <div v-if="warning_message" class="col-sm mt-1">
                <div class="alert alert-warning">
                    {{ warning_message }}
                </div>
            </div>

            <template v-for="c in components">
                <Box style="min-width:20rem;" :color="c.color" :width="c.width" :height="c.height">
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
                        <Loading v-if="loading && show_loading" :styles="'margin-top: 2rem !important;'"></Loading>
                        <div :class="[(loading && show_loading) ? 'ntopng-gray-out' : '']">
                            <component :is="components_dict[c.component]" :id="c.component_id"
                                :style="component_custom_style(c)" :epoch_begin="c.epoch_begin" :epoch_end="c.epoch_end"
                                :i18n_title="c.i18n_name" :ifid="c.ifid ? c.ifid.toString() : context.ifid.toString()" :max_width="c.width"
                                :max_height="c.height" :params="c.params" :get_component_data="get_component_data_func(c)"
                                :csrf="context.csrf" :filters="c.filters">
                            </component>
                        </div>
                    </template>
                    <template v-slot:box_footer>
                        <span v-if="c.component != 'empty' && c.i18n_name && !disable_date"
                            style="color: lightgray;font-size:12px;">
                            {{ component_interval(c) }}
                        </span>
                    </template>
                </Box>
            </template>
        </div>
    </div> <!-- div row -->
    <ModalSave ref="modal_store_report" :get_suggested_file_name="get_suggested_report_name" :store_file="store_report"
        :csrf="context.csrf" :title="_i18n('dashboard.store')">
    </ModalSave>
    <ModalOpen ref="modal_open_report" :list_files="list_reports" :open_file="open_report" :delete_file="delete_report"
        :csrf="context.csrf" :title="_i18n('dashboard.open')" :file_title="_i18n('report.report_name')">
    </ModalOpen>
    <ModalUpload ref="modal_upload_report" :upload_file="upload_report" :title="_i18n('upload')"
        :file_title="_i18n('report.file')">
    </ModalUpload>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_url_manager, ntopng_utility, ntopng_events_manager, ntopng_sync } from "../services/context/ntopng_globals_services";

import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";

import { default as ModalSave } from "./modal-file-save.vue";
import { default as ModalOpen } from "./modal-file-open.vue";
import { default as ModalUpload } from "./modal-file-upload.vue";
import { default as Loading } from "./loading.vue";

import { default as Box } from "./dashboard-box.vue";

import { default as EmptyComponent } from "./dashboard-empty.vue";
import { default as TableComponent } from "./dashboard-table.vue";
import { default as BadgeComponent } from "./dashboard-badge.vue";
import { default as PieComponent } from "./dashboard-pie.vue";
import { default as TimeseriesComponent } from "./dashboard-timeseries.vue";
import { default as SankeyComponent } from "./dashboard-sankey.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as dataUtils } from "../utilities/data-utils";

const _i18n = (t) => i18n(t);
const timeframes_dict = ntopng_utility.get_timeframes_dict();

const props = defineProps({
    context: Object,
});

const components_dict = {
    "badge": BadgeComponent,
    "empty": EmptyComponent,
    "pie": PieComponent,
    "timeseries": TimeseriesComponent,
    "table": TableComponent,
    "sankey": SankeyComponent,
}

const loading = ref(true);
const page_id = "page-dashboard";
const show_loading = props.context.show_loading || false;
const report_box = ref(null);

const modal_store_report = ref(null);
const modal_open_report = ref(null);
const modal_upload_report = ref(null);

const main_epoch_interval = ref(null);

const components = ref([]);
const selected_filters = ref({});
const all_available_filters = ref({});
const filtered_filters = ref({});
const filters_to_show = ref([]);
const nested_filters = ref([]);

const reports_templates = ref([]);
const selected_report_template = ref({});

const warning_message = ref("");

let components_info = {};
let data_from_backup = false;
let printable = false;

const enable_date_time_range_picker = computed(() => {
    return props.context.page == "report"
        && !printable;
});

const enable_small_picker = computed(() => {
    return props.context.page == "vs-report";
});

const enable_small_picker_actions = computed(() => {
    return true; // Set to false for hiding open/save actions in the small picker
});

const disable_date = computed(() => {
    return selected_report_template.value?.toolbox?.time?.hide == true;
});

const disable_date_time_picker = computed(() => {
    const disabled = selected_report_template.value.is_open_report == true
        || disable_date.value;
    return disabled;
});

const enable_report_title = computed(() => {
    const enable = selected_report_template.value.is_open_report == true
        || props.context.page == "vs-report";
    return enable;
});

const report_title = computed(() => {
    let title = "";

    if (selected_report_template.value.is_open_report) {
        title = `Report: ${selected_report_template.value.value}`;
    } else if (props.context.title) {
        title = props.context.title;
    }

    return title;
});

const component_custom_style = computed(() => {
    return (c) => {
        if (c.params.custom_style != null && (!printable || c.params.custom_print_style)) {
            return c.params.custom_style;
        } else if (c.params.custom_print_style && printable == true) {
            return c.params.custom_print_style;
        }
        return "";
    };
});

const component_interval = computed(() => {
    return (c) => {
        const time_interval_string = get_time_interval_string(c.epoch_begin, c.epoch_end);
        return time_interval_string;
    };
});

onBeforeMount(async () => {
    let epoch_interval = null;
    printable = ntopng_url_manager.get_url_entry("printable") == "true";

    if (props.context.page == "report" || props.context.page == "vs-report") {
        if (props.context.page == "report") {
            epoch_interval = ntopng_utility.check_and_set_default_time_interval(undefined, undefined, true, "min");
        } else if (props.context.page == "vs-report") {
            epoch_interval = ntopng_utility.check_and_set_default_time_interval(undefined, undefined, true);
        }
        main_epoch_interval.value = epoch_interval;
    }

    await set_templates_list();
    let report_name = ntopng_url_manager.get_url_entry("report_name");
    if (report_name != null && report_name != "") {
        /* Report name provided - open a report backup */
        await open_report(report_name);
    } else {
        /* Load a template and build a new report */
        await load_components(epoch_interval, selected_report_template.value.value);
    }
    if (printable == true) {
        set_report_title();
        // await nextTick();
        // ntopng_sync.ready("print_report");
    }
});

onMounted(async () => {
    if (props.context.page == "dashboard") {
        start_dashboard_refresh_loop();
    }
    // if (printable == true) {
    //     await ntopng_sync.on_ready("print_report");
    // }
});

async function set_templates_list() {
    const url_request = props.context.template_list_endpoint;
    let res = await ntopng_utility.http_request(url_request);
    if (res?.list == null) { return; }

    reports_templates.value = res.list.map((t) => {
        return {
            value: t.name,
            label: t.label,
            disabled: false,
            toolbox: t.toolbox,
            is_open_report: false,
        };
    });
    const report_template_value = ntopng_url_manager.get_url_entry("report_template") || props.context.template;
    selected_report_template.value = reports_templates.value.find((t) => t.value == report_template_value);
    if (selected_report_template.value == null) {
        selected_report_template.value = reports_templates.value[0];
    }
}

let dasboard_loop_interval;

/* Dashboard update interval/frequency */
const loop_interval = 10 * 1000;

function start_dashboard_refresh_loop() {
    dasboard_loop_interval = setInterval(() => {
        set_components_epoch_interval();
    }, loop_interval);
}

function set_components_filter(filter_id, filter_value) {
    if (filter_value) { filter_value = filter_value + ";eq"; }
    ntopng_url_manager.set_key_to_url(filter_id, filter_value);
    components.value.forEach((c, i) => {
        update_component_filters(c, filter_id, filter_value);
    });
}

function set_components_epoch_interval(epoch_interval) {
    if (epoch_interval) {
        main_epoch_interval.value = epoch_interval;
    }

    components.value.forEach((c, i) => {
        update_component_epoch_interval(c, epoch_interval);
    });
}

/* This is used to reset the filters putting all of them to the ALL value */
function reset_filters() {
    /* Iterate all the filters available */
    for (const [filter, value] of Object.entries(all_available_filters.value)) {
        /* Set each filter to the ALL value (first value) */
        set_components_filter(filter, value[0].value);
        selected_filters.value[filter] = value[0];
        /* Hide all the needed filters */
        hide_nested_filters(filter);
    }
}

/* This function loads the filters */
async function load_filters(filters_available, res) {
    const added_filters_list = [];
    if (!res) {
        res = await ntopng_utility.http_request(`${props.context.report_filters_endpoint}`);
    }
    filters_available.forEach(async (element) => {
        const id = element?.name || "";
        const filter_options = res.find((el) => el.id == id)?.options;
        /* Check the filters available, if no filter or only 1 filter is provided, hide the dropdown */
        if (filter_options && filter_options.length > 1) {
            let all_label = i18n('db_search.all.' + id)
            if (dataUtils.isEmptyOrNull(all_label)) {
                all_label = i18n('all') + " " + i18n('db_search.' + id);
            }
            /* Add the 'All' filter */
            /* To be safe, add a default name */
            filter_options.unshift({
                value: null,
                label: all_label
            });

            all_available_filters.value[id] = filter_options;
            selected_filters.value[id] = filter_options[0];
            filtered_filters.value[id] = filter_options
            added_filters_list.push(id);

            const nested = element?.nested || [];
            if (nested.length > 0) {
                nested_filters.value[id] = await load_filters(nested, res /* Skip the request to the backend */)
            }
            /* Now check the nested filters, they appear ONLY 
            * if the filter selected is not ALL (first entry) 
            */
        }
    });
    return added_filters_list;
}

async function load_components(epoch_interval, template_name) {
    /* Enable REST calls */
    data_from_backup = false;

    let url_request = `${props.context.template_endpoint}?template=${template_name}`;
    let res = await ntopng_utility.http_request(url_request);
    components.value = res.list.filter((c) => components_dict[c.component] != null)
        .map((c, index) => {
            let c_ext = {
                component_id: get_component_id(c.id, index),
                filters: {},
                ...c
            };
            update_component_epoch_interval(c_ext, epoch_interval);
            return c_ext;
        });
    reset_filters();
    filters_to_show.value = await load_filters(res.filters);
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

function update_component_filters(c, filter_id, filter_value) {
    c.filters[filter_id] = filter_value;
}

/* ********************************************* */

/* This function hides the nested filters (the ones to not show) */
function hide_nested_filters(filter) {
    const to_hide_filters = nested_filters.value[filter];
    to_hide_filters?.forEach((filter_to_remove) => {
        /* For each filter check if currently it's displayed */
        if (filters_to_show.value.includes(filter_to_remove)) {
            /* If it's displayed, then remove it */
            filters_to_show.value = filters_to_show.value.filter((element) => {
                return element != filter_to_remove;
            });
            /* Reset its value to the default one */
            const all_value = all_available_filters.value[filter_to_remove][0];
            selected_filters.value[filter_to_remove] = all_value;
            set_components_filter(filter_to_remove, all_value.value)
        }
    })
}

/* ********************************************* */

/* This function shows the filters when clicking on a filter having a nested option */
function show_nested_filters(filter_to_check, currently_selected_filter) {
    /* Gets the nested filters of the filter to check */
    const show_filters = nested_filters.value[filter_to_check];
    show_filters?.forEach((filter_to_add) => {
        /* Get all the available options for the nested option */
        const all_filters = all_available_filters.value[filter_to_add];
        const filters_to_enable = [];

        /* Check if the currently selected filter is the filter to check for the nested filters */
        if (currently_selected_filter == filter_to_check) {
            /* If it is, reset its value to the default ones */
            const all_value = all_available_filters.value[filter_to_add][0];
            selected_filters.value[filter_to_add] = all_value;
            set_components_filter(filter_to_add, all_value.value)
        }

        /* Filter out the values of the nested filter that have to be hide */
        all_filters?.forEach((element) => {
            if (element.show_only_value === selected_filters.value[filter_to_check].value || element.value == null)
                filters_to_enable.push(element);
        });

        /* Add the remaining values to the array that shows the filters */
        if (!filters_to_show.value.includes(filter_to_add)) {
            const index_to_push = filters_to_show.value.indexOf(filter_to_check);
            filters_to_show.value.splice(index_to_push + 1, 0, filter_to_add);
        }
        filters_to_enable.length > 0 ?
            filtered_filters.value[filter_to_add] = filters_to_enable :
            delete filtered_filters.value[filter_to_add]
    })
}

/* ********************************************* */

/* This function is called whenever a filter is clicked */
function select_filter(option, filter_id) {
    /* Set the filter, ready for the rest */
    set_components_filter(filter_id, option.value);
    for (const [filter, _] of Object.entries(all_available_filters.value)) {
        /* Iterate all the available filters and hide the ones to hide
        * and show the ones to show
        */
        const filter_to_check = selected_filters.value[filter];
        filter_to_check?.value ? show_nested_filters(filter, filter_id) : hide_nested_filters(filter);
    }
}

/* ********************************************* */

function select_report_template() {
    if (printable == true) {
        set_report_title();
    }
    if (selected_report_template.value.is_open_report == true) {
        return;
    }
    components_info = {};
    update_templates_list();
    const global_status = ntopng_status_manager.get_status(true);
    let epoch_interval = { epoch_begin: global_status.epoch_begin, epoch_end: global_status.epoch_end };
    if (data_from_backup == true) { // last report selected it was a saved report and then we must to restore default timestamp
        epoch_interval = ntopng_utility.set_default_time_interval(undefined, "min");
        ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, epoch_interval, props.context.page);
    }
    load_components(epoch_interval, selected_report_template.value.value);
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

function show_upload_report_modal() {
    modal_upload_report.value.show();
}

function get_suggested_report_name() {
    let name = "report";
    if (props.context.page == "vs-report") {
        name = props.context.title;
    } else if (main_epoch_interval.value &&
        main_epoch_interval.value.epoch_end) {
        name += "-" + ntopng_utility.from_utc_to_server_date_format(main_epoch_interval.value.epoch_end * 1000, 'DD-MM-YYYY');
    }
    return name;
}

const upload_report = async (content_string) => {
    let content = JSON.parse(content_string);
    set_report(content, content.name);
    ntopng_url_manager.delete_key_from_url("report_name");
}

function set_report(content, name) {
    update_templates_list(name);
    const epoch_status = { epoch_begin: content.epoch_begin, epoch_end: content.epoch_end };
    ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, epoch_status, props.context.page);
    load_report(content);
}

const list_reports = async () => {
    let url = `${props.context.report_list_endpoint}?ifid=${props.context.ifid}`;
    let files_obj = await ntopng_utility.http_request(url);
    let files = ntopng_utility.object_to_array(files_obj);

    /* Return array of [{ name: String, epoch: Number }, ...] */

    return files;
}

const load_report = async (content) => {
    let tmp_epoch_interval = {
        epoch_begin: content.epoch_begin,
        epoch_end: content.epoch_end
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

const open_report = async (file_name) => {
    let url = `${props.context.report_open_endpoint}?ifid=${props.context.ifid}&report_name=${file_name}`;
    let content = await ntopng_utility.http_request(url);
    if (content) {
        set_report(content, file_name);
        warning_message.value = "";
    } else {
        warning_message.value = _i18n("report.unable_to_open");
    }
}

function update_templates_list(report_name_to_open) {
    reports_templates.value = reports_templates.value.filter((t) => t.is_open_report == false);
    if (report_name_to_open == null) { // in this case is selected a report_template
        ntopng_url_manager.set_key_to_url("report_template", selected_report_template.value.value);
        ntopng_url_manager.delete_key_from_url("report_name");
        return;
    }

    let t_entry = {
        value: report_name_to_open,
        label: _i18n("dashboard.custom"),
        disabled: false,
        toolbox: null,
        is_open_report: true,
    };
    reports_templates.value.push(t_entry);
    selected_report_template.value = t_entry;
    ntopng_url_manager.set_key_to_url("report_name", selected_report_template.value.value);
    ntopng_url_manager.delete_key_from_url("report_template");
}

const delete_report = async (file_name) => {
    let success = false;

    let params = {
        csrf: props.context.csrf,
        ifid: props.context.ifid,
        report_name: file_name
    };

    let url = `${props.context.report_delete_endpoint}`;
    try {
        let headers = {
            'Content-Type': 'application/json'
        };
        await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
        success = true;
    } catch (err) {
        console.error(err);
    }

    return success;
}

/* Dump report content - keep in sync with dashboard_utils.build_report (lua) */
const serialize_report = async (name) => {

    let components_data = {};
    for (var key in components_info) {
        components_data[key] = await components_info[key].data;
    }

    let content = {
        version: "1.0", // Report dump version
        name: name,
        template: components.value,
        data: components_data
    };

    if (main_epoch_interval.value &&
        main_epoch_interval.value.epoch_begin &&
        main_epoch_interval.value.epoch_end) {
        content.epoch_begin = main_epoch_interval.value.epoch_begin;
        content.epoch_end = main_epoch_interval.value.epoch_end;
    }

    return JSON.stringify(content);
}

const store_report = async (file_name) => {
    let success = false;

    let data = {
        csrf: props.context.csrf,
        ifid: props.context.ifid,
        report_name: file_name,
        content: await serialize_report(file_name)
    };

    let url = `${props.context.report_store_endpoint}`;
    try {
        let headers = {
            'Content-Type': 'application/json'
        };
        await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(data) });
        success = true;
    } catch (err) {
        console.error(err);
    }

    return success;
}

async function download_report() {
    var name = get_suggested_report_name();
    var filename = name + '.json';
    var content = await serialize_report(name);
    var element = document.createElement('a');
    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(content));
    element.setAttribute('download', filename);
    element.style.display = 'none';
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
}

function print_report() {
    if (printable == true) {
        window.print();
        return false;
    }

    let url_params_obj = ntopng_url_manager.get_url_object();
    url_params_obj.printable = true;
    const params = ntopng_url_manager.obj_to_url_params(url_params_obj);

    let url = `${window.location.origin}${window.location.pathname}?${params}`;

    //const print_key = "printable";
    //ntopng_url_manager.set_key_to_url(print_key, true);

    ntopng_url_manager.open_new_window(url);

    //ntopng_url_manager.delete_key_from_url(print_key);
    // $(report_box.value).print({mediaPrint: true, timeout: 1000}); 
    // $(report_box.value).print();
}

function get_time_interval_string(epoch_begin, epoch_end) {
    if (disable_date.value == true) { return ""; }

    const epoch_begin_msec = epoch_begin * 1000;
    const epoch_end_msec = epoch_end * 1000;

    const begin_date = ntopng_utility.from_utc_to_server_date_format(epoch_begin_msec, 'DD/MM/YYYY');
    const begin_time = ntopng_utility.from_utc_to_server_date_format(epoch_begin_msec, 'HH:mm:ss');

    const end_date = ntopng_utility.from_utc_to_server_date_format(epoch_end_msec, 'DD/MM/YYYY');
    const end_time = ntopng_utility.from_utc_to_server_date_format(epoch_end_msec, 'HH:mm:ss');

    const begin = `${begin_date} ${begin_time}`;
    const end = (begin_date == end_date) ? `${end_time}` : `${end_date} ${end_time}`;
    return `${begin} - ${end}`;
}

function set_report_title() {
    const epoch_interval = ntopng_status_manager.get_status(true);
    const time_interval_string = get_time_interval_string(epoch_interval.epoch_begin, epoch_interval.epoch_end);
    let title = `ntopng - Report ${selected_report_template.value.label} ${time_interval_string}`;
    document.title = title;
}

/* Callback to request REST data from components */
function get_component_data_func(component) {
    const get_component_data = async (url, url_params, post_params) => {
        let info = {};
        if (data_from_backup) {
            if (!components_info[component.component_id]) { /* Safety check */
                console.error("No data for " + component.component_id);
                info.data = {};
            } else {
                info = components_info[component.component_id];
            }
        } else {

            /* Check if there is already a promise for the same request */
            if (components_info[component.component_id]) {
                info = components_info[component.component_id];
                if (info.data) {
                    await info.data; /* wait in case of previous pending requests */
                }
            }

            const data_url = `${url}?${url_params}`;

            loading.value = true;
            if (post_params) {
                info.data = ntopng_utility.http_post_request(data_url, post_params)
            } else {
                info.data = ntopng_utility.http_request(data_url);
            }
            info.data.then(() => {
                loading.value = false;
            });

            components_info[component.component_id] = info;
        }
        return info.data;
    };
    return get_component_data
}

</script>

<style scoped>
@media print {
    .dontprint {
        display: none;
    }

    .pagebreak-begin {
        page-break-before: always;
    }

    .pagebreak-end {
        page-break-after: always !important;
    }

    .print-element-class {
        page-break-inside: avoid !important;
        page-break-after: auto
    }
}

/* @media print and (orientation: portrait) and (max-width: 297mm){ */
/*     .col-4 { */
/*         width: 50% !important; */
/*         flex: 0 0 auto; */
/*     } */
/* } */
@page {
    /* size: A3 landscape; */
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

/* @media print and (max-width: 148mm){ */
/*     .col-4 { */
/*         width: 100% !important; */
/*         flex: 0 0 auto; */
/*     } */
/*     .col-6 { */
/*         width: 100% !important; */
/*         flex: 0 0 auto; */
/*     } */
/* } */

.align-center {}
</style>
