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
        <div class="col-sm-8">
          <input v-model="host" @input="check_host_regex" :disabled="is_edit_page" class="form-control" type="text"
            :placeholder="host_placeholder" required />
        </div>
        <div class="col-sm-2">
          <SelectSearch v-model:selected_option="selected_cidr" :disabled="is_edit_page || is_ipv4_netscan" :options="cidr_options_list">
          </SelectSearch>
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
          <div class="col-10 mt-4">
            <SelectSearch v-model:selected_option="selected_discovered_scan_type" :options="discovered_scan_type_list">
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
          :disabled="!(is_cidr_correct && is_host_correct && is_port_correct)">
          {{ _i18n("add") }}
        </button>
        <button v-else type="button" @click="edit_" class="btn btn-primary"
          :disabled="!(is_cidr_correct && is_host_correct && is_port_correct)">
          {{ _i18n("apply") }}
        </button>
      </div>
    </template>
  </modal>
</template>

<script setup>
/* Imports */
import { ref } from "vue";
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
const ports_placeholder = i18n("hosts_stats.page_scan_hosts.ports_placeholder");
const note_list = [
  _i18n("hosts_stats.page_scan_hosts.notes.note_1"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_2"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_3"),
];
const enterprise_note_list = [
  _i18n("hosts_stats.page_scan_hosts.notes.note_1"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_2"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_3"),
  _i18n("hosts_stats.page_scan_hosts.notes.note_4"),
];

const modal_id = ref(null);
const selected_scan_type = ref({});
const selected_discovered_scan_type = ref({})
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
const is_cidr_correct = ref(true);
const is_host_correct = ref(false);
const is_ipv4_netscan = ref(false);
const scan_frequencies_list = ref([
  { id: "disabled", label: i18n("hosts_stats.page_scan_hosts.disabled") },
  { id: "1day", label: i18n("hosts_stats.page_scan_hosts.every_night") },
  { id: "1week", label: i18n("hosts_stats.page_scan_hosts.every_week") },
]);
const CIDR_24 = "24";
const CIDR_32 = "32";
const CIDR_128 = "128";
const cidr_options_list = ref([
  { id: "24", label: "/24" },
  { id: "32", label: "/32" },
  { id: "128", label: "/128" },
]);
const selected_cidr = ref(cidr_options_list.value[1]);
const selected_scan_frequency = ref(scan_frequencies_list.value[0]);
const is_data_not_ok = ref(false);

/* ****************************************************** */

/*
 * Reset fields in modal form
 */
const reset_modal_form = function () {
  host.value = "";
  ports.value = "";
  is_port_correct.value = true;
  is_cidr_correct.value = true;
  is_host_correct.value = false;
  activate_add_spinner.value = false;
  show_port_feedback.value = false;
  selected_scan_type.value = scan_type_list.value[0];
  selected_discovered_scan_type.value = discovered_scan_type_list.value[0];
  selected_cidr.value = cidr_options_list.value[1];
  row_to_edit_id.value = null;
  is_edit_page.value = false;
  is_data_not_ok.value = false;
  is_ipv4_netscan.value = false;
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
  if (row.discovered_scan_type != null) {
    selected_discovered_scan_type.value = discovered_scan_type_list.value.find((item) => item.id == row.discovered_scan_type);
  }

  /* CIDR */
  if (selected_scan_type.value.id == 'ipv4_netscan') {
    // ipv4_netscan scan type case
    selected_cidr.value = cidr_options_list.value.find(
      (item) => item.id == CIDR_24
    );
  } else if (regexValidation.validateIPv4(row.host)) {
    selected_cidr.value = cidr_options_list.value.find(
      (item) => item.id == CIDR_32
    ); /* IPv4 */
  } else {
    selected_cidr.value = cidr_options_list.value.find(
      (item) => item.id == CIDR_128
    ); /* IPv6 */
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

/* Function to set is_ipv4_netscan in order to disable cidr selectio
   only /24 (for now)
*/
const set_is_ipv4_netscan = () => {
  if (selected_scan_type.value.id == 'ipv4_netscan') {
    // /24 
    selected_cidr.value = cidr_options_list.value.find(
      (item) => item.id == CIDR_24
    ); 
    

    is_ipv4_netscan.value = true;
  } else {
    is_ipv4_netscan.value = false;
  }
}

/* ****************************************************** */

/* Regex to check if the host is correct or not */
const check_host_regex = () => {
  const is_ipv4 = regexValidation.validateIPv4(host.value);
  const is_ipv6 = regexValidation.validateIPv6(host.value);
  const is_host_name = regexValidation.validateHostName(host.value);
  if (is_ipv4) {
    /* IPv4 */
    is_host_correct.value = true;
    if (!host.value.endsWith(0)) {
      /* In case the CIDR is wrong */
      selected_cidr.value = cidr_options_list.value.find(
        (item) => item.id == CIDR_32
      ); /* IPv4 */
    }
  } else if (is_ipv6) {
    /* IPv6 */
    selected_cidr.value = cidr_options_list.value[2];
    is_host_correct.value = true;
    /* In case the CIDR is wrong */
    selected_cidr.value = cidr_options_list.value.find(
      (item) => item.id == CIDR_128
    ); /* IPv6 */
  } else if (is_host_name) {
    /* Host Name */
    is_host_correct.value = true;
    /* In case the CIDR is wrong */
    selected_cidr.value = cidr_options_list.value.find(
      (item) => item.id == CIDR_32
    );
  } else {
    is_host_correct.value = false;
  }
};

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

  const tmp_second_scan_type = host_scan_type == 'ipv4_netscan' ? selected_discovered_scan_type.value.id : null;
  /* If the resolution was ok or no resolution at all was done emit the event */
  activate_add_spinner.value = new_host_name_resolved;

  if (new_host_name_resolved) {
    /* Emit the event, only if the resolution 
    was ok or no resolution at all was needed */
    emit(emit_event, {
      host: new_host,
      scan_type: host_scan_type,
      scan_ports: host_ports,
      cidr: selected_cidr.value.id,
      scan_frequency: is_enterprise_l ? selected_scan_frequency.value.id : null,
      scan_id: row_id,
      discovered_host_scan_type : tmp_second_scan_type
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
  selected_discovered_scan_type.value = discovered_scan_type_list.value[0];
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
