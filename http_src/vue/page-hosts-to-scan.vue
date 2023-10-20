<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">
        <div class="card-body">
          <div v-if="autorefresh" class="alert alert-info alert-dismissable">
            <span class="spinner-border spinner-border-sm text-info me-1"></span> 
            <span> {{ in_progress_scan_text }}</span>
          </div>
          <div v-if="insert_with_success" class="alert alert-success alert-dismissable">
            <span class="text-success me-1"></span> 
            <span> {{ insert_text }}</span>
          </div>
          <div v-if="already_inserted" class="alert alert-danger alert-dismissable">
            <span class="text-danger me-1"></span> 
            <span> {{ already_insert_text }}</span>
          </div>
          
          <div id="hosts_to_scan">
            <ModalDeleteScanConfirm ref="modal_delete_confirm" :title="title_delete" :body="body_delete" @delete="delete_row" @delete_all="delete_all_rows" @scan_row="scan_row" @scan_all_rows="scan_all_entries">
            </ModalDeleteScanConfirm>
            <ModalUpdatePeriodicityScan
              ref="modal_update_perioditicy_scan" :title="title_update_periodicity_scan" @update="update_all_scan_frequencies">
            </ModalUpdatePeriodicityScan>
            <TableWithConfig ref="table_hosts_to_scan" :table_id="table_id" :csrf="context.csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
              <template v-slot:custom_header>
                <button class="btn btn-link" type="button" ref="add_host" @click="add_host"><i
                    class='fas fa-plus'></i></button>
              </template>
            </TableWithConfig>

          </div>
          
        </div>
        <div class="card-footer mt-3">
            <button type="button" ref="delete_all" @click="delete_all_entries" class="btn btn-danger me-1" :class="{ 'disabled': total_rows == 0}"><i
                class='fas fa-trash'></i> {{ _i18n("delete_all_entries") }}</button>

            <button type="button" ref="scan_all" @click="confirm_scan_all_entries" class="btn btn-primary me-1" :class="{ 'disabled': total_rows == 0}"><i
                class='fas fa-clock-rotate-left'></i> {{ _i18n("hosts_stats.page_scan_hosts.schedule_all_scan") }}</button>
            <template v-if="props.context.is_enterprise_l">

            <button type="button" ref="update_all" @click="update_all_periodicity" class="btn btn-secondary me-1" :class="{ 'disabled': total_rows == 0}">{{ _i18n("hosts_stats.page_scan_hosts.update_periodicity_title") }}</button>          
            </template>
            </div>

        <div class="card-footer">
        <NoteList
        :note_list="note_list">
        </NoteList>
      </div>

      </div>
    </div>
  </div>
  <ModalAddHostToScan ref="modal_add" :context="context" @add="add_host_rest" @edit="edit" @closeModal="update_modal_status(false)" @openModal="update_modal_status(true)" @hidden="update_modal_status(false)" >
  </ModalAddHostToScan>
</template>
  
<script setup>

/* Imports */ 
import { ref, onBeforeMount, onMounted, nextTick } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as ModalDeleteScanConfirm } from "./modal-delete-scan-confirm.vue";
import { default as ModalUpdatePeriodicityScan } from "./modal-update-periodicity-scan.vue";
import { ntopng_utility } from '../services/context/ntopng_globals_services';
import { default as ModalAddHostToScan } from "./modal-add-host-to-scan.vue";
import { columns_formatter } from "../utilities/vs_report_formatter.js"; 

/* ******************************************************************** */ 

/* Consts */ 
const _i18n = (t) => i18n(t);

let autorefresh = ref(false);
let modal_opened = ref(false);
let insert_with_success = ref(false);
let already_inserted = ref(false);
let note = _i18n('hosts_stats.page_scan_hosts.notes.generic_notes_1').replaceAll("${http_prefix}",`${http_prefix}`);

const note_list = [
  note
]

let insert_text = ref(_i18n('scan_host_inserted'));
let already_insert_text = ref(_i18n('scan_host_already_inserted'));
let in_progress_scan_text = ref(_i18n('scan_in_progress'));

const title_html = ref(i18n("scan_hosts"));


const table_id = ref('hosts_to_scan');
let title_delete = _i18n('hosts_stats.page_scan_hosts.delete_host_title');
let body_delete = _i18n('hosts_stats.page_scan_hosts.delete_host_description');

let title_update_periodicity_scan = _i18n('hosts_stats.page_scan_hosts.update_periodicity_title');

const table_hosts_to_scan = ref();
const modal_delete_confirm = ref();
const modal_add = ref();
const modal_vs_result = ref();
const modal_update_perioditicy_scan = ref();
const total_rows = ref(0);

const add_host_url = `${http_prefix}/lua/rest/v2/add/host/to_scan.lua`;
const edit_host_url = `${http_prefix}/lua/rest/v2/edit/host/update_va_scan_period.lua`;
const remove_host_url = `${http_prefix}/lua/rest/v2/delete/host/delete_host_to_scan.lua`;
const scan_host_url = `${http_prefix}/lua/rest/v2/exec/host/schedule_vulnerability_scan.lua`;
const scan_type_list_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_type_list.lua`;
const active_monitoring_url = `${http_prefix}/lua/vulnerability_scan.lua`;
const scan_result_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_result.lua`;
const check_status_url = `${http_prefix}/lua/rest/v2/get/host/vulnerability_scan_status.lua`;
const in_progress_number = ref(null);

const row_to_delete = ref({});
const row_to_scan = ref({});
let scan_type_list = [];
let get_scan_type_list_v = null;

const props = defineProps({
  context: Object,
});
const rest_params = {
  csrf: props.context.csrf
};
const context = ref({
  csrf: props.context.csrf,
  ifid: props.context.ifid,
  is_enterprise_l: props.context.is_enterprise_l
});

/* ******************************************************************** */ 

/* Function to add a new host to scan */ 
function add_host() {
  if (props.context.host != null && props.context.host != "")
    modal_add.value.show(null, props.context.host);
  else
    modal_add.value.show();
}

/* ******************************************************************** */ 

/* Function to refresh table */ 
function refresh_table(disable_loading) {
  /* It's important to set autorefresh to false, in this way when refreshed 
     all the entries are going to be checked and if all of them are not scanning it stays false
   */
  total_rows.value = table_hosts_to_scan.value.get_rows_num();
  console.log(total_rows.value)
  //console.log("REFRESHING")
  if(disable_loading != null)
    table_hosts_to_scan.value.refresh_table(disable_loading);
  else
    table_hosts_to_scan.value.refresh_table(true);

  
}

/* ******************************************************************** */ 

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ******************************************************************** */ 

/* Function to handle all buttons */
function on_table_custom_event(event) {
  
  let events_managed = {
    "click_button_edit_host": click_button_edit_host,
    "click_button_delete": click_button_delete,
    "click_button_scan": click_button_scan,
    "click_button_download": click_button_download,
    "click_button_show_result": click_button_show_result,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}


function compare_by_host_ip(r0,r1) {

  const col = {
      "data": {
          "title_i18n": "db_explorer.host_data",
          "data_field": "host",
          "sortable": true,
          "class": [
              "text-nowrap"
          ]
      }
    }
    let r0_col = r0[col.data.data_field];
    let r1_col = r1[col.data.data_field];
    r0_col = NtopUtils.convertIPAddress(r0_col);
    r1_col = NtopUtils.convertIPAddress(r1_col);
    
    return r0_col.localeCompare(r1_col);
}


function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = r0[col.data.data_field];
    let r1_col = r1[col.data.data_field];
    if(col.id == "host") {
      r0_col = NtopUtils.convertIPAddress(r0_col);
      r1_col = NtopUtils.convertIPAddress(r1_col);
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "host_name") {

      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    }
    else if(col.id == "num_vulnerabilities_found") {
      /* It's an array */
      r0_col = format_num_for_sort(r0_col);
      r1_col = format_num_for_sort(r1_col);

      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col - r1_col;
      }
      return r1_col - r0_col; 
    } else if ( col.id == "tcp_ports" || col.id == "udp_ports") {
      r0_col = format_num_ports_for_sort(r0_col);
      r1_col = format_num_ports_for_sort(r1_col);
      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col - r1_col;
      }
      return r1_col - r0_col;
    } 
    else if(col.id == "duration") {
      r0_col = r0["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r0["last_scan"][col.data.data_field];
      r1_col = r1["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r1["last_scan"][col.data.data_field];
      if (r1_col != i18n("hosts_stats.page_scan_hosts.not_yet"))
        r1_col = r1_col.split(" ")[0];
      
      if (r0_col != i18n("hosts_stats.page_scan_hosts.not_yet"))
        r0_col = r0_col.split(" ")[0];
      
      
      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }

      if(r0_col == i18n("hosts_stats.page_scan_hosts.not_yet")){
        r0_col = "-1";

      }
      if(r1_col == i18n("hosts_stats.page_scan_hosts.not_yet"))
        r1_col = "-1";

      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "last_scan") {
      r0_col = r0["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r0["last_scan"]["time"];
      r1_col = r1["last_scan"] === undefined ? i18n("hosts_stats.page_scan_hosts.not_yet") : r1["last_scan"]["time"];
      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }

      if(r0_col == i18n("hosts_stats.page_scan_hosts.not_yet")){
        r0_col = "00000000";
      }
      if(r1_col == i18n("hosts_stats.page_scan_hosts.not_yet"))
        r1_col = "0000000000";
      
      return r1_col.localeCompare(r0_col);
    } else if (col.id == "is_ok_last_scan") {
      r0_col = get_scan_status_value(r0_col, r0);
      r1_col = get_scan_status_value(r1_col, r1);

      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "max_score_cve") {
      r0_col = r0_col != null ? r0_col : 0;
      r1_col = r1_col != null ? r1_col : 0;

      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col - r1_col;
      }
      return r1_col - r0_col; 
    }else if(col.id == "scan_frequency") {
      r0_col = get_scan_frequency(r0_col);
      r1_col = get_scan_frequency(r1_col);


      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);  
    } else {

      if (r0_col == r1_col) {
        return compare_by_host_ip(r0,r1);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    }	
  } else {
    return compare_by_host_ip(r0,r1);
  }
  
}

/* ******************************************************************** */ 

function get_scan_frequency(scan_frequency) {
  if (scan_frequency == "1day") {
    return i18n("hosts_stats.page_scan_hosts.daily");
  } else if (scan_frequency == "1week") {
    return i18n("hosts_stats.page_scan_hosts.weekly");
  } else {
    return "";
  }
}

/* ******************************************************************** */ 

function get_scan_status_value(is_ok_last_scan, r) {
  let status = "";
  if (is_ok_last_scan == 2) {
    status = i18n("hosts_stats.page_scan_hosts.scheduled");
  } else if (is_ok_last_scan == 4) {
    status = i18n("hosts_stats.page_scan_hosts.scanning");
  } else if (is_ok_last_scan == 3 || is_ok_last_scan == null) {
    status = i18n("hosts_stats.page_scan_hosts.not_scanned");
  } else if (is_ok_last_scan == 1) {
    status = i18n("hosts_stats.page_scan_hosts.success");
  } else {
    status = i18n("hosts_stats.page_scan_hosts.error");
  }
  return status + r.id;
}

/* ******************************************************************** */ 

function format_num_for_sort(num) {
  if (num === "" || num === null || num === NaN || num === undefined) {
    num = 0;
  } else {
    num = num.split(',').join("")
    num = parseInt(num);
  }

  return num;
}

/* ******************************************************************** */ 

function format_num_ports_for_sort(num) {
  if (num == "" || num == null || num == NaN || num == undefined) 
    num = 0;

  num = parseInt(num);;
  return num;
}

/* ******************************************************************** */ 

/* Function to handle delete button */
async function click_button_delete(event) {

  insert_with_success.value = false;
  already_inserted.value = false;
  
  refresh_feedback_messages();
  row_to_delete.value = event.row;
  modal_delete_confirm.value.show("delete_single_row",i18n("delete_vs_host"));  
}

/* ******************************************************************** */ 

/* Function to handle scan button */
async function click_button_scan(event) {
  insert_with_success.value = false;
  already_inserted.value = false;
  refresh_feedback_messages();
  row_to_scan.value = event.row;
  const scan_host_msg = `${i18n("scan_host")}`
  modal_delete_confirm.value.show("scan_row", scan_host_msg);  
}

/* ******************************************************************** */ 

/* Function to handle edit button */
function click_button_edit_host(event) {
  const row = event.row;
  //row_to_delete.value = row;
  modal_add.value.show(row);
}

/* ******************************************************************** */ 

/* Function to delete all entries */
function delete_all_entries() {
  insert_with_success.value = false;
  already_inserted.value = false;
  refresh_feedback_messages();
  modal_delete_confirm.value.show('delete_all', i18n('delete_all_vs_hosts'));
  total_rows.value = table_hosts_to_scan.value.get_rows_num();
}

/* Function to edit host to scan */
async function edit(params) {
  //await delete_row();
  params.is_edit = true;
  await add_host_rest(params);
}

/* Every 10 second check if the autorefresh is enabled or not, if it is refresh the table */
function set_autorefresh() {
  if(autorefresh.value == true && modal_opened.value == false)
    setTimeout(check_autorefresh, 10000);
}

/* Every 10 second check to disable feedbacks */
async function set_already_insert_or_insert_with_success() {
  if(insert_with_success.value == true) {
    insert_with_success.value = false;
    insert_text.value = i18n('scan_host_inserted');
  }

  if(already_inserted.value == true) {
    already_insert_text.value = i18n('scan_host_already_inserted');  
    already_inserted.value = false;
  }
}

/* Every 10 second check to disable autorefresh */
async function check_autorefresh() {
  await check_in_progress_status();
  set_autorefresh();
}

/* ******************************************************************** */ 

/* Function to map columns data */
const map_table_def_columns = async (columns) => {
  let result = columns_formatter(columns, scan_type_list, false);

  return result;
};

/* ******************************************************************** */ 

onBeforeMount(async () => {
  get_scan_type_list_v = Promise.all([get_scan_type_list(),check_in_progress_status()]);
})

/* ******************************************************************** */ 

onMounted(async () => {
  await get_scan_type_list_v;
  await modal_add.value.metricsLoaded(scan_type_list, props.context.ifid, props.context.is_enterprise_l);
  total_rows.value = table_hosts_to_scan.value.get_rows_num();
  
  if (props.context.host != null) {
    modal_add.value.show(null, props.context.host);
  }

  /* Check again the status in 10 seconds, already checked a couple of seconds ago */
  setTimeout(check_autorefresh, 10000);
})

/* ************************** REST Functions ************************** */

/* Function to add a new host during edit */
const add_host_rest = async function (params) {
  const url = NtopUtils.buildURL(add_host_url, {
    ...params
  })

  insert_text = ref(_i18n('scan_host_inserted'));

  const result = await ntopng_utility.http_post_request(url, rest_params);
  modal_add.value.close();
  if (result.rsp == true) {
    
    if (params.is_edit) {
      insert_text = ref(_i18n('scan_host_updated'));
    }
    if (params.cidr != null) {
      insert_text.value = insert_text.value.replace("%{host}", `${params.host}/${params.cidr}`);
    } else {
      insert_text.value = insert_text.value.replace("%{host}", `${params.host}`);
    }
    insert_with_success.value = true;
    already_inserted.value = false;
    already_insert_text.value = i18n('scan_host_already_inserted');  

    setTimeout(set_already_insert_or_insert_with_success,10000);

    refresh_table(false);
    
  } else {
    if (params.cidr != null) {
      already_insert_text.value = already_insert_text.value.replace("%{host}", `${params.host}/${params.cidr}`);
    } else {
      already_insert_text.value = already_insert_text.value.replace("%{host}", `${params.host}`);
    }

    let scan_type_label = "";

    scan_type_list.forEach((item) => {
      if(item.id == params.scan_type) {
        scan_type_label = item.label;
      }
    });

    already_insert_text.value = already_insert_text.value.replace("%{scan_type}", `${scan_type_label}`);


    already_inserted.value = true;
    insert_with_success.value = false;
    setTimeout(set_already_insert_or_insert_with_success,10000);

    insert_text.value = i18n('scan_host_inserted');

  }

  if (params.is_edit != true){
    check_autorefresh()
    refresh_table(false);
  };
}

/* ******************************************************************** */ 

const refresh_feedback_messages = function (in_progress) {
  already_insert_text.value = i18n('scan_host_already_inserted');  
  insert_text.value = i18n('scan_host_inserted');
  if (in_progress != null && in_progress != 0) {
    if (in_progress_scan_text.value.includes("total"))
      in_progress_scan_text.value = in_progress_scan_text.value.replace("total",`${in_progress}`);
    else {

      in_progress_scan_text.value = _i18n('scan_in_progress');
      in_progress_scan_text.value = in_progress_scan_text.value.replace("total",`${in_progress}`);

    }
  }
}

/* ******************************************************************** */ 

const update_all_scan_frequencies = async function(params) {
  const url = NtopUtils.buildURL(edit_host_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);  

  insert_with_success.value = false;
  already_inserted.value = false;
  refresh_feedback_messages();
  refresh_table(false);
}

/* ******************************************************************** */ 

/* Function to retrieve scan types list */
const get_scan_type_list = async function () {
  const url = NtopUtils.buildURL(scan_type_list_url, {
    ...rest_params
  })

  const result = await ntopng_utility.http_request(url);
  scan_type_list = result.rsp;
}

/* ******************************************************************** */ 

/* Function to check if there is a scan in progress */
const check_in_progress_status = async function () {
  const url = NtopUtils.buildURL(check_status_url, {
    ...rest_params
  })

  const result = await ntopng_utility.http_request(url);
  insert_with_success.value = false;
  already_inserted.value = false;
  refresh_feedback_messages(result.rsp.total_in_progress);
  
  /* Get the number of scans currently in progress */
  /* In case the number changed, refresh the table */
  if(in_progress_number.value == null) {
    /* First time checking the number of scans, don't refresh the table */
    in_progress_number.value = result.rsp.total_in_progress;
  }

  const scans_ended = result.rsp.total_in_progress == 0 && in_progress_number.value > 0;
  in_progress_number.value = result.rsp.total_in_progress;
  autorefresh.value = (in_progress_number.value > 0
                      && modal_opened.value === false);

  if(autorefresh.value === true) {
    /* Refresh the data, periodic update */
    setTimeout(function() {
      refresh_table(true);
    }, 2000);
  } else if(scans_ended) {
    /* Refresh the data, all scans ended */
    setTimeout(function() {
      refresh_table(true);
    }, 5000);    
  }
}

/* ******************************************************************** */ 

/* Function to confirm to start all scan */
const confirm_scan_all_entries = function() {
  modal_delete_confirm.value.show("scan_all_rows",i18n("scan_all_hosts"));  
  refresh_table(false);
}

/* Function to update all scan  frequencies*/
const update_all_periodicity = function() {
  modal_update_perioditicy_scan.value.show();
}

/* ******************************************************************** */ 

/* Function to exec the vulnerability scan of a single host */
const scan_row = async function () {
  const row = row_to_scan.value;
  await scan_row_rest(row.host,row.scan_type, row.ports, row.id);
  refresh_table(true /* Disable loading, annoying when enabling a scan */);
}

/* ******************************************************************** */ 

const scan_row_rest = async function(host, scan_type, ports, id) {
  const url = NtopUtils.buildURL(scan_host_url, {
    host: host,
    scan_type: scan_type,
    scan_single_host: true,
    scan_ports: ports,
    scan_id: id
  })
  await ntopng_utility.http_post_request(url, rest_params);
  check_autorefresh();
}

/* ******************************************************************** */ 

/* Function to exec a vulnerability scan to all hosts set */
async function scan_all_entries() {
  const url = NtopUtils.buildURL(scan_host_url, {
    scan_single_host: false,
  })
  await ntopng_utility.http_post_request(url, rest_params);
  check_autorefresh();
  refresh_table(false);
}

/* ******************************************************************** */ 

/* Function to delete host to scan */
const delete_row = async function () {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_host_url, {

    host: row.host,
    scan_type: row.scan_type,
    delete_all_scan_hosts: false,
    scan_id: row.id

  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh_table(false);
}

/* ******************************************************************** */ 

const delete_all_rows = async function() {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_host_url, {
    delete_all_scan_hosts: true
  })

  await ntopng_utility.http_post_request(url, rest_params);
  autorefresh.value = false;
  refresh_table(false);
}

/* ******************************************************************** */ 

/* Function to download last vulnerability scan result */
async function click_button_download(event) {
  let params = {
    host: event.row.host,
    scan_type: event.row.scan_type
  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${scan_result_url}?${url_params}`;
  ntopng_utility.download_URI(url);
}

/* ******************************************************************** */ 

/* Function to show last vulnerability scan result */
async function click_button_show_result(event) {
  let host = event.row.host;
  let date = event.row.last_scan.time.replace(" ","|");

  let params = {
    host: host,
    scan_type: event.row.scan_type,
    scan_return_result: true,
    page: "show_result",
    scan_date: date

  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${active_monitoring_url}?${url_params}`;
  ntopng_url_manager.go_to_url(url);
}

async function update_modal_status(value) {
  // update the modal_opened var used for disable/enable autorefresh when
  // modal is open/closed
  modal_opened.value = value;
  await check_autorefresh();
}


/* ******************************************************************** */ 

</script>
  