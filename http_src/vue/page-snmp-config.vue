<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="m-3">
    <h5>{{ _i18n('prefs.snmp_device_config') }}</h5>
    <hr>
    <div class="m-4 card card-shadow">
      <div class="card-body">
        <div class="table table-striped table-bordered col-sm-12">
          <tbody class="table_length">
            <tr>
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-11">
                    <b>{{ _i18n('prefs.toggle_snmp_port_qos_mib_polling_title') }}</b><br>
                    <small>{{ _i18n('prefs.toggle_snmp_port_qos_mib_polling_description') }}</small>
                  </div>
                  <div class="col-1 form-group d-flex justify-content-end">
                    <div class="form-check form-switch">
                      <input ref="toggle_snmp_qos_mib_polling" class="form-check-input" type="checkbox" value="0"
                        @click="change_toggle_snmp_qos_mib_polling">
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </div>
        <div class="d-flex justify-content-end me-1">
          <button class="btn btn-primary" :disabled="disable_save" @click="reload_page">
            {{ _i18n('save_settings') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
/* Imports */
import { ref, onMounted } from "vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

/* ******************************************************************** */

/* Consts */
const _i18n = (t) => i18n(t);

const get_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/device/config.lua`;
const post_url = `${http_prefix}/lua/pro/rest/v2/edit/snmp/device/config.lua`;

const disable_save = ref(true);
const toggle_snmp_qos_mib_polling_changed = ref(false);
const toggle_snmp_qos_mib_polling = ref(null);
const props = defineProps({
  context: Object,
});

onMounted(async () => {
  const extra_params = ntopng_url_manager.get_url_object();
  const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const device_config = await ntopng_utility.http_request(`${get_url}?${url_params}`);
  if (device_config.toggle_snmp_qos_mib_polling == '0' ||
    device_config.toggle_snmp_qos_mib_polling == '') {
    toggle_snmp_qos_mib_polling.value.value = '0';
    toggle_snmp_qos_mib_polling.value.removeAttribute('checked');
  } else {
    toggle_snmp_qos_mib_polling.value.value = '1';
    toggle_snmp_qos_mib_polling.value.setAttribute('checked', 'checked');
  }
});

function change_toggle_snmp_qos_mib_polling() {
  toggle_snmp_qos_mib_polling_changed.value = !toggle_snmp_qos_mib_polling_changed.value;
  toggle_snmp_qos_mib_polling.value.value == '1' ?
    toggle_snmp_qos_mib_polling.value.value = '0' :
    toggle_snmp_qos_mib_polling.value.value = '1';
  update_save_button_state()
}

function update_save_button_state() {
  disable_save.value = !toggle_snmp_qos_mib_polling_changed.value;
}

async function reload_page() {
  const extra_params = ntopng_url_manager.get_url_object();
  const params = {
    csrf: props.context.csrf,
    toggle_snmp_qos_mib_polling: toggle_snmp_qos_mib_polling.value.value,
    ...extra_params
  };
  const headers = {
    'Content-Type': 'application/json'
  };
  ntopng_utility.http_request(`${post_url}`, { method: 'post', headers, body: JSON.stringify(params) })
  ntopng_url_manager.reload_url();
}
</script>

<style scoped>
.table_length {
  display: table;
  width: 100%;
}
</style>