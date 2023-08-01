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
          <div class="col-sm-10" >
            <input v-model="host" @focusout="load_ports"  @input="check_empty_host" class="form-control" type="text" :placeholder="host_placeholder" required>
          </div>
      </div>

      <div  class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.ports")}}</b>
          </label>
            <div class="col-sm-10" >
            <input v-model="ports" class="form-control" type="text" :placeholder="ports_placeholder" required>
            </div>
            

      </div>
      <div  class="form-group ms-2 me-2 mt-3 row">

      <div class="col-sm-9"></div>
      <div class="col-sm-3">

        <button type="button"  :disabled="disable_add" class="btn btn-primary" >{{_i18n('hosts_stats.page_scan_hosts.load_ports')}}</button>
        <Spinner :show="disable_add" size="1rem" class="ms-1"></Spinner>
            <a class="ntopng-truncate" :title="disable_add"></a>

        </div>
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

      <div class="mt-4">
        <NoteList
        :note_list="note_list">
        </NoteList>
      </div>
    </template>

      

      <template v-slot:footer>

      <template v-if="is_edit_page == false">
      <button type="button" @click="add_" class="btn btn-primary"  :disabled="disable_add">{{_i18n('add')}}</button>
      </template>
      <template v-else>
      <button type="button" @click="edit_" class="btn btn-primary"  :disabled="disable_add ">{{_i18n('apply')}}</button>
      </template>
    </template>

  </modal>
  </template>
  
<script setup>
/* Imports */
import { ref, onBeforeMount } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Spinner } from "./spinner.vue";

import regexValidation from "../utilities/regex-validation.js";
import NtopUtils from "../utilities/ntop-utils";
/* ****************************************************** */

/* Consts */
const modal_id = ref(null);
const selected_scan_type = ref(null);
const emit = defineEmits(['add','edit']);
let title = i18n('hosts_stats.page_scan_hosts.add_host');
const host_placeholder = i18n('hosts_stats.page_scan_hosts.host_placeholder');
const ports_placeholder = i18n('hosts_stats.page_scan_hosts.ports_placeholder');

const resolve_host_name_url = `${http_prefix}/lua/rest/v2/get/host/resolve_host_name.lua`;
const server_ports = `${http_prefix}/lua/iface_ports_list.lua`; // ?clisrv=server&ifid=2&host=192.168.2.39
const nmap_server_ports = `${http_prefix}/lua/rest/v2/get/host/ports_by_nmap.lua`;

const _i18n = (t) => i18n(t);
const disable_add = ref(false);
const is_edit_page = ref(false);
const note_list = [
  _i18n('hosts_stats.page_scan_hosts.notes.note_1'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_2'),
  _i18n('hosts_stats.page_scan_hosts.notes.note_3')

];
const scan_type_list = ref([]);
const ifid = ref(null);
const host = ref(null);
const ports = ref(null);
const showed = () => {};
const props = defineProps({
  context: Object,
});
/* ****************************************************** */

/**
 * 
 * Reset fields in modal form 
 */
const reset_modal_form = function() {
    host.value = "";
    ports.value = "";
    selected_scan_type.value = scan_type_list.value[0];
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
    
    scan_type_list.value.forEach((item) => {
    if (item.id == row.scan_type) {
        selected_scan_type.value = item;
    }
    })
      
      
    
  }
}

const show = (row) => {
  reset_modal_form();
  if(row != null)
    set_row_to_edit(row);
  
  modal_id.value.show();
};


const check_empty_host = async () => {
   
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

  if(is_edit == true) 
    emit_name = 'edit';


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
    console.log(result);
    disable_add.value = result == "no_success";
  }

  if (!(disable_add.value)) {
    emit(emit_name, { 
      host: tmp_host, 
      scan_type: tmp_scan_type, 
      scan_ports: tmp_ports,
    });
    
    close();
  }

  
};

async function load_ports() {
  disable_add.value = true;
  const url = NtopUtils.buildURL(server_ports, {
        host: host.value,
        ifid: ifid.value,
        scan_ports_rsp: true,
        clisrv: "server"
      })

  const result = await ntopng_utility.http_request(url);
  if (result != null) {
    ports.value = result.filter((x) => typeof x.key === "number").map((x) => x.key).join(',');
  } else {
    ports.value = "";
  }
  disable_add.value = false;
}

async function load_nmap_ports() {
  disable_add.value = true;
  const url = NtopUtils.buildURL(nmap_server_ports, {
    host: host.value
  })

  const result = await ntopng_utility.http_request(url);
  if (result != null) {
    ports.value = result.map((x) => x.key).join(',');
  } else {
    ports.value = "";
  }
  disable_add.value = false;

}


const edit_ = () => {
  add_(true);
}

const close = () => {
  modal_id.value.close();
};

onBeforeMount(async () => {
  selected_scan_type.value = {}
});  

const metricsLoaded = async (_scan_type_list, _ifid ) => {
  scan_type_list.value = _scan_type_list;
  ifid.value = _ifid;

  let scan_types = scan_type_list.value;
  scan_types.sort((a,b) => a.label.localeCompare(b.label));
  scan_type_list.value = scan_types;
  selected_scan_type.value = scan_type_list.value[0];
}
    
defineExpose({ show, close, metricsLoaded });
  
</script>
<style scoped>
</style>
    