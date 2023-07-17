<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">

        <div class="card-body">
          <div id="hosts_to_scan">
            <ModalDeleteConfirm ref="modal_delete_confirm"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_row">
          </ModalDeleteConfirm>
            <TableWithConfig ref="table_hosts_to_scan" :table_id="table_id" :csrf="context.csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              @custom_event="on_table_custom_event">
              <template v-slot:custom_header>
                <button class="btn btn-link" type="button" ref="add_host" @click="add_host"><i
                    class='fas fa-plus'></i></button>
              </template>
            </TableWithConfig>

          </div>
          <div class="card-footer mt-3">
            <button type="button" ref="delete_all" @click="delete_all_entries" class="btn btn-danger me-1"><i
                class='fas fa-trash'></i> {{ _i18n("delete_all_entries") }}</button>
            
                <button type="button" ref="scan_all" @click="scan_all_entries" class="btn btn-primary me-1"><i
                class='fas fa-search'></i> {{ _i18n("hosts_stats.page_scan_hosts.schedule_all_scan") }}</button>
          
            </div>
        </div>
      </div>
    </div>
  </div>
  <ModalAddHostToScan ref="modal_add" :context="context" 
  @add="add_host_rest"
  @edit="edit">
  </ModalAddHostToScan>
</template>
  
<script setup>
import { ref, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { ntopng_utility } from '../services/context/ntopng_globals_services';
import { default as ModalAddHostToScan } from "./modal-add-host-to-scan.vue"

const _i18n = (t) => i18n(t);

const table_id = ref('hosts_to_scan');
let title_delete = _i18n('hosts_stats.page_scan_hosts.delete_host_title');
let body_delete = _i18n('hosts_stats.page_scan_hosts.delete_host_description');

const table_hosts_to_scan = ref();
const modal_delete_confirm = ref();
const modal_add = ref();
const add_host_url = `${http_prefix}/lua/rest/v2/add/host/to_scan.lua`;
const remove_host_url = `${http_prefix}/lua/rest/v2/delete/host/delete_host_to_scan.lua`;
const scan_host_url = `${http_prefix}/lua/rest/v2/add/host/scan_host.lua`;
const scan_result_url = `${http_prefix}/lua/rest/v2/get/host/scan_result.lua`;
const scan_type_list_url = `${http_prefix}/lua/rest/v2/get/host/scan_type_list.lua`;


const row_to_delete = ref({});
const row_to_scan = ref({});
let scan_type_list = [];

const props = defineProps({
  context: Object,
});
const rest_params = {
  csrf: props.context.csrf
}
const add_host_rest = async function (params) {
  const url = NtopUtils.buildURL(add_host_url, {
    ...rest_params,
    ...params
  })

  await $.post(url, function (rsp, status) {
    refresh_table();
  });
}

const change_applications_tab_event = "change_applications_tab_event";

const context = ref({
  csrf: props.context.csrf,
})

/* ************************************** */

function add_host() {
  modal_add.value.show();
  refresh_table();
}
/* ************************************** */

function refresh_table() {
  table_hosts_to_scan.value.refresh_table();
}

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_edit_host": click_button_edit_host,
    "click_button_delete": click_button_delete,
    "click_button_scan": click_button_scan,
    "click_button_download": click_button_download,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ************************************** */

async function click_button_delete(event) {
  row_to_delete.value = event.row;
  await delete_row();
  refresh_table();
}

/* ************************************** */

async function click_button_scan(event) {
  row_to_scan.value = event.row;
  await scan_row();  
  refresh_table();
}

async function click_button_download(event) {
	let params = {
    host: event.row.host,
    scan_type: event.row.scan_type
  };
	let url_params = ntopng_url_manager.obj_to_url_params(params);

  let url = `${scan_result_url}?${url_params}`;
  ntopng_utility.download_URI(url);
}

/* ************************************** */

function delete_all_entries() {
  modal_delete.value.show('all', i18n('delete_all_inactive_hosts'));
}

async function scan_all_entries() {
  const url = NtopUtils.buildURL(scan_host_url, {
    ...rest_params,
    ...{
      scan_single_host: false,
    }
  })
  await $.post(url, function(rsp, status){
    refresh_table();
  });
}

const delete_row = async function() {
  const row = row_to_delete.value;
  const url = NtopUtils.buildURL(remove_host_url, {
    ...rest_params,
    ...{
      host: row.host,
      scan_type: row.scan_type
    }
  })
  await $.post(url, function(rsp, status){
    refresh_table();
  });
}

const scan_row = async function() {
  const row = row_to_scan.value;
  const url = NtopUtils.buildURL(scan_host_url, {
    ...rest_params,
    ...{
      host: row.host,
      scan_type: row.scan_type,
      scan_single_host: true,
    }
  })
  await $.post(url, function(rsp, status){
    refresh_table();
  });
}

const download_row_result = async function() {
  const url = NtopUtils.buildURL(scan_result_url, {
    ...rest_params,
    ...{
      host: row.host,
      scan_type: row.scan_type
    }
  })
  await $.get(url, function(rsp, status){
    refresh_table();
  });
}


async function edit(params) {
  await delete_row();

  await add_host_rest(params);
  refresh_table();

}
/* ************************************** */

function download() {
  modal_download.value.show();
}

/* ************************************** */

function click_button_edit_host(event) {
  const row = event.row;
  row_to_delete.value = row;
  modal_add.value.show(row);
}

/* ************************************** */

const map_table_def_columns = (columns) => {
  
  let map_columns = {
    "scan_type" :(scan_type, row) => {
            if (scan_type !== undefined) {
              let label = scan_type
              scan_type_list.forEach((item) => {
                if(item.id.localeCompare(scan_type) == 0) {
                  label = item.label;
                }
              })
              return label;
            }
      },
    "last_scan":(last_scan, row) => {
            if (last_scan !== undefined && last_scan.time!== undefined) {
              return last_scan.time;
            } else if(last_scan !== undefined) {
              return last_scan;
            } else {
              return "";
            }
      }, 
  }
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];

    if (c.id == "actions") {
      const visible_dict = {
        historical_data: props.show_historical,
      };
      c.button_def_array.forEach((b) => {
        if (!visible_dict[b.id]) {
          b.class.push("disabled");
        }
      });
    }
  });

  return columns;
};

const get_scan_type_list = async function() {
  const url = NtopUtils.buildURL(scan_type_list_url, {
    ...rest_params
  })
  await $.get(url, function(rsp, status){
    scan_type_list = rsp.rsp;
  });
}


onBeforeMount(async () => {
  await get_scan_type_list();
  modal_add.value.metricsLoaded(scan_type_list);
})


/* ************************************** */

</script>
  