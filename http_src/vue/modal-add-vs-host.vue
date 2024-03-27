<!-- (C) 2023 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <!-- Target information, here an IP is put -->
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("hosts_stats.page_scan_hosts.host_or_network") }}</b>
        </label>
        <div class="col-sm-4 pe-0">
          <input v-model="host" @input="check_host_regex" :disabled="is_edit_page" class="form-control" type="text"
            :placeholder="host_placeholder" required />
          </div>
            <div class="col-1 ps-5 pe-0 mt-1">
              <span>/</span> 
            </div>
            <div class="col-2 ps-0">
            <input v-model="selected_cidr" @input="check_cidr" :disabled="is_edit_page" class="form-control" type="text"
            :placeholder="cidr_placeholder" required />
          </div>
        </div>                    
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("hosts_stats.page_scan_hosts.ports") }}</b>
        </label>
        <div class="col-sm-10">
          <input v-model="ports" @focusout="check_ports" class="form-control" :class="hide_ports_placeholder === true ? 'ntopng-hide-placeholder' : ''
            " type="text" :placeholder="ports_placeholder" required />
        </div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("hosts_stats.page_scan_hosts.scan_type") }}</b>
        </label>
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_scan_type" :options="scan_type_list" :disabled="is_edit_page" @select_option="set_is_ipv4_netscan()">
          </SelectSearch>
        </div>
      </div>
      <template v-if="selected_scan_type.id == 'ipv4_netscan'">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2">
            <b>{{ _i18n("hosts_stats.page_scan_hosts.host_discovered_scan_type") }}</b>
          </label>
          <div class="col-10" >
            <SelectSearch v-model:selected_options="selected_discovered_scan_types" @change_selected_options="update_selected_discovered_scan_types" @unselect_option="remove_selected_discovered_scan_types" :options="discovered_scan_type_list" :multiple="true">
            </SelectSearch>
          </div>
        </div>
      </template>
      <template v-if="is_enterprise_l == true">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2">
            <b>{{ _i18n("hosts_stats.page_scan_hosts.periodicity") }}</b>
          </label>
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_scan_frequency" :options="scan_frequencies_list">
            </SelectSearch>
          </div>
        </div>
      </template>

      <div class="mt-4">
        <template v-if="is_enterprise_l == false">
          <NoteList :note_list="note_list"> </NoteList>
        </template>
        <template v-else>
          <NoteList :note_list="enterprise_note_list"> </NoteList>
        </template>
      </div>
    </template>

    <template v-slot:footer>
      <div v-if="is_data_not_ok" class="me-auto text-danger d-inline">
        {{ no_host_feedback }}
      </div>
      <div>
        <Spinner :show="activate_add_spinner" size="1rem" class="me-2"></Spinner>
        <button v-if="is_edit_page == false" type="button" @click="add_" class="btn btn-primary"
          :disabled="!(is_cidr_correct && is_host_correct && is_port_correct && is_netscan_ok)">
          {{ _i18n("add") }}
        </button>
        <button v-else type="button" @click="edit_" class="btn btn-primary"
          :disabled="!(is_cidr_correct && is_host_correct && is_port_correct && is_netscan_ok)">
          {{ _i18n("apply") }}
        </button>
      </div>
    </template>
  </modal>
</template>

<script setup>
/* Imports */
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Spinner } from "./spinner.vue";
import { default as dataUtils } from "../utilities/data-utils";
import regexValidation from "../utilities/regex-validation.js";
import NtopUtils from "../utilities/ntop-utils";

/* ****************************************************** */

const _i18n = (t) => i18n(t);
const emit = defineEmits(["add", "edit"]);
const props = defineProps({
  context: Object,
});

/* Consts */
const title = ref(i18n("hosts_stats.page_scan_hosts.add_host"));
const no_host_feedback = ref(i18n("hosts_stats.page_scan_hosts.host_not_resolved"));
const host_placeholder = i18n("hosts_stats.page_scan_hosts.host_placeholder");
const cidr_placeholder = i18n("hosts_stats.page_scan_hosts.cidr_placeholder");
const ports_placeholder = i18n("hosts_stats.page_scan_hosts.ports_placeholder");
const note_list = [
  _i18n("hosts_stats.page_scan_hosts.notes.note_1"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_2"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_3"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_3_1"),
];
const enterprise_note_list = [
  _i18n("hosts_stats.page_scan_hosts.notes.note_1"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_2"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_3"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_3_1"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_4"),
];

const modal_id = ref(null);
const selected_scan_type = ref({});
const selected_discovered_scan_types = ref([]); // array for hosts discovered scan types
const hide_ports_placeholder = ref("");
const row_to_edit_id = ref("");
const activate_add_spinner = ref(false);
const is_edit_page = ref(false);
const scan_type_list = ref([]);
const discovered_scan_type_list = ref([]);
const ifid = ref(null);
const host = ref(null);
const ports = ref(null);
const show_port_feedback = ref(false);
const is_enterprise_l = ref(null);
const is_port_correct = ref(true);
const is_cidr_correct = ref(false);
const is_netscan_ok = ref(true); // bool to be sure that on netscan at least one discovered hosts scan type is selected
const is_host_correct = ref(false);
const is_ipv4_netscan = ref(false);
const scan_frequencies_list = ref([
  { id: "disabled", label: i18n("hosts_stats.page_scan_hosts.disabled") },
  { id: "1day", label: i18n("hosts_stats.page_scan_hosts.every_night") },
  { id: "1week", label: i18n("hosts_stats.page_scan_hosts.every_week") },
]);

const CIDR_24 = 24;
const CIDR_30 = 30;
const CIDR_32 = 32;
const CIDR_128 = 128;

const selected_cidr = ref(null);
const selected_scan_frequency = ref(scan_frequencies_list.value[0]);
const is_data_not_ok = ref(false);
const refresh_select_search = ref(false);
/* ****************************************************** */

/*
 * Reset fields in modal form
 */
const reset_modal_form = function () {
  host.value = "";
  ports.value = "";
  selected_cidr.value = "";
  is_port_correct.value = true;
  is_cidr_correct.value = false;
  is_host_correct.value = false;
  activate_add_spinner.value = false;
  show_port_feedback.value = false;
  selected_scan_type.value = scan_type_list.value[0];
  selected_discovered_scan_types.value = [];
  row_to_edit_id.value = null;
  is_edit_page.value = false;
  is_data_not_ok.value = false;
  is_ipv4_netscan.value = false;
  is_netscan_ok.value = !is_ipv4_netscan.value;
};

/* ****************************************************** */

/*
 * Set row to edit
 */
const set_row_to_edit = (row) => {
  is_edit_page.value = true;

  /* Set host values */
  host.value = row.host;
  ports.value = row.ports;
  is_host_correct.value = true;
  is_port_correct.value = true;
  row_to_edit_id.value = row.id;

  /* Set the correct values if available */
  /* Scan Type */
  selected_scan_type.value = scan_type_list.value.find(
    (item) => item.id == row.scan_type
  );

  /* Sub Scans Types */
  if (row.discovered_host_scan_type != null) {
    const discovered_scan_type_ids_array = row.discovered_host_scan_type.split(",");
    let tmp_selected_scan_types = [];
    let tmp_found_scan_type;
    discovered_scan_type_ids_array.forEach((setted_scan_type) => {
      tmp_found_scan_type = discovered_scan_type_list.value.find((item) => item.id == setted_scan_type);
      tmp_selected_scan_types.push(tmp_found_scan_type);
    })
    selected_discovered_scan_types.value = tmp_selected_scan_types;
  }

  /* CIDR */
  if (selected_scan_type.value.id == 'ipv4_netscan') {
    // ipv4_netscan scan type case
    selected_cidr.value = CIDR_24;
  } else {
    if (check_is_network_address(host.value) || row.cidr == CIDR_128) {
      selected_cidr.value = row.cidr;
    } else {
      selected_cidr.value = CIDR_32;
    }
  }
  is_cidr_correct.value = true;

  /* Scan Frequency */
  if (is_enterprise_l) {
    selected_scan_frequency.value = scan_frequencies_list.value.find(
      (item) => item.id == row.scan_frequency
    );
  }
};

/* ****************************************************** */

/* This method is called whenever the modal is opened */
const show = (row, _host) => {
  /* First of all reset all the data */
  reset_modal_form();
  title.value = i18n("hosts_stats.page_scan_hosts.add_host");
  if (!dataUtils.isEmptyOrNull(row)) {
    /* In case row is not null then an edit is requested */
    title.value = i18n("hosts_stats.page_scan_hosts.edit_host_title");
    set_row_to_edit(row);
  }

  if (!dataUtils.isEmptyOrNull(_host)) {
    host.value = _host;
    is_host_correct.value = true;
  }

  modal_id.value.show();
};

/* ****************************************************** */

/* Function called when a new selected discovered scan type
   is added
*/
const update_selected_discovered_scan_types = (items) => {
  selected_discovered_scan_types.value = items;
  is_netscan_ok.value = selected_discovered_scan_types.value.length > 0;
}

/* Function called when is removed a selected discovered scan type
*/
const remove_selected_discovered_scan_types = (item_to_delete) => {
  selected_discovered_scan_types.value = selected_discovered_scan_types.value.filter((item) => item.id != item_to_delete.id);
  is_netscan_ok.value = selected_discovered_scan_types.value.length > 0; 
}

/* ****************************************************** */

/* Function to set is_ipv4_netscan in order to disable cidr selectio
   only /24 (for now)
*/
const set_is_ipv4_netscan = () => {
  if (selected_scan_type.value.id == 'ipv4_netscan') {
    // /24 
    selected_cidr.value = CIDR_24;
    // is_ipv4_netscan -> enable the discovered_hosts_scan_types multiselection
    is_ipv4_netscan.value = true;
    // is_netscan_ok -> disabled apply or add button because is necessary at least one discovered_hosts_scan_type
    is_netscan_ok.value = false;
  } else {
    // is_ipv4_netscan -> disable the discovered_hosts_scan_types multiselection
    is_ipv4_netscan.value = false;
    // is_netscan_ok -> enable the add or apply button because is not ipv4_netscan case
    is_netscan_ok.value = true;
  }

}

/* ****************************************************** */
const check_is_network_address = (address) => {
  const addr_parts = address.split(".");
  if (addr_parts.length > 3) {
    return addr_parts[3] == 0;
  }
}

/* ****************************************************** */

/* Regex to check if the host is correct or not */
const check_host_regex = () => {
  const is_ipv4 = regexValidation.validateIPv4(host.value);
  const is_ipv6 = regexValidation.validateIPv6(host.value);
  const is_host_name = regexValidation.validateHostName(host.value);
  if (selected_scan_type.value.id == 'ipv4_netscan') {
    
    if (is_ipv4) {
      // the IP must be an IPv4
      /* IPv4 */
      is_host_correct.value = true;
      // the selected_discovered_scan_types must be an array with lenght more than 0
      is_netscan_ok.value = selected_discovered_scan_types.value && selected_discovered_scan_types.value.length > 0;
    }

    is_netscan_ok.value = true; // not ipv4_netscan case so is_netscan_ok is true
  } else {

    /* When it isn't the ipv4_netscan case the cidr selection is enabled */

    if (is_ipv4) {
      /* IPv4 */
      if (!check_is_network_address(host.value)) {
        /* In case the CIDR is wrong */
        selected_cidr.value = CIDR_32;
      } else {
        selected_cidr.value = CIDR_24;
      }
      is_host_correct.value = true;
      is_cidr_correct.value = true;
    } else if (is_ipv6) {
      /* IPv6 */
      is_host_correct.value = true;
      is_cidr_correct.value = true;
      /* In case the CIDR is wrong */
      selected_cidr.value = CIDR_128
      /* IPv6 */

    } else if (is_host_name) {
      /* Host Name */
      is_host_correct.value = true;
      is_cidr_correct.value = true;
      /* In case the CIDR is wrong */
      selected_cidr.value = CIDR_32;
      
    } else {
      is_host_correct.value = false;
    }
  }
};

const check_cidr = () => {
  if (( selected_cidr.value >= CIDR_24 && selected_cidr.value <= CIDR_30) || 
        selected_cidr.value == CIDR_32 || selected_cidr.value == CIDR_128) {
    is_cidr_correct.value = true;
    return true;
  } 
  is_cidr_correct.value = false;
  return false;
}

/* ****************************************************** */

/* Regex to check if ports list is correct or not */
const check_ports = () => {
  if (
    !regexValidation.validatePortRange(ports.value) &&
    !regexValidation.validateCommaSeparatedPortList(ports.value) &&
    !dataUtils.isEmptyOrNull(ports.value)
  ) {
    is_port_correct.value = false;
  } else {
    /* Empty port is alright! */
    is_port_correct.value = true;
  }
};

/* ****************************************************** */

/* Resolve hostname */
async function resolve_host_name(host) {
  const resolve_host_name_url = `${http_prefix}/lua/rest/v2/get/host/resolve_host_name.lua`;
  const url = NtopUtils.buildURL(resolve_host_name_url, {
    host: host,
  });

  return await ntopng_utility.http_request(url);
}

/* ****************************************************** */

/* Function called when the edit button is clicked */
const edit_ = () => {
  add_(true);
};

/* ****************************************************** */

/* Function called when the modal is closed */
const close = () => {
  refresh_select_search.value = false;
  modal_id.value.close();
};

/* ****************************************************** */

/* Function to add host to scan */
const add_ = async (is_edit) => {
  const host_ports = ports.value;
  const host_scan_type = selected_scan_type.value.id;
  const emit_event = (is_edit === true) ? "edit" : "add";
  const row_id = (is_edit === true) ? row_to_edit_id.value : null;
  let new_host = host.value;
  let new_host_name_resolved = true;

  /* Activate the spinner to give the user a feedback */
  activate_add_spinner.value = true;

  /* Check if it's an IP or not, if not it means it's an hostname */
  if (!regexValidation.validateIP(host.value)) {
    /* During the validation disable the add button */
    is_host_correct.value = false;
    new_host = await resolve_host_name(host.value);
    if (new_host === "no_success") {
      /* The resolution failed! */
      new_host_name_resolved = false;
      no_host_feedback.value = host.value + " " + i18n("hosts_stats.page_scan_hosts.host_not_resolved");
      is_data_not_ok.value = true;
      /* Hide the message after 3 seconds */
      setTimeout(() => {
        is_data_not_ok.value = false
      }, 4000)
    }
    /* Validation ended, re-enable the button */
    is_host_correct.value = true;
  }

  let tmp_second_scan_types = [];
  
  selected_discovered_scan_types.value.forEach((item) => {
    tmp_second_scan_types.push(item.id);
  })
  /* The discovered scan types are sent to the rest in comma separated string list */
  const tmp_second_scan_types_formatted = tmp_second_scan_types.join(",");

  /* If the resolution was ok or no resolution at all was done emit the event */
  activate_add_spinner.value = new_host_name_resolved;

  if (new_host_name_resolved) {
    /* Emit the event, only if the resolution 
    was ok or no resolution at all was needed */
    emit(emit_event, {
      host: new_host,
      scan_type: host_scan_type,
      scan_ports: host_ports,
      vs_cidr: selected_cidr.value,
      scan_frequency: is_enterprise_l ? selected_scan_frequency.value.id : null,
      scan_id: row_id,
      discovered_host_scan_type : tmp_second_scan_types_formatted
    });
  }

};

/* ****************************************************** */

/* Load the available metrics */
const metricsLoaded = async (_scan_type_list, _ifid, _is_enterprise_l) => {
  const scan_types = _scan_type_list.sort((a, b) =>
    a.label.localeCompare(b.label)
  );
  ifid.value = _ifid;
  scan_type_list.value = scan_types;
  discovered_scan_type_list.value = scan_types.filter((item) => (item.id != 'ipv4_netscan'));
  is_enterprise_l.value = _is_enterprise_l;
  selected_scan_type.value = scan_type_list.value[0];
};

/* ****************************************************** */
/* ****************************************************** */

/* Function called whenever the CIDR changes,
 * in case of a network the port is not needed
 */
/* 

<div class="form-group ms-2 me-2 mt-3 row">
  <div class="col-2"></div>
  <div class="col-10 d-flex align-items-center">
    <!--
      HIDDEN BUTTON FOR NOW
      <button
      type="button"
      @click="load_ports"
      :disabled="!is_host_correct || disable_load_ports"
      class="btn btn-primary"
    >
      {{ _i18n("hosts_stats.page_scan_hosts.load_ports") }}
    </button>
    -->
    <dd v-if="show_port_feedback" class="ms-2 mb-0 text-danger">
      {{ port_feedback }}
    </dd>
    <a class="ntopng-truncate"></a>
  </div>
</div>

 -- Hidden function for now, it's not needed --

const port_feedback = i18n("hosts_stats.page_scan_hosts.no_ports_detected");
const server_ports = `${http_prefix}/lua/rest/v2/get/host/open_ports.lua`;
const disable_load_ports = ref(false);

function disable_ports() {
  if (selected_cidr.value.id != cidr_24) {
    disable_load_ports.value = false;
  } else {
    disable_load_ports.value = true;
  }
}

async function load_ports() {
  activate_spinner.value = true;
  /* In case the host is not empty, hide the placeholder */
/*  if (dataUtils.isEmptyOrNull(host.value)) {
    hide_ports_placeholder.value = true;
  } else {
    hide_ports_placeholder.value = false;
  }

  /* Request for the available ports */
/*  const url = NtopUtils.buildURL(server_ports, {
    host: host.value,
    ifid: ifid.value,
    clisrv: "server",
  });

  const result = await ntopng_utility.http_request(url);

  /* Show the results or empty if no data was found */
/*  if (!dataUtils.isEmptyOrNull(result)) {
    ports.value = result.map((x) => x.key).join(",");
    show_port_feedback.value = false;
  } else {
    show_port_feedback.value = true;
    ports.value = "";
    /* Remove the message after 5 seconds! */
/*    setTimeout(() => {
      show_port_feedback.value = false;
    }, 5000);
  }
  activate_spinner.value = false;
}
*/


defineExpose({ show, close, metricsLoaded });
</script>
