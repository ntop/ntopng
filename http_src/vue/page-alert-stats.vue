<!-- (C) 2022 - ntop.org     -->
<template>
<Navbar
  id="navbar"
  :main_title="context.navbar.main_title"
  :base_url="context.navbar.base_url"
  :help_link="context.navbar.help_link"
  :items_table="context.navbar.items_table"
  @click_item="click_navbar_item">
</Navbar>

<div class='row'>
  <div class='col-12'>
    <div class="mb-2">
      <div class="w-100">
	<div clas="range-container d-flex flex-wrap">
	  <div class="range-picker d-flex m-auto flex-wrap" id="rangepicker">
	    <AlertInfo id="alert_info" :global="true" ref="alert_info"></AlertInfo>
	    <ModalTrafficExtraction id="modal_traffic_extraction" ref="modal_traffic_extraction"></ModalTrafficExtraction>
	    <ModalSnapshot ref="modal_snapshot"
			   :csrf="context.csrf">
	    </ModalSnapshot>
	    <RangePicker ref="range-picker-vue" id="id_range_picker">
	      <template v-slot:extra_range_buttons>
		<button v-if="context.show_permalink" class="btn btn-link btn-sm" @click="get_permanent_link" :title="_i18n('graphs.get_permanent_link')" ref="permanent_link_button"><i class="fas fa-lg fa-link"></i></button>
		<a v-if="context.show_download" class="btn btn-link btn-sm" id="dt-btn-download" :title="_i18n('graphs.download_records')" ><i class="fas fa-lg fa-file"></i></a>
		<button v-if="context.show_pcap_download" class="btn btn-link btn-sm" @click="show_modal_traffic_extraction" :title="_i18n('traffic_recording.pcap_download')"><i class="fas fa-lg fa-download"></i></button>
		<button v-if="context.is_ntop_enterprise_m" class="btn btn-link btn-sm" @click="show_modal_snapshot" :title="_i18n('datatable.manage_snapshots')"><i class="fas fa-lg fa-camera-retro"></i></button>
	      </template>
	    </RangePicker>
	  </div>
	</div>
      </div>
    </div>
  </div>
  
  <div class='col-12'>
    <div class="card card-shadow">
      <!-- <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100"> -->
	<!--   <div class="text-center"> -->
	  <!--     <div class="spinner-border text-primary mt-5" role="status"> -->
	    <!--       <span class="sr-only position-absolute">Loading...</span> -->
	    <!--     </div> -->
	  <!--   </div> -->
	<!-- </div> -->
      
      <div class="card-body">	
        <div v-if="context.show_chart" class="row">	  
          <div class="col-12 mb-2" id="chart-vue">
            <div class="card h-100 overflow-hidden">
              <Chart ref="chart"
	             id="chart_0"
		     :chart_type="chart_type"
	             :base_url_request="chart_data_url"
		     :register_on_status_change="false">
	      </Chart>
	      <ModalAlertsFilter
	        :alert="current_alert"
		:page="page"
		@exclude="add_exclude"
		ref="modal_alerts_filter">
	      </ModalAlertsFilter>
            </div>
          </div>

	  <Table ref="table_alerts" id="table_config.id"
                 :key="table_config.columns" :columns="table_config.columns"
                 :get_rows="table_config.get_rows"
                 :get_column_id="table_config.get_column_id"
                 :print_column_name="table_config.print_column_name"
		 :print_html_row="table_config.print_html_row"
		 :print_vue_node_row="table_config.print_vue_node_row"
		 :f_is_column_sortable="table_config.f_is_column_sortable"
		 :enable_search="table_config.enable_search"
		 :paging="table_config.paging"
		 @custom_event="on_table_button_click">
          </Table>
	  
	</div>
      </div>
    </div>
  </div>
  
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import NtopUtils from "../utilities/ntop-utils";
import { ntopChartApex } from "../components/ntopChartApex.js";
import { DataTableRenders } from "../utilities/datatable/sprymedia-datatable-utils.js";
import TableUtils from "../utilities/table-utils";

import { default as SelectSearch } from "./select-search.vue";
import { default as Navbar } from "./page-navbar.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as Table } from "./table.vue";

import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalAlertsFilter } from "./modal-alerts-filter.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const alert_info = ref(null);
const chart = ref(null);
const table_alerts = ref(null);
const modal_traffic_extraction = ref(null);
const modal_snapshot = ref(null);
const range_picker = ref(null);
const permanent_link_button = ref(null);
const modal_alerts_filter = ref(null);

const current_alert = ref(null);
const table_config = ref({});
const default_ifid = props.context.ifid;
let page;
let table_id;
let chart_data_url = `${http_prefix}/lua/pro/rest/v2/get/db/ts.lua`;
const chart_type = ntopChartApex.typeChart.TS_COLUMN;

onBeforeMount(async () => {
    page = ntopng_url_manager.get_url_entry("page");
    if (page == null) { page = "all"; }
    chart_data_url = (page == "snmp_device") ? `${http_prefix}/lua/pro/rest/v2/get/snmp/device/alert/ts.lua` : `${http_prefix}/lua/rest/v2/get/${page}/alert/ts.lua`;
    table_id = `alert_${page}`;
});

onMounted(async () => {
    console.log(props.context);
    if (ntopng_url_manager.get_url_entry("ifid") == null) {
	ntopng_url_manager.set_key_to_url("ifid", default_ifid);
    }
    if (ntopng_url_manager.get_url_entry("epoch_begin") == null
      	|| ntopng_url_manager.get_url_entry("epoch_end") == null) {
	let default_epoch_begin = Number.parseInt((Date.now() - 1000 * 30 * 60) / 1000);
	let default_epoch_end = Number.parseInt(Date.now() / 1000);
	ntopng_url_manager.set_key_to_url("epoch_begin", default_epoch_begin);
	ntopng_url_manager.set_key_to_url("epoch_end", default_epoch_end);
    }
    if (ntopng_url_manager.get_url_entry("page") == "flow"
      	&& ntopng_url_manager.get_url_entry("status") == "engaged") {
	ntopng_url_manager.set_key_to_url("status", "historical");
    }
    table_config.value = await TableUtils.build_table(http_prefix, table_id, map_table_def_columns, get_extra_params_obj);
});

const map_table_def_columns = (columns) => {
    let map_columns = {
	"l7_proto": (proto, row) => {
            let confidence = "";
            if (proto.confidence !== undefined) {
		const title = proto.confidence;
		(title == "DPI") ? confidence = `<span class="badge bg-success" title="${title}">${title}</span>` : confidence = `<span class="badge bg-warning" title="${title}">${title}</span>` 
            }
	    return DataTableRenders.filterize('l7proto', proto.value, proto.label) + " " + `${confidence}`;
	},
    };
    columns.forEach((c) => {
	c.render_func = map_columns[c.data_field];
    });
    return columns;
};

const get_extra_params_obj = () => {
    let status = ntopng_status_manager.get_status(true);
    return {
	page,
	ifid: props.context.ifid,
	draw: 1,
	epoch_begin: status.epoch_begin,
	epoch_end: status.epoch_end,
    };
};

function click_navbar_item(item) {
    ntopng_url_manager.set_key_to_url('page', item.page_name);
    let is_alert_stats_url = window.location.toString().match(/alert_stats.lua/) != null;
    if (is_alert_stats_url) {
	remove_filters_from_url();
    }
    ntopng_url_manager.reload_url();    
}

function remove_filters_from_url() {
    let status = ntopng_status_manager.get_status();
    let filters = status.filters;
    if (filters == null) { return; }		
    ntopng_url_manager.delete_params(filters.map((f) => f.id));    
}

function show_modal_alerts_filter(alert) {
    current_alert.value = alert;
    modal_alerts_filter.value.show();
}

function get_permanent_link() {
    const $this = permanent_link_button.value;
    const placeholder = document.createElement('input');
    placeholder.value = location.href;
    document.body.appendChild(placeholder);
    placeholder.select();
    
    // copy the url to the clipboard from the placeholder
    document.execCommand("copy");
    document.body.removeChild(placeholder);
    
    $this.attr("title", "{{ i18n('copied') }}!")
	.tooltip("dispose")
	.tooltip()
	.tooltip("show");
}

function show_modal_traffic_extraction() {
    modal_traffic_extraction.value.show();
    
}

function show_modal_snapshot() {
    modal_snapshot.value.show();
}

async function add_exclude(params) {
    params.csrf = context.csrf;
    let url = `${http_prefix}/lua/pro/rest/v2/add/alert/exclusion.lua`;
    try {
	let headers = {
	    'Content-Type': 'application/json'
	};
	await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
	let url_params = ntopng_url_manager.get_url_params();
	setTimeout(() => {
	    //todo reloadTable($table, url_params);
	    ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_GLOBAL_ALERT_INFO, { text_html: _i18n('check_exclusion.disable_warn'), type: "alert-info", timeout: 2 });
	}, 1000);
    } catch(err) {
	console.error(err);
    }    
}

function on_table_button_click(event) {
    console.log(event);
    if (event.event_id == "click_button_info") {
    }
}

</script>

<style scoped>
</style>
