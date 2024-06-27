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
          <template v-if="discovery_requested">
            <div class="alert alert-info alert-dismissable">
              <span class="spinner-border spinner-border-sm text-info"></span>
              {{ discovery_requested_message }}
              <span v-html="progress_message"></span>
            </div>
          </template>
          <!-- Show message that discovery is not enabled in preferences -->
          <template v-if="!networkDiscoveryPrefEnabled">
            <div class="alert alert-danger alert-dismissable">
              {{ _i18n("network_discovery_disabled") }}
              <button class="btn btn-small" @click="redirectToPreferencesPage">
                <i class="fa-solid fa-gear"></i>
              </button>
            </div>
          </template>
          <div :class="[(discovery_requested || !networkDiscoveryPrefEnabled) ? 'ntopng-gray-out' : '']">
            <TableWithConfig ref="network_discovery_table" :table_id="table_id" :csrf="csrf"
              :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting">
              <template v-slot:custom_header>
                <button v-for="(button, index) in tableButtons" :key="index" :class="button.className"
                  @click="button.action">
                  <span v-html="button.text"></span>
                </button>
              </template> <!-- Dropdown filters -->
            </TableWithConfig>
          </div>

          <NoteList v-bind:note_list="note_list">
          </NoteList>
          <!-- Adding Extra Message -->
          <div class="p-1" v-html="last_network_discovery"></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>

import { ref, onUnmounted, onMounted } from "vue";
import { default as Loading } from "./loading.vue";
import { default as NoteList } from "./note-list.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import osUtils from "../utilities/map/os-utils";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const ifid = props.context.ifid;

const error = ref(false);
const error_message = i18n("map_page.fetch_error");
const discovery_requested = ref(false);
const network_discovery_table = ref(null);
const progress_message = ref(null);
const last_network_discovery = ref('');
const discovery_requested_message = i18n('discover.network_discovery_not_enabled');
const loading = ref(false);
const networkDiscoveryPrefEnabled = ref(false);

const ghost_message = i18n("discover.ghost_icon_descr");
const too_many_devices_message = i18n("discover.too_many_devices_descr");
const ghost_message_added = ref(false);

const timeout_id = ref(null);

const note_list = [
  i18n("discover.discovery_running"),
  i18n("discover.protocols_note")
];

const run_network_discovery = `${http_prefix}/lua/rest/v2/get/network/discovery/run_discovery.lua`;
const discovery_url = `${http_prefix}/lua/get_discover_progress.lua`;

/********** NEW ADDITION **********/

const table_id = ref("network_discovery");
const csrf = props.context.csrf;

const tableButtons = ref([
  {
    text: `${i18n('discover.start_discovery')} <i class="fa-solid fa-play"></i>`,
    className: 'btn btn-link',
    action: async ()  => {
      loading.value = false;

      const url = run_network_discovery + `?ifid=${ifid}`
      await ntopng_utility.http_request(url);

      timeout_id.value = setInterval(checkDiscovery, 1000);
    }
  }
]);

const map_table_def_columns = (columns) => {
  let map_columns = {
    "ip": (value, row) => {
      return `<a href="${http_prefix}/lua/host_details.lua?host=${value}">${value}</a>`;
    },
    "name": (value, row) => {
      return value;
    },
    "manufacturer": (value, row) => {
      return value;
    },
    "mac_address": (value, row) => {
      return value;
    },
    "os": (value, row) => {
      return osUtils.getOS(value)["icon"];
    },
    "info": (value, row) => {
      return value;
    },
    "device_type": (value, row) => {
      return osUtils.getAssetIcon(value);
    }
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
  });

  return columns;
};


/********** **********/

/*  This function add notes to the pages, like adding notes 
 *  to note_list or last network discovery note 
 */
const add_notes = (rsp) => {
  if (rsp.ghost_found == true && ghost_message_added.value == false) {
    note_list.unshift(ghost_message);
    ghost_message_added.value = true;
  }
  if (rsp.too_many_devices_message == true && too_many_devices_message.value == false) {
    note_list.unshift(too_many_devices_message);
    too_many_devices_message.value = true;
  }
  if (rsp.ghost_found == false && ghost_message_added.value == true) {
    note_list.shift();
    ghost_message_added.value = false;
  }
  if (rsp.too_many_devices_message == false && too_many_devices_message.value == true) {
    note_list.shift();
    too_many_devices_message.value = false;
  }

  last_network_discovery.value = rsp.last_network_discovery;
};

/*  This function handle the discovery, asking the backend if  
 *  a new discovery was requested or not and in case updates the notes
 *  and the various messages
 */
const checkDiscovery = async () => {
  loading.value = false;

  // check discovery process percent
  const url = discovery_url + `?ifid=${ifid}`
  const rsp = await ntopng_utility.http_request(url);

  if (rsp.discovery_requested) {
    discovery_requested.value = true;
    progress_message.value = rsp.progress !== "" ? rsp.progress : "";
  } else {
    network_discovery_table.value.refresh_table()
    discovery_requested.value = false;
    progress_message.value = '';
    clearInterval(timeout_id.value);
  }

  add_notes(rsp);
};

// Function to redirect to a url
function redirectToPreferencesPage() {
  const url = `${http_prefix}/lua/admin/prefs.lua`
  ntopng_url_manager.go_to_url(url)
}

// Function to get if network discovery is enabled in preferences
async function checkNetworkDiscoveryEnabled() {
  const url = `${http_prefix}/lua/rest/v2/get/ntopng/get_preferences.lua`
  const rsp = await ntopng_utility.http_request(url);

  networkDiscoveryPrefEnabled.value = rsp.active_monitoring
}

const destroy = () => {
  network_discovery_table.value.destroy_table();
};

onMounted(async () => {
  await checkNetworkDiscoveryEnabled()
})

onUnmounted(async () => {
  destroy();
});

function columns_sorting(col, r0, r1) {
  if (col != null) {
    if (col.id == "name") {
      return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
    } else if (col.id == "ip") {
      return sortingFunctions.sortByIP(r0.ip, r1.ip, col.sort);
    } else if (col.id == "manufacturer") {
      return sortingFunctions.sortByName(r0.manufacturer, r1.manufacturer, col.sort);
    } else if (col.id == "mac_address") {
      return sortingFunctions.sortByMacAddress(r0.mac_address, r1.mac_address, col.sort);
    } else if (col.id == "os") {
      return sortingFunctions.sortByNumber(r0.os, r1.os, col.sort);
    } else if (col.id == "device") {
      debugger
      return sortingFunctions.sortByNumber(r0.device, r1.device, col.sort);
    } 
  }
 
}

</script>
