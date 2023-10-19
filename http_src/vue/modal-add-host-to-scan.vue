<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{title}}</template>
    <template v-slot:body>
      <!-- Target information, here an IP is put -->
    
  
      <div  class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.host")}}</b>
          </label>
          <div class="col-sm-8" >
            <input v-model="host" @input="check_empty_host" class="form-control" type="text" :placeholder="host_placeholder" required>
          </div>
          <div class="col-sm-2" >
            <SelectSearch v-model:selected_option="selected_cidr"
                @select_option="_load_ports"
                :options="cidr_options_list">
            </SelectSearch>
          </div>
      </div>

      <div  class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.ports")}}</b>
          </label>
            <div class="col-sm-10" >
            <input v-model="ports" @focusout="check_ports" class="form-control" type="text" :placeholder="ports_placeholder" required>
            </div>
            

      </div>
      <div  class="form-group ms-2 me-2 mt-3 row">

        <div class="col-sm-2"></div>
        <div class="col-sm-3">

          <button type="button" @click="load_ports" :disabled="disable_add || disable_load_ports" class="btn btn-primary" >{{_i18n('hosts_stats.page_scan_hosts.load_ports')}}</button>
          <Spinner :show="activate_spinner" size="1rem" class="ms-1"></Spinner>
              <a class="ntopng-truncate" :title="disable_add"></a>

        </div>
        <div class="col-sm-3 mt-1">{{ message_feedback }}</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.scan_type")}}</b>
          </label>
        <div class="col-10">
          
          <SelectSearch v-model:selected_option="selected_scan_type"
                :options="scan_type_list">
          </SelectSearch>
        </div> 
      </div>

      <template v-if="is_enterprise_l == true">
      <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.periodicity")}}</b>
          </label>
        <div class="col-10 ">
          <SelectSearch v-model:selected_option="selected_automatic_scan_frequency"
                :options="automatic_scan_frequencies_list">
          </SelectSearch> 
        </div> 
      </div>

    </template>


      <div class="mt-4">
        <template v-if="is_enterprise_l == false">
          <NoteList
          :note_list="note_list">
          </NoteList>
        </template>
        <template v-else>
          <NoteList
          :note_list="enterprise_note_list">
          </NoteList>
        </template>
      </div>
    </template>

      

      <template v-slot:footer>

      <template v-if="is_edit_page == false">
      <div>
      <button type="button" @click="add_" class="btn btn-primary"  :disabled="disable_add">{{_i18n('add')}}</button>
      <Spinner :show="activate_add_spinner" size="1rem" class="ms-1"></Spinner>
              <a class="ntopng-truncate" :title="disable_add"></a>
      </div>  
    </template>
      <template v-else>
      <div>
      <button type="button" @click="edit_" class="btn btn-primary"  :disabled="disable_add">{{_i18n('apply')}}</button>
      <Spinner :show="activate_add_spinner" size="1rem" class="ms-1"></Spinner>
              <a class="ntopng-truncate" :title="disable_add"></a>
    </div>
    </template>
    </template>

  </modal>
  </template>
  
<script setup>
/* Imports */
import { ref, onBeforeMount, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Spinner } from "./spinner.vue";

import regexValidation from "../utilities/regex-validation.js";
import NtopUtils from "../utilities/ntop-utils";
/* ****************************************************** */

/* Consts */
const modal_id = ref(null);
const selected_scan_type = ref({});
const emit = defineEmits(['add','edit']);
let title = i18n('hosts_stats.page_scan_hosts.add_host');
const host_placeholder = i18n('hosts_stats.page_scan_hosts.host_placeholder');
let ports_placeholder = i18n('hosts_stats.page_scan_hosts.ports_placeholder');
const message_feedback = ref('');

const row_to_edit_id = ref('');

const resolve_host_name_url = `${http_prefix}/lua/rest/v2/get/host/resolve_host_name.lua`;
const server_ports = `${http_prefix}/lua/iface_ports_list.lua`; // ?clisrv=server&ifid=2&host=192.168.2.39
const nmap_server_ports = `${http_prefix}/lua/rest/v2/get/host/ports_by_nmap.lua`;

const _i18n = (t) => i18n(t);
const disable_add = ref(true);
const disable_load_ports = ref(false);
const activate_add_spinner = ref(false);

const activate_spinner = ref(false);
const is_edit_page = ref(false);
const note_list = [
  _i18n('hosts_stats.page_scan_hosts.notes.note_1'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_2'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_3')
];

const enterprise_note_list = [
  _i18n('hosts_stats.page_scan_hosts.notes.note_1'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_2'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_3'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_4')
];

const automatic_scan_frequencies_list = ref([
  { id: "disabled", label:i18n('hosts_stats.page_scan_hosts.disabled')},
  { id: "1day", label:i18n('hosts_stats.page_scan_hosts.every_night')},
  { id: "1week", label:i18n('hosts_stats.page_scan_hosts.every_week')},
]);

const cidr_options_list = ref([
  { id: "24", label:"/24"},
  { id: "32", label:"/32"},
  { id: "128", label:"/128"},
])

const selected_cidr = ref(cidr_options_list.value[1]);

const selected_automatic_scan_frequency = ref(automatic_scan_frequencies_list.value[0]);
const scan_type_list = ref([]);
const ifid = ref(null);
const host = ref(null);
const ports = ref(null);
const showed = () => {};
const props = defineProps({
  context: Object,
});

const is_enterprise_l = ref(null);
/* ****************************************************** */

/**
 * 
 * Reset fields in modal form 
 */
const reset_modal_form = function() {
    host.value = "";
    ports.value = "";
    disable_add.value = true;
    activate_spinner.value = false;
    activate_add_spinner.value = false;
    message_feedback.value = "";
    row_to_edit_id.value = null;
    
    ports_placeholder = i18n('hosts_stats.page_scan_hosts.ports_placeholder');


    selected_scan_type.value = scan_type_list.value[0];
    selected_cidr.value = cidr_options_list.value[1];
}

/**
 * 
 * Set row to edit 
 */
const set_row_to_edit = (row) => {

  if(row != null) {
    title = _i18n('hosts_stats.page_scan_hosts.edit_host_title');
    is_edit_page.value = true;

    disable_add.value = false;

      //set host
    host.value = row.host;
    ports.value = row.ports;

    row_to_edit_id.value = row.id;

    automatic_scan_frequencies_list.value.forEach((item) => {
      if(item.id == row.scan_frequency) {
        selected_automatic_scan_frequency.value = item;
      }
    });
    
    scan_type_list.value.forEach((item) => {
    if (item.id == row.scan_type) {
        selected_scan_type.value = item;
    }
    })

    if (is_enterprise_l) {
      automatic_scan_frequencies_list.value.forEach((item) => {
        if (item.id == row.auto_scan_frequency) {
          selected_automatic_scan_frequency.value = item;
        }
      })
    }

    cidr_options_list.value.forEach((item) => {
      if (item.id == row.cidr) {
        selected_cidr.value = item;
      }
    })
      
      
    
  }
}

const show = (row, _host) => {
  reset_modal_form();
  if(row != null)
    set_row_to_edit(row);
  
  
  if(_host!=null && _host!="") {
    host.value = _host;
    disable_add.value = false;
  }
  
  modal_id.value.show();
};


const check_empty_host = async () => {

  let ipv4_regex = /^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$/gm;   
  let ipv6_regex = /^(?:(?:[a-fA-F\d]{1,4}:){7}(?:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){6}(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){5}(?::(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,2}|:)|(?:[a-fA-F\d]{1,4}:){4}(?:(?::[a-fA-F\d]{1,4}){0,1}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,3}|:)|(?:[a-fA-F\d]{1,4}:){3}(?:(?::[a-fA-F\d]{1,4}){0,2}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,4}|:)|(?:[a-fA-F\d]{1,4}:){2}(?:(?::[a-fA-F\d]{1,4}){0,3}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,5}|:)|(?:[a-fA-F\d]{1,4}:){1}(?:(?::[a-fA-F\d]{1,4}){0,4}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,6}|:)|(?::(?:(?::[a-fA-F\d]{1,4}){0,5}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,7}|:)))(?:%[0-9a-zA-Z]{1,})?$/gm;     

  if (ipv4_regex.test(host.value)) {
    const ip_parts = host.value.split(".");
    const last_part = ip_parts[3];

    if (last_part != "0") {
      selected_cidr.value = cidr_options_list.value[1];
    }
    disable_add.value = false;
  } else if (ipv6_regex.test(host.value)) {
    selected_cidr.value = cidr_options_list.value[2];
    disable_add.value = false;

  } else if (host.value != null && host.value != "") {
    disable_add.value = false;
  }
  
}

const check_ports = () => {
  let comma_separted_port_regex = /^(\d{1,5})(,\s*\d{1,5})*$/;

  if (ports.value != "" && !comma_separted_port_regex.test(ports.value)) {

    disable_add.value = true; 
  } else {
    ports_placeholder = i18n('hosts_stats.page_scan_hosts.ports_placeholder');
    disable_add.value = false;
  }


}

async function resolve_host_name(host) {
  const url = NtopUtils.buildURL(resolve_host_name_url, {
        host: host
      })

  const result = await ntopng_utility.http_request(url);
  return result
}




/**
 * Function to add host to scan
 */
const add_ = async (is_edit) => {
  let tmp_host = host.value;
  let tmp_ports = ports.value;
  const tmp_scan_type = selected_scan_type.value.id;
  
  let emit_name = 'add';

  let tmp_row_id = "";
  if(is_edit == true) {
    emit_name = 'edit';
    tmp_row_id = row_to_edit_id.value;

  } else {
    tmp_row_id = null;
  }


    // FIX validation
  let regex = new RegExp(regexValidation.get_data_pattern('ip'));

  let verify_host_name = false;
  if ((!(regex.test(host.value))) == true) {
    if (host.value != "") {

      verify_host_name = true;
      
    } else {
      disable_add.value = true;
    }
  } else {
    disable_add.value = false;
  }


  if (verify_host_name) {
    let result = await resolve_host_name(host.value);
    disable_add.value = result == "no_success";
    if (!disable_add.value) {
      tmp_host = result;
    }
  }

  if (!(disable_add.value)) {
    
    if(is_enterprise_l) {
      const a_scan_frequency = selected_automatic_scan_frequency.value.id;
      emit(emit_name, { 
        host: tmp_host, 
        scan_type: tmp_scan_type, 
        scan_ports: tmp_ports,
        cidr: selected_cidr.value.id,
        auto_scan_frequency: a_scan_frequency,
        scan_id: tmp_row_id

      });
    } else {
      emit(emit_name, { 
        host: tmp_host, 
        scan_type: tmp_scan_type, 
        scan_ports: tmp_ports,
        cidr: selected_cidr.value.id,
        scan_id: tmp_row_id
      });
    }

    activate_add_spinner.value = true;
    disable_add.value = true;
    
  }

  
};

function _load_ports() {
  if (selected_cidr.value.id != "24") {
    disable_load_ports.value = false;
  } else {
    disable_load_ports.value = true;
  }
}

async function load_ports() {

  if (host.value != "")
    ports_placeholder = "";
  else 
    ports_placeholder = i18n('hosts_stats.page_scan_hosts.ports_placeholder');

  if (ports.value == null || ports.value == "") {
    if (selected_cidr.value.id != "24") {
      disable_load_ports.value = false;

      activate_spinner.value = true;
      const url = NtopUtils.buildURL(server_ports, {
            host: host.value,
            ifid: ifid.value,
            scan_ports_rsp: true,
            clisrv: "server"
          })

      const result = await ntopng_utility.http_request(url);
      if (result != null) {
        ports.value = result.filter((x) => typeof x.key === "number").map((x) => x.key).join(',');
        message_feedback.value = "";
      } else {
        if (selected_cidr.value.id != "24") {
          message_feedback.value = i18n("hosts_stats.page_scan_hosts.unknown_host");
        }
        ports.value = "";
      }
      activate_spinner.value = false;
    } else {
      disable_load_ports.value = true;
      message_feedback.value = "";
    }
  }
}




const edit_ = () => {
  add_(true);
}

const close = () => {
  modal_id.value.close();
};

onBeforeMount(async () => {
  //selected_scan_type.value = {};
});  



const metricsLoaded = async (_scan_type_list, _ifid, _is_enterprise_l ) => {
  scan_type_list.value = _scan_type_list;
  ifid.value = _ifid;
  is_enterprise_l.value = _is_enterprise_l;
  let scan_types = scan_type_list.value;
  scan_types.sort((a,b) => a.label.localeCompare(b.label));
  scan_type_list.value = scan_types;
  selected_scan_type.value = scan_type_list.value[0];
}
    
defineExpose({ show, close, metricsLoaded });
  
</script>
<style scoped>
</style>
    