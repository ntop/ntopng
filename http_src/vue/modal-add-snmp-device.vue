<!-- (C) 2023 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <form>
      <!-- Host -->
      <template v-if="!is_edit_page">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4">
            <b>{{ _i18n("snmp.snmp_host") }}</b>
          </label>
          <div class="col-sm-5 pe-0">
            <input v-model="snmp_host"  @input="check_host_regex" class="form-control" :class="{'invalid': !is_host_correct}" type="text"
              :placeholder="host_placeholder" required />
            <small class="text-muted">{{ _i18n("snmp.descriptions.host") }}</small>
            </div>
            <div class="col-1 ps-5 pe-0 mt-1">
              <span>/</span> 
            </div>
            <div class="col-2 ps-0">
              <input v-model="selected_cidr" @input="check_cidr" class="form-control" type="text"
              :placeholder="cidr_placeholder" required />
          </div>
        </div>
      </template>

      <!-- SNMP Version -->
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4">
          <b>{{ _i18n("snmp.snmp_version") }}</b>
        </label>
        <div class="col-sm-5">
          <SelectSearch v-model:selected_option="selected_version" :options="snmp_versions" @select_option="update_v3_fields">
          </SelectSearch>
          <small class="text-muted">{{ _i18n("snmp.descriptions.version") }}</small>
        </div>
      </div>

      <!-- SNMP Read Community -->
      <div v-if="enable_v3_options == false" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4">
          <b>{{ _i18n("snmp.snmp_read_community") }}</b>
        </label>
        <div class="col-sm-5">
          <input v-model="snmp_read_community"  class="form-control" type="text" :class="{'invalid': !is_community_correct}"
            :placeholder="community_place_holder" @input="check_community" required />
            <small class="text-muted">{{ _i18n("snmp.descriptions.read_community") }}</small>
        </div>
      </div>
      
      <!-- SNMP Write Community -->
      <div v-if="props.context.snmp_set_available && enable_v3_options == false" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4">
          {{ _i18n("snmp.snmp_write_community") }}
        </label>
        <div class="col-sm-5" >
          <input v-model="snmp_write_community"  class="form-control" type="text"/>
            <small class="text-muted">{{ _i18n("snmp.descriptions.write_community") }}</small>
        </div>
      </div>
      
      <!-- SNMP Level -->
      <template v-if="enable_v3_options">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4">
            <b>{{ _i18n("snmp.snmp_level") }}</b>
          </label>
          <div class="col-sm-5">
            <SelectSearch v-model:selected_option="selected_snmp_level" :options="snmp_levels" @select_option="update_levels">
            </SelectSearch>
            <small class="text-muted">{{ _i18n("snmp.descriptions.level") }}</small>
          </div>
        </div>

        <!-- SNMP Username -->
        <template v-if="with_auth">
          <div class="form-group ms-2 me-2 mt-3 row">
            <label class="col-form-label col-sm-4">
              <b>{{ _i18n("snmp.snmp_username") }}</b>
            </label>
            <div class="col-sm-5">
              <input v-model="snmp_username"  class="form-control" type="text" autocomplete="current-username" @input="check_username" required :class="{'invalid': !is_username_valid}"/>
                <small class="text-muted">{{ _i18n("snmp.descriptions.username") }}</small>
            </div>
          </div>
          
          <!-- SNMP Auth Protocol -->
          <div class="form-group ms-2 me-2 mt-3 row">
            <label class="col-form-label col-sm-4">
              <b>{{ _i18n("snmp.authentication_protocol") }}</b>
            </label>
            <div class="col-sm-5">
              <SelectSearch v-model:selected_option="selected_auth_protocol" :options="snmp_auth_protocols">
              </SelectSearch>
              <small class="text-muted">{{ _i18n("snmp.descriptions.authentication_protocol") }}</small>
            </div>
          </div>

          <!-- SNMP Auth PassaPhrase -->
          <div class="form-group ms-2 me-2 mt-3 row">
            <label class="col-form-label col-sm-4">
              <b>{{ _i18n("snmp.authentication_passphrase") }}</b>
            </label>
            <div class="col-sm-5">
              <input v-model="snmp_auth_passphrase"  class="form-control"  type = "password" autocomplete="current-password" required @input="check_snmp_auth_passphrase" :class="{'invalid': !is_snmp_auth_passphrase_valid}" />
                <small class="text-muted">{{ _i18n("snmp.descriptions.authentication_passphrase") }}</small>
            </div>
          </div>
        </template>

        <!-- SNMP Privacy Protocol -->
        
        <template v-if="with_privacy">
          <div class="form-group ms-2 me-2 mt-3 row">
            <label class="col-form-label col-sm-4">
              <b>{{ _i18n("snmp.privacy_protocol") }}</b>
            </label>
            <div class="col-sm-5">
              <SelectSearch v-model:selected_option="selected_privacy_protocol" :options="snmp_privacy_protocols">
              </SelectSearch>
              <small class="text-muted">{{ _i18n("snmp.descriptions.privacy_protocol") }}</small>
            </div>
          </div>

          <!-- SNMP Privacy PassaPhrase -->
          <div class="form-group ms-2 me-2 mt-3 row">
            <label class="col-form-label col-sm-4">
              <b>{{ _i18n("snmp.privacy_passphrase") }}</b>
            </label>
            <div class="col-sm-5">
              <input v-model="snmp_privacy_passphrase"  class="form-control" autocomplete="current-password" type = "password" required @input="check_snmp_privacy_passphrase" :class="{'invalid': !is_snmp_privacy_passphrase_valid}" />
              <small class="text-muted">{{ _i18n("snmp.descriptions.privacy_passphrase") }}</small>
            </div>
          </div>
        </template>
      </template>
    </form>
    </template>

    <template v-slot:footer>
      <div v-if="is_data_not_ok" class="me-auto text-danger d-inline">
        {{ no_host_feedback }}
      </div>
      <div>
        <Spinner :show="activate_add_spinner" size="1rem" class="me-2"></Spinner>
        <button v-if="is_edit_page == false" type="button" @click="add_" class="btn btn-primary"
        :disabled="!(is_cidr_correct && is_host_correct && is_username_valid && is_snmp_auth_passphrase_valid && is_snmp_privacy_passphrase_valid && is_community_correct)">
          {{ _i18n("add") }}
        </button>
        <button v-else type="button" @click="edit_" class="btn btn-primary"
          :disabled="!( is_cidr_correct && is_host_correct && is_username_valid && is_snmp_auth_passphrase_valid && is_snmp_privacy_passphrase_valid && is_community_correct)">
          {{ _i18n("apply") }}
        </button>
      </div>
    </template>
  </modal>
</template>

<script setup>
/* Imports */
import { ref,  } from "vue";
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
const title = ref(_i18n("snmp.add_snmp_devices"));
const host_placeholder = ref(_i18n("snmp.device_example").replace("%{example}", "192.168.1.2"));
const community_place_holder = ref(_i18n("snmp.device_example").replace("%{example}", "public"));
const cidr_placeholder = i18n("hosts_stats.page_scan_hosts.cidr_placeholder");

const modal_id = ref(null);
const row_to_edit_id = ref("");
const activate_add_spinner = ref(false);
const is_edit_page = ref(false);
const ifid = ref(null);
const snmp_host = ref(null);
const snmp_read_community = ref(null);
const snmp_write_community = ref(null);
const is_enterprise_l = ref(null);
const is_cidr_correct = ref(false);
const is_host_correct = ref(false);
const is_community_correct = ref(false);
const is_snmp_auth_passphrase_valid = ref(true);
const is_snmp_privacy_passphrase_valid = ref(true);
const is_username_valid = ref(true);
const no_host_feedback = ref("");
const with_privacy = ref(false);
const with_auth = ref(false);
const enable_v3_options = ref(false);

const selected_version = ref(null);
const snmp_versions = props.context.snmp_v3_available ? 
      ref([
        { id: "0", label: "v1" },
        { id: "1", label: "v2c" },
        { id: "2", label: "v3"},
      ]) : 
      ref([
        { id: "0", label: "v1" },
        { id: "1", label: "v2c" }]);

const selected_snmp_level = ref(null);
const snmp_levels = ref([
  { id: "authNoPriv", label: _i18n("snmp.snmp_authnopriv") }, 
  { id: "authPriv", label: _i18n("snmp.snmp_authpriv") }, 
  { id: "noAuthNoPriv", label: _i18n("snmp.snmp_noauthnopriv")}
]);

const selected_auth_protocol = ref(null);
const snmp_auth_protocols = ref([
  { id: "md5", label: "MD5" },
  { id: "sha", label: "SHA" },
]);

const snmp_privacy_protocols = ref([
  { id: "des", label: "DES" },
  { id: "aes", label: "AES" },
  { id: "aes128", label: "AES128" },  
]);
const selected_privacy_protocol = ref(null);

const snmp_username = ref(null);
const snmp_auth_passphrase = ref(null);
const snmp_privacy_passphrase = ref("");

const CIDR_24 = 24;
const CIDR_32 = 32;
const CIDR_128 = 128;

const selected_cidr = ref(null);
const is_data_not_ok = ref(false);
const refresh_select_search = ref(false);
/* ****************************************************** */

/*
 * Reset fields in modal form
 */
const reset_modal_form = function () {
  snmp_host.value = "";
  selected_cidr.value = "";
  snmp_read_community.value = "";
  snmp_write_community.value = "";
  no_host_feedback.value = "";
  snmp_auth_passphrase.value = "";
  snmp_username.value = "";
  selected_snmp_level.value = snmp_levels.value[2];
  selected_auth_protocol.value = snmp_auth_protocols.value[0];
  selected_privacy_protocol.value = snmp_privacy_protocols.value[0];
  snmp_privacy_passphrase.value = "";
  is_cidr_correct.value = false;
  is_host_correct.value = false;
  is_community_correct.value = false;
  activate_add_spinner.value = false;
  row_to_edit_id.value = null;
  is_edit_page.value = false;
  is_data_not_ok.value = false;
  selected_version.value = snmp_versions.value[0];
  enable_v3_options.value = false;
  is_snmp_auth_passphrase_valid.value = true;
  is_snmp_privacy_passphrase_valid.value = true;
  is_username_valid.value = true;
};

/* ****************************************************** */

/*
 * Set row to edit
 */
const set_row_to_edit = (row) => {
  is_edit_page.value = true;

  /* Set host values */
  snmp_host.value = row.ip;
  selected_cidr.value = row.cidr;

  is_host_correct.value = true;
  is_cidr_correct.value = true;
  is_community_correct.value = true;

  is_username_valid.value = true;

  selected_version.value = snmp_versions.value.find((item) => item.label == row.column_version);
  if (selected_version.value.id != '2') {
    snmp_read_community.value = row.column_community;
    snmp_write_community.value = row.column_write_community;
  } else {
    enable_v3_options.value = true;
    snmp_auth_passphrase.value = row.column_auth_passphrase;
    selected_auth_protocol.value = snmp_auth_protocols.value.find((item) => item.id == row.column_auth_protocol);
    selected_snmp_level.value = snmp_levels.value.find((item) => item.id == row.column_level);
    selected_privacy_protocol.value = snmp_privacy_protocols.value.find((item) => item.id == row.column_privacy_protocol);
    snmp_privacy_passphrase.value = row.column_privacy_passphrase;
    snmp_username.value = row.column_username;
    switch(selected_snmp_level.value.id) {
      case "authNoPriv" : {
        with_privacy.value = false;
        with_auth.value = true;   
      }break;
      case "authPriv" :{
        with_privacy.value = true;
        with_auth.value = true;
      }break;
      case "noAuthNoPriv" : {
        with_privacy.value = false;
        with_auth.value = false;
      }
    }
  }

};

/* ****************************************************** */

/* This method is called whenever the modal is opened */
const show = (row, _host) => {
  /* First of all reset all the data */
  reset_modal_form();
  title.value = i18n("snmp.add_snmp_devices");
  if (!dataUtils.isEmptyOrNull(row)) {
    /* In case row is not null then an edit is requested */
    const device_name = row.column_name != null && row.column_name != "" ? row.column_name : row.ip;
    title.value = `${_i18n("snmp.edit_snmp_devices")}: ${device_name}`;
    set_row_to_edit(row);
  }

  modal_id.value.show();
};

const update_levels = () =>  {

  is_community_correct.value = true;
  switch (selected_snmp_level.value.id) {
    case "authNoPriv" : {
      with_privacy.value = false;
      with_auth.value = true;    
      is_snmp_auth_passphrase_valid.value = false;
      is_snmp_privacy_passphrase_valid.value = true;

      is_username_valid.value = false;
      snmp_auth_passphrase.value = "";
      snmp_privacy_passphrase.value = "";
    }break;
    case "authPriv" : {
      with_privacy.value = true;
      with_auth.value = true;
      is_snmp_auth_passphrase_valid.value = false;
      is_snmp_privacy_passphrase_valid.value = false;

      is_username_valid.value = false;
      snmp_auth_passphrase.value = "";
      snmp_privacy_passphrase.value = "";
    }break;
    case "noAuthNoPriv" : {
      with_privacy.value = false;
      with_auth.value = false;
      is_snmp_auth_passphrase_valid.value = true;
      is_snmp_privacy_passphrase_valid.value = true;
      is_username_valid.value = true;
      snmp_auth_passphrase.value = "";
      snmp_privacy_passphrase.value = "";
    }break;
  } 
}

const update_v3_fields = () => {

  if (selected_version.value.id == "2" && props.context.snmp_v3_available) {
    enable_v3_options.value = true;
    is_community_correct.value = true;
  } else {
    enable_v3_options.value = false;
  }
}

/* ****************************************************** */

/* Regex to check if the host is correct or not */
const check_host_regex = () => {
  const is_ipv4 = regexValidation.validateIPv4(snmp_host.value);
  const is_ipv6 = regexValidation.validateIPv6(snmp_host.value);
  const is_host_name = regexValidation.validateHostName(snmp_host.value);
    
  /* When it isn't the ipv4_netscan case the cidr selection is enabled */

  if (is_ipv4) {
    /* IPv4 */
    is_host_correct.value = true;
    selected_cidr.value = CIDR_32;
    is_cidr_correct.value = true;
  } else if (is_ipv6) {
    /* IPv6 */
    is_host_correct.value = true;
    selected_cidr.value = CIDR_128;
    is_cidr_correct.value = true;
  } else if (is_host_name) {
    /* Host Name */
    is_host_correct.value = true;
  
  } else {
    is_host_correct.value = false;
  }
  
};

const check_community = () => {
  if(snmp_read_community.value) {
    is_community_correct.value = true;
  } else {
    is_community_correct.value = false;
  }

}
const check_cidr = () => {
  if ( selected_cidr.value == CIDR_24 || selected_cidr.value == CIDR_32 || selected_cidr.value == CIDR_128 ) {
    is_cidr_correct.value = true;
    return true;
  } 
  is_cidr_correct.value = false;
  return false;
}

const check_username = () => {
  if (snmp_username.value != null && snmp_username.value != "") {
    is_username_valid.value = true;
  } else {
    is_username_valid.value = false;
  }
}

const check_snmp_auth_passphrase = () => {
  if (snmp_auth_passphrase.value != null && snmp_auth_passphrase.value.length > 8) {
    is_snmp_auth_passphrase_valid.value = true;
  } else {
    is_snmp_auth_passphrase_valid.value = false;
  }
}

const check_snmp_privacy_passphrase = () => {
  if (snmp_privacy_passphrase.value != null && snmp_privacy_passphrase.value.length > 8) {
    is_snmp_privacy_passphrase_valid.value = true;
  } else {
    is_snmp_privacy_passphrase_valid.value = false;
  }
}

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
  const emit_event = (is_edit === true) ? "edit" : "add";

  /* Activate the spinner to give the user a feedback */
  activate_add_spinner.value = true;

  /* Check if it's an IP or not, if not it means it's an hostname */
  let new_host_name_resolved = true;
  let new_host = snmp_host.value;
  if (!regexValidation.validateIP(snmp_host.value)) {
    /* During the validation disable the add button */
    is_host_correct.value = false;
    new_host = await resolve_host_name(snmp_host.value);
    if (new_host === "no_success") {
      /* The resolution failed! */
      new_host_name_resolved = false;
      no_host_feedback.value = snmp_host.value + " " + i18n("hosts_stats.page_scan_hosts.host_not_resolved");
      is_data_not_ok.value = true;
      /* Hide the message after 3 seconds */
      setTimeout(() => {
        is_data_not_ok.value = false
      }, 4000)
    }
    /* Validation ended, re-enable the button */
    is_host_correct.value = true;
  }

  /* If the resolution was ok or no resolution at all was done emit the event */
  activate_add_spinner.value = new_host_name_resolved;

  if (new_host_name_resolved) {
    /* Emit the event, only if the resolution 
    was ok or no resolution at all was needed */
    let snmp_entry = {
      snmp_host: new_host,
      cidr: selected_cidr.value,
      snmp_version: selected_version.value.id,
      snmp_read_community: snmp_read_community.value,
      snmp_write_community: snmp_write_community.value

    }

    if (selected_version.value.id == '2') {
      let tmp_selected_auth_protocol = selected_auth_protocol.value != null ? selected_auth_protocol.value.id : snmp_auth_protocols.value[0].id;
      let tmp_selected_snmp_level = selected_snmp_level.value != null ? selected_snmp_level.value.id : snmp_levels.value[0].id;
      let tmp_selected_privacy_protocol = selected_privacy_protocol.value != null ? selected_privacy_protocol.value.id : snmp_privacy_protocols.value[0].id;
      
      snmp_entry = {
        ...snmp_entry,...{
          snmp_auth_passphrase: snmp_auth_passphrase.value,
          snmp_auth_protocol: tmp_selected_auth_protocol,
          snmp_level: tmp_selected_snmp_level,
          snmp_privacy_protocol: tmp_selected_privacy_protocol,
          snmp_privacy_passphrase: snmp_privacy_passphrase.value,
          snmp_username: snmp_username.value,
          snmp_write_community: snmp_write_community.value
        }
      }
    }
    is_data_not_ok.value = false;
    emit(emit_event, 
      snmp_entry
    );
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

const show_bad_feedback = (feedback_msg) => {
  is_data_not_ok.value = true;
  no_host_feedback.value = feedback_msg;
  activate_add_spinner.value = false;
}

defineExpose({ show, close, metricsLoaded, show_bad_feedback });
</script>
