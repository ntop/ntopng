<template>
  

<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="alert alert-danger d-none" id='alert-row-buttons' role="alert">
    </div>
    <div class="card">
      <div class="card-body">
        <div v-if="is_learning_status" class="alert alert-info">
          {{ learning_message }}
        </div>
      	<div id="table_devices_vue">
          <modal-delete-confirm ref="modal_delete_confirm"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_row">
          </modal-delete-confirm>
          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete_all"
            :body="body_delete_all"
            @delete="delete_all">
          </modal-delete-confirm>
          <modal-add-device-exclusion ref="modal_add_device"
            :title="title_add"
            :body="body_add"
            :footer="footer_add"
            :list_notes="list_notes_add"
            @add="add_device_rest">
          </modal-add-device-exclusion>
          <modal-edit-device-exclusion ref="modal_edit_device"
            :title="title_edit"
            :title_edit_all="title_edit_all"
            @edit="edit_row">
          </modal-edit-device-exclusion>
            
          <TableWithConfig ref="table_device_exclusions"
				        :csrf="csrf"
				        :table_id="table_id"
                :f_map_columns="map_table_def_columns"
				        :get_extra_params_obj="get_extra_params_obj"
                :f_map_config="map_config"
                :f_sort_rows="columns_sorting"
                @custom_event="on_table_custom_event">
                <template v-slot:custom_header>
                <button class="btn btn-link" type="button" ref="add_device" @click="add_device"><i
                    class='fas fa-plus'></i></button>
              </template>
          </TableWithConfig>
        </div>
      </div>
      <div class="card-footer mt-3">
        <button type="button" @click="delete_all_confirm"  class="btn btn-danger me-1">
          <i class='fas fa-trash'></i> {{ _i18n("edit_check.delete_all_device_exclusions") }}
        </button>
        <button type="button" @click="edit_all_devices_confirm"  class="btn btn-secondary">
          <i class='fas fa-edit'></i> {{ _i18n("edit_check.edit_all_devices_status") }}
        </button>
      </div>
          
  </div>
  <NoteList :note_list="notes_list" :add_sub_notes=true 
                    :sub_note_list="sub_notes_list"> 
          </NoteList>
    </div>
</div>
</template>

<script setup>
import  TableWithConfig  from "./table-with-config.vue";
import  ModalDeleteConfirm  from "./modal-delete-confirm.vue";
import  ModalAddDeviceExclusion  from "./modal-add-device-exclusion.vue";
import  ModalEditDeviceExclusion  from "./modal-edit-device-exclusion.vue";
import { default as NoteList } from "./note-list.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { ref, onMounted } from "vue";


const table_device_exclusions = ref();
const modal_delete_confirm = ref();
const modal_delete_all = ref();
const modal_add_device = ref();
const modal_edit_device = ref();

const table_id = ref('device_exclusions');

const add_url             = `${http_prefix}/lua/pro/rest/v2/add/device/exclusion.lua`;
const delete_url          = `${http_prefix}/lua/pro/rest/v2/delete/device/exclusion.lua`;
const edit_url            = `${http_prefix}/lua/pro/rest/v2/edit/device/exclusion.lua`;
const learning_status_url = `${http_prefix}/lua/pro/rest/v2/get/device/learning_status.lua`;
const is_learning_status = ref(false);
const _i18n = (t) => i18n(t);

let title_delete= '';
let body_delete= '';
let title_delete_all= _i18n('edit_check.delete_all_device_exclusions');
let body_delete_all=  _i18n('edit_check.delete_all_device_exclusions_message');
let title_add= _i18n('edit_check.add_device_exclusion');
let body_add= _i18n('edit_check.add_device_exclusion_message');
let footer_add= _i18n('edit_check.add_device_exclusion_notes');
let list_notes_add= _i18n('edit_check.add_device_exclusion_list_notes');
let title_edit= _i18n('edit_check.edit_device_exclusion');
let title_edit_all= _i18n('edit_check.edit_all_devices_status');
let learning_message= _i18n('edit_check.learning');
let row_to_delete= ref(null);
let row_to_edit= ref(null);

const props = defineProps({
    context: Object
});


const rest_params = {
  csrf: props.context.csrf,
  ifid: props.context.ifid
};

const notes_list = [
  _i18n("edit_check.device_exclusion_page_notes.note_1")
];

const sub_notes_list = [
  _i18n("edit_check.device_exclusion_page_notes.sub_note_1"),
  _i18n("edit_check.device_exclusion_page_notes.sub_note_2")
];

/* ******************************************************************** */ 

/* Function to handle all buttons */
function on_table_custom_event(event) {
  
  let events_managed = {
    "click_button_edit_device": click_button_edit_device,
    "click_button_historical_flows": click_button_historical_flows,
    "click_button_delete": click_button_delete,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

async function click_button_delete(event) {
  let body = `${i18n('edit_check.delete_device_exclusion')} ${event.row.mac_address.mac}`;
  row_to_delete.value = event.row;

  body_delete = body;

  title_delete = i18n('edit_check.device_exclusion');
  modal_delete_confirm.value.show(body_delete, title_delete);    
  
}

async function click_button_edit_device(event) {
  row_to_edit.value = event.row;
  modal_edit_device.value.show(row_to_edit.value);  
}

function click_button_historical_flows(event) {
  const rowData = event.row;
  const url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${rowData.first_seen.timestamp}&epoch_end=${rowData.last_seen.timestamp}&mac=${rowData.mac_address.mac};eq&aggregated=false`
  window.open(url, '_blank');
}

onMounted(async () => {

  await learning_status();

})

const csrf = props.crsf;

/* Function to delete device */
const delete_row = async function () {
  const row = row_to_delete.value;

  const url = NtopUtils.buildURL(delete_url, {
    device: row.mac_address.mac,
  })

  rest_params.device = {
    mac: row.mac_address.mac
  };
  await ntopng_utility.http_post_request(url, rest_params);
  refresh();

}

const delete_all_confirm = async function() {
  modal_delete_all.value.show();
}

const edit_all_devices_confirm = async function() {
  modal_edit_device.value.show();
}

/* Function to delete all devices */
const delete_all = async function () {
  const url = NtopUtils.buildURL(delete_url, {
    device: 'all',
  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh();

};

const learning_status = async function() {
    
  const rsp = await ntopng_utility.http_request(learning_status_url);
  if(rsp.learning_done) {
    is_learning_status.value = false;
  } else {
    is_learning_status.value = true;
  }
}

const refresh = async function() {
  await learning_status();
  table_device_exclusions.value.refresh_table();
}

function add_device() {
  modal_add_device.value.show();
}

const add_device_rest = async function (set_params_in_url) {
  let params = set_params_in_url;
  params.mac_list = params.mac_list.replace(/(?:\t| )/g,'')
  params.mac_list = params.mac_list.replace(/(?:\r\n|\r|\n)/g, ',');

  const url = NtopUtils.buildURL(add_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);
  refresh();
          
};

const edit_row = async function(params) {
  let row = row_to_edit.value;
  if(row != null)
    params.mac_alias = params.mac_alias.replace(/(?:\t| )/g,'');   
  if(row != null)
    params.mac = row.mac_address.mac;
  params.csrf = props.context.csrf;

  const url = NtopUtils.buildURL(edit_url, {
    ...params
  })

  await ntopng_utility.http_post_request(url, rest_params);

  refresh();
};


function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = r0[col.data.data_field];
    let r1_col = r1[col.data.data_field];
    if(col.id == "last_ip") {
      if (r0_col != '') {
        r0_col = take_ip(r0_col);
        r0_col = NtopUtils.convertIPAddress(r0_col);
      } 
      if (r1_col != '') {
        r1_col = take_ip(r1_col);
        r1_col = NtopUtils.convertIPAddress(r1_col);
      }
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "manufacturer" ) {
      if (r0_col === undefined) r0_col = '';
      if (r1_col === undefined) r1_col = '';
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if(col.id == "mac_address") {
      r0_col = r0_col.mac;
      r1_col = r1_col.mac;
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    }else if(col.id == "first_seen") {
      r0_col = r0["first_seen"]["timestamp"] == 0 ? 0 : r0["first_seen"]["timestamp"];
      r1_col = r1["first_seen"]["timestamp"] == 0 ? 0 : r1["first_seen"]["timestamp"];
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort)
    } else if(col.id == "last_seen") {
      r0_col = r0["last_seen"]["timestamp"] == 0 ? 0 : r0["last_seen"]["timestamp"];
      r1_col = r1["last_seen"]["timestamp"] == 0 ? 0 : r1["last_seen"]["timestamp"];
      return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort)
    } else if (col.id == "status") {
      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    } else if (col.id == "trigger_alert") {
      r0_col = format_bool(r0_col);
      r1_col = format_bool(r1_col);

      if (col.sort == 1) {
        return r0_col.localeCompare(r1_col);
      }
      return r1_col.localeCompare(r0_col);
    }
  }
  
}

function take_ip(r_col) {
  const ip = r_col.split('host=')[1].split("\'")[0];
  return ip;
}

function format_bool(r_col) {
  if (r_col) {
    return 'true';
  }

  if (!r_col) {
    return 'false';
  }

  if (r_col == 'true') {
    return r_col;
  }

  if (r_col == 'false') {
    return r_col;
  }
}

const map_table_def_columns = async (columns) => {
    
  let map_columns = {
    "mac_address": (data, row) => {
      let label = data.mac;
      let alias = data.alias;

      if ((data.symbolic_mac) && (data.symbolic_mac != label))
        label = data.symbolic_mac;

      if ((alias != null) && (alias != label))
        label = `${label} (${alias})`;

      if (data.url != null)
        label = `<a href='${data.url}' title='${data.mac}'>${label}</a>`;

      return label;
    },
    "first_seen": (first_seen, row) => {
      if (first_seen.timestamp == 0) {
        return '';
      } else {
        return first_seen.data;
      }
    }, 
    "last_seen": (last_seen, row) => {
      if (last_seen.timestamp == 0) {
        return '';
      } else {
        return last_seen.data;
      }
    },
    "status": (status, row) => {
      //<span class="badge bg-success" title="${label}">${label}</span>
      //<span class="badge bg-danger" title="${label}">${label}</span>
      //const label = _i18n(status);
      let label = "";
      if (status == "allowed") {
        label = _i18n("edit_check.authorized");
        return `<span class="badge bg-success" title="${label}">${label}</span>`
      } else {
        label = _i18n("edit_check.unauthorized");
        return `<span class="badge bg-danger" title="${label}">${label}</span>`
      }

    },
    "trigger_alert": (trigger_alert, row) => {
      let is_enabled = false;
      if (trigger_alert == "false") 
        is_enabled = false;
      else
        is_enabled = trigger_alert;
      return is_enabled ? `<i class="fas fa-check text-success"></i>` : `<i class="fas fa-times text-danger"></i>`;
    }
  }
  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];

    /*if (c.id == "actions") {
            
      c.button_def_array.forEach((b) => {
          
        b.f_map_class = (current_class, row) => { 
          current_class = current_class.filter((class_item) => class_item != "link-disabled");
          if((row.is_ok_last_scan == 4 || row.is_ok_last_scan == null || row.num_open_ports < 1) && visible_dict[b.id]) {
            current_class.push("link-disabled"); 
          }
          return current_class;
        }
      });
    }*/
  });
    // console.log(columns);
  return columns;
};

const get_extra_params_obj = () => {
    /*let params = get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows);
    set_params_in_url(params);*/
    let params = get_url_params();
    return params;
};

function get_url_params() {
    let actual_params = {
        ifid: ntopng_url_manager.get_url_entry("ifid") || props.context.ifid,
    };    

    return actual_params;
}

const map_config = (config) => {
    return config;
};

</script>
