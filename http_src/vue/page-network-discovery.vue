<!--
  (C) 2013-23 - ntop.org
-->

<template>    
  <div class="row">
    <div class="col-12">
      <div class="card card-shadow">
        <Loading v-if="loading"></Loading>
        <div class="card-body">
          <template v-if="error">
            <div class="alert alert-danger" role="alert" id='error-alert'>
              {{ error_message }}
            </div>
          </template>
          <template v-if="!discovery_requested">
            <Datatable ref="network_discovery_table"
              :table_buttons="config_network_discovery.table_buttons"
              :columns_config="config_network_discovery.columns_config"
              :data_url="config_network_discovery.data_url"
              :enable_search="config_network_discovery.enable_search"
              :table_config="config_network_discovery.table_config">
            </Datatable>
          </template>
          <template v-else>
            <div class="alert alert-info alert-dismissable">
              <span class="spinner-border spinner-border-sm text-info"></span>
                {{ discovery_requested_message }}
              <span v-html="progress_message"></span>
            </div>
          </template>
          <NoteList
            v-bind:note_list="note_list">
          </NoteList>
          <!-- Adding Extra Message -->
          <div class="p-1" v-html="last_network_discovery"></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onBeforeMount, onUnmounted, onMounted } from "vue";
import { default as Datatable } from "./datatable.vue";
import { default as Loading } from "./loading.vue";
import { default as NoteList } from "./note-list.vue";

const error = ref(false);
const error_message = i18n("map_page.fetch_error");
const discovery_requested = ref(false);
const network_discovery_table = ref(null);
const config_network_discovery = ref({});
const progress_message = ref(null);
const last_network_discovery = ref('')
const discovery_requested_message = i18n('discover.network_discovery_not_enabled')
const loading = ref(false);
const props = defineProps({
  ifid: String,
})

const ghost_message = i18n("discover.ghost_icon_descr");
const too_many_devices_message = i18n("discover.too_many_devices_descr");
const ghost_message_added = ref(false);

let timeout_id;

const note_list = [
  i18n("discover.discovery_running"),
  i18n("discover.protocols_note")
]

const discovery_url = `${http_prefix}/lua/get_discover_progress.lua`
const network_discovery_data = `${http_prefix}/lua/rest/v2/get/network/discovery/discover.lua`
const run_network_discovery = `${http_prefix}/lua/rest/v2/get/network/discovery/run_discovery.lua`

/*  This function add notes to the pages, like adding notes 
 *  to note_list or last network discovery note 
 */
const add_notes = (rsp) => {
  if(rsp.ghost_found == true
      && ghost_message_added.value == false) {
    note_list.unshift(ghost_message);
    ghost_message_added.value = true;
  }
  if(rsp.too_many_devices_message == true
      && too_many_devices_message.value == false) {
    note_list.unshift(too_many_devices_message);
    too_many_devices_message.value = true
  }
  if(rsp.ghost_found == false
      && ghost_message_added.value == false) {
    note_list.shift();
    ghost_message_added.value = false;
  }
  if(rsp.too_many_devices_message == false
      && too_many_devices_message.value == true) {
    note_list.shift();
    too_many_devices_message.value = false
  }

  last_network_discovery.value = rsp.last_network_discovery;
}

/*  This function handle the discovery, asking the backend if  
 *  a new discovery was requested or not and in case updates the notes
 *  and the various messages
 */
const checkDiscovery = async function() {
  loading.value = false;
  await $.get(NtopUtils.buildURL(discovery_url, { ifid: props.ifid }), function(rsp, status){
    if(rsp.rsp.discovery_requested == true) {
      discovery_requested.value = true;
      if(rsp.rsp.progress != "") {
        progress_message.value = rsp.rsp.progress;
      }
    } else {
      discovery_requested.value = false;
      progress_message.value = '';
      clearInterval(timeout_id);
    }
    add_notes(rsp.rsp);
  });
}

const destroy = () => {
  network_discovery_table.value.destroy_table();
}

const reload_table = () => {
  network_discovery_table.value.reload();
}

onMounted(() => {
  timeout_id = setInterval(checkDiscovery, 3000);
}),
    
onBeforeMount(async () => {
  start_datatable();
});

onUnmounted(async () => {
  destroy()
});

/*  Initialize the datatable, adding the action buttons (next to the search),
 *  the various columns, names and data and the configuration of the datatable
 */
function start_datatable() {
  const datatableButton = [{
      text: '<i class="fas fa-sync"></i>',
      className: 'btn-link',
      action: function () {
        reload_table();
      }
    }, {
      text: i18n("discover.start_discovery") + ' <i class="fa-solid fa-play"></i>',
      action: function() {
        loading.value = false;
        $.get(NtopUtils.buildURL(run_network_discovery, { ifid: props.ifid }), function(_) {})
        /* Set the descovery requested to true */
        timeout_id = setInterval(checkDiscovery, 1000);
      }
    }
  ];
    
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: NtopUtils.buildURL(network_discovery_data, { ifid: props.ifid }),
    enable_search: true,
    table_config: { 
      serverSide: false, 
      order: [[ 0 /* application column */, 'asc' ]],
    }
  };
  
  /* Applications table configuration */  

  let columns = [
    { columnName: i18n("ip_address"), name: 'ip', data: 'ip', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("name"), name: 'name', data: 'name', className: 'text-nowrap text-center', responsivePriority: 1 },
    { columnName: i18n("mac_stats.manufacturer"), name: 'manufacturer', data: 'manufacturer', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("mac_address"), name: 'mac_address', data: 'mac_address', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("os"), name: 'os', data: 'os', className: 'text-nowrap text-center', responsivePriority: 2 },
    { columnName: i18n("info"), name: 'info', data: 'info', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("device"), name: 'device', data: 'device', className: 'text-nowrap', responsivePriority: 2 },
  ];

  let trafficConfig = ntopng_utility.clone(defaultDatatableConfig);
  trafficConfig.columns_config = columns;
  config_network_discovery.value = trafficConfig;
}
</script>

