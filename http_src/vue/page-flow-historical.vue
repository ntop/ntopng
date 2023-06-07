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
	  <div class="range-picker d-flex m-auto flex-wrap">
	    <AlertInfo id="alert_info" :global="true" ref="alert_info"></AlertInfo>
	    <RangePicker ref="range_picker" id="range_picker">
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
            </div>
          </div>
	  <TableWithConfig ref="table_alerts"
			   :table_id="table_id"
			   :csrf="context.csrf"
			   :f_map_columns="map_table_def_columns"
			   :get_extra_params_obj="get_extra_params_obj"
			   @loaded="on_table_loaded"
			   @custom_event="on_table_custom_event">
	    <template v-slot:custom_header>
	      <Dropdown v-for="(t, t_index) in top_table_array" :f_on_open="get_open_top_table_dropdown(t, t_index)" :ref="el => { top_table_dropdown_array[t_index] = el }"> <!-- Dropdown columns -->
		<template v-slot:title>
		  <Spinner :show="t.show_spinner" size="1rem" class="me-1" ></Spinner>
		  <a class="ntopng-truncate"  :title="t.title">{{t.label}}</a>
		</template>
		<template v-slot:menu>
		  <a v-for="opt in t.options" style="cursor:pointer;" @click="add_top_table_filter(opt, $event)" class="ntopng-truncate tag-filter " :title="opt.value">{{opt.label}}</a>
		</template>
	      </Dropdown> <!-- Dropdown columns -->
	    </template> <!-- custom_header -->
	  </TableWithConfig>	  
	</div>
      </div> <!-- card body -->
      
      <div v-if="props.context.show_acknowledge_all || props.context.show_delete_all" class="card-footer">
        <button v-if="props.context.show_acknowledge_all" id="dt-btn-acknowledge" :disabled="true" data-bs-target="#dt-acknowledge-modal" data-bs-toggle="modal" class="btn btn-primary me-1">
          <i class="fas fa fa-user-check"></i> Acknowledge Alerts
        </button>
        <button v-if="props.context.show_delete_all" id="dt-btn-delete" :disabled="true" data-bs-target="#dt-delete-modal" data-bs-toggle="modal" class="btn btn-danger">
          <i class="fas fa fa-trash"></i> Delete Alerts
        </button>
      </div> <!-- card footer -->
    </div>  <!-- card-shadow -->
    
  </div> <!-- div col -->
  <NoteList :note_list="note_list"></NoteList>
</div> <!-- div row -->

<ModalTrafficExtraction id="modal_traffic_extraction" ref="modal_traffic_extraction">
</ModalTrafficExtraction>

<ModalSnapshot ref="modal_snapshot" :csrf="context.csrf">
</ModalSnapshot>

<ModalAcknoledgeAlert ref="modal_acknowledge" :context="context" @acknowledge="refresh_page_components"></ModalAcknoledgeAlert>

<ModalDeleteAlert ref="modal_delete" :context="context" @delete_alert="refresh_page_components"></ModalDeleteAlert>

<ModalAlertsFilter
  :alert="current_alert"
  :page="page"
  @exclude="add_exclude"
  ref="modal_alerts_filter">
</ModalAlertsFilter>

</template>

<script setup>
import { ref, onMounted, onBeforeMount, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services";
import NtopUtils from "../utilities/ntop-utils";
import { ntopChartApex } from "../components/ntopChartApex.js";
import { DataTableRenders } from "../utilities/datatable/sprymedia-datatable-utils.js";
import TableUtils from "../utilities/table-utils";

import { default as SelectSearch } from "./select-search.vue";
import { default as Navbar } from "./page-navbar.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as Spinner } from "./spinner.vue";
import { default as NoteList } from "./note-list.vue";

import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalAlertsFilter } from "./modal-alerts-filter.vue";
import { default as ModalAcknoledgeAlert } from "./modal-acknowledge-alert.vue";
import { default as ModalDeleteAlert } from "./modal-delete-alert.vue";

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
const modal_acknowledge = ref(null);
const modal_delete = ref(null);

const current_alert = ref(null);
const default_ifid = props.context.ifid;
let page;
let table_id;
let chart_data_url = `${http_prefix}/lua/pro/rest/v2/get/db/ts.lua`;
const chart_type = ntopChartApex.typeChart.TS_COLUMN;
const top_table_array = ref([]);
const top_table_dropdown_array = ref([]);
const note_list = ref([_i18n('show_alerts.alerts_info')]);

onBeforeMount(async () => {
    page = ntopng_url_manager.get_url_entry("page");
    if (page == null) { page = "overview"; }
    chart_data_url = `${http_prefix}/lua/pro/rest/v2/get/db/ts.lua`;
    table_id = `flow_historical`;
    init_url_params();
});

onMounted(async () => {
    register_components_on_status_update();
    load_top_table_array_overview();
});

function init_url_params() {
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
}

async function load_top_table_array_overview(action) {
    if (props.context.show_cards != true) { return; }    
    top_table_array.value = await load_top_table_array("overview");
}

async function load_top_table_details(top, top_index) {
    top.show_spinner = true;
    await nextTick();
    if (top.data_loaded == false) {
	let new_top_array = await load_top_table_array(top.id, top);
	top.options = new_top_array.find((t) => t.id == top.id).options;
	await nextTick();
	let dropdown = top_table_dropdown_array.value[top_index];
	dropdown.load_menu();
    }
    top.show_spinner = false;
}

async function load_top_table_array(action, top) {
    // top_table.value = [];
    const url_params = ntopng_url_manager.get_url_params();
    const url = `${http_prefix}/lua/pro/rest/v2/get/flow/top.lua?${url_params}&action=${action}`;
    let res = await ntopng_utility.http_request(url);
    return res.map((t) => {
	return {
	    id: t.action || t.name,
	    label: t.label,	    
	    title: t.tooltip,
	    show_spinner: false,
	    data_loaded: action != 'overview',
	    options: t.value,
	};
    });
}

const get_open_top_table_dropdown = (top, top_index) => {
    return (d) => {
	load_top_table_details(top, top_index);
    };
};

async function register_components_on_status_update() {
    await ntopng_sync.on_ready("range_picker");
    //if (show_chart) {      
    chart.value.register_status();
    //}
    //updateDownloadButton();
    ntopng_status_manager.on_status_change(page.value, (new_status) => {
	let url_params = ntopng_url_manager.get_url_params();
	table_alerts.value.refresh_table();
	load_top_table_array_overview();
    }, false);
}

function on_table_loaded() {
    register_table_alerts_events();
}

function register_table_alerts_events() {
    let jquery_table_alerts = $(`#${table_id}`);
    jquery_table_alerts.on('click', `a.tag-filter`, async function (e) {
	add_table_row_filter(e, $(this));
    });
}

const map_table_def_columns = (columns) => {
    let html_ref = '';
    let location = '';
    const f_print_asn = (key, asn, row) => {
        if (asn !== undefined && asn.value != 0) {
            return `<a class='tag-filter' data-tag-key='${key}' data-tag-value='${asn.value}' title='${asn.title}' href='javascript:void(0)'>${asn.label}</a>`;
	}
	return "";
    };
    const f_print_latency = (key, latency, row) => {
	if (latency == null) { return ""; }
        return `<a class='tag-filter' data-tag-key='${key}' data-tag-value='${latency}' href='javascript:void(0)'>${NtopUtils.msecToTime(latency)}</a>`;
    };
    let map_columns = {
	"first_seen": (first_seen, row) => {
            if (first_seen !== undefined)
		return first_seen.time;
	},
	"l7proto": (proto, row) => {
            let confidence = "";
            if (proto.confidence !== undefined) {
		const title = proto.confidence;
		(title == "DPI") ? confidence = `<span class="badge bg-success" title="${title}">${title}</span>` : confidence = `<span class="badge bg-warning" title="${title}">${title}</span>` 
            }
	    return DataTableRenders.filterize('l7proto', proto.value, proto.label) + " " + `${confidence}`;
	},
	"packets": (packets, row) => {
            if (packets !== undefined) {
		return NtopUtils.formatPackets(packets);
 	    }
	    return "";
	},
	"cli_asn": (cli_asn, row) => f_print_asn("cli_asn", cli_asn, row),
	"srv_asn": (srv_asn, row) => f_print_asn("srv_asn", srv_asn, row),
	"flow_risk": (flow_risks, row) => {
	    if (flow_risks == null) { return ""; }
            let res = [];
	    
            for (let i = 0; i < flow_risks.length; i++) {
		const flow_risk = flow_risks[i];
		const flow_risk_label = (flow_risk.label || flow_risk.value);
		const flow_risk_help = (flow_risk.help);
		res.push(`${flow_risk_label} ${flow_risk_help}`);
            }
            return res.join(', ');	    
	},
	"cli_nw_latency": (cli_nw_latency, row) => f_print_latency("cli_nw_latency", cli_nw_latency, row),
	"srv_nw_latency": (srv_nw_latency, row) => f_print_latency("srv_nw_latency", srv_nw_latency, row),
	"info": (info, row) => {
	    if (info == null) { return ""; }
            return `<a class='tag-filter' data-tag-value='${info.title}' title='${info.title}' href='#'>${info.label}</a>`;
	},
    };
    columns = columns.filter((c) => props.context?.visible_columns[c.data_field] != false);
    columns.forEach((c) => {
	c.render_func = map_columns[c.data_field];
	
	if (c.id == "actions") {
	    const visible_dict = {
		info: props.context.actions.show_info,
		historical_data: props.context.actions.show_historical,
		flow_alerts: props.context.actions.show_alerts,
		pcap_download: props.context.actions.show_pcap_download,
	    };
	    c.button_def_array.forEach((b) => {
		if (!visible_dict[b.id]) {
		    b.class.push("link-disabled");
		}
	    });
	}
    });
    return columns;
};

const add_table_row_filter = (e, a) => {
    e.stopPropagation();    
    
    let key = undefined;
    let displayValue = undefined;
    let realValue = undefined;
    let operator = 'eq';
    
    // Read tag key and value from the <a> itself if provided
    if (a.data('tagKey')        != undefined) key          = a.data('tagKey');
    if (a.data('tagRealvalue')  != undefined) realValue    = a.data('tagRealvalue');
    else if (a.data('tagValue') != undefined) realValue    = a.data('tagValue');
    if (a.data('tagOperator')   != undefined) operator     = a.data('tagOperator');
    
    let filter = {
	id: key,
	value: realValue,
	operator: operator,
    };
    add_filter(filter);
}    

function add_top_table_filter(opt, event) {
    event.stopPropagation();
    let filter = {
	id: opt.key,
	value: opt.value,
	operator: opt.operator,
    };
    add_filter(filter);
}

function add_filter(filter) {
    if (range_picker.value.is_filter_defined(filter)) {
	ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_MODAL_FILTERS, filter);
    } else {
	ntopng_url_manager.set_key_to_url("query_preset", "");
	ntopng_url_manager.set_key_to_url(filter.id, `${filter.value};${filter.operator}`);
	ntopng_url_manager.reload_url();
    }    
}

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
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
    params.csrf = props.context.csrf;
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

function refresh_page_components() {
    let t = table_alerts.value;
    let c = chart.value;
    setTimeout(() => {
	t.refresh_table();
	c.update_chart();
    }, 1 * 1000);
}

function on_table_custom_event(event) {
    let events_managed = {
	"click_button_info": click_button_info,
	"click_button_flow_alerts": click_button_flow_alerts,
	"click_button_historical_flows": click_button_historical_flows,
	"click_button_pcap_download": click_button_pcap_download,
    };
    if (events_managed[event.event_id] == null) {
	return;
    }
    events_managed[event.event_id](event);
}

function click_button_info(event) {
    const flow = event.row;
    const href = `${http_prefix}/lua/pro/db_flow_details.lua?row_id=${flow.rowid}&tstamp=${flow.tstamp}&instance_name=${flow.NTOPNG_INSTANCE_NAME}`;
    window.open(href, "_blank");
}

function click_button_pcap_download(event) {
    const flow = event.row;
    modal_traffic_extraction.value.show(flow?.filter?.bpf);
}

function click_button_historical_flows(event) {
    const flow = event.row;
    let filters_params_object = {};
    for (let key in flow) {
	let filter_key = key;
	if (flow[key].tag_key != null && flow[key].tag_key != "") {
            filter_key = flow[key].tag_key;
	}
        if (flow[key].value == null && flow[key].value != "") { continue; }
    	let filter = `${flow[key].value};eq`;
    	filters_params_object[filter_key] = filter;
    }
    ntopng_url_manager.set_key_to_url("query_preset", "");
    ntopng_url_manager.add_obj_to_url(filters_params_object);
    ntopng_url_manager.reload_url();
}

function click_button_flow_alerts(event) {
    const flow = event.row;
    if (flow.alerts_url) {
	ntopng_url_manager.go_to_url(flow.alerts_url);
    }
}

function get_status_view() {
    let status_view = ntopng_url_manager.get_url_entry("status");
    if (status_view == null || status_view == "") {
	status_view = "historical";
    }
    return status_view;
}

</script>

<style scoped>
</style>