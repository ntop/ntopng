<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="m-3">
    <h5>{{ _i18n('snmp.snmp_interfaces_auto_role') }}</h5>
    <hr>
    <div class="card card-shadow">
      <div class="card-body">
        <table class="table table-striped table-bordered col-sm-12">
          <tbody class="table_length">

            <!-- Interface Name/Alias Filter -->
            <tr>
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-8">
                    <b>{{ _i18n('snmp.interface_name_alias_filter') }}</b><br>
                    <small>{{ _i18n('snmp.interface_name_alias_filter_description') }}</small>
                  </div>
                  <div class="col-4 form-group d-flex justify-content-end">
                    <div class="form-check w-75">
                      <input class="form-control" type="text"
                        :placeholder="_i18n('snmp.interface_name_alias_filter_placeholder')"
                        v-model="interface_filter_value" @input="update_save_button_state">
                    </div>
                  </div>
                </div>
              </td>
            </tr>

            <!-- Interface Role -->
            <tr>
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-8">
                    <b>{{ _i18n('prefs.snmp_interface_role_title') }}</b><br>
                    <small>{{ _i18n('snmp.interface_auto_assign_role_description') }}</small>
                  </div>
                  <div class="col-4 form-group d-flex justify-content-end">
                    <SelectSearch
                      v-model:selected_option="selected_role"
                      @select_option="update_save_button_state"
                      :options="role_options_list">
                    </SelectSearch>
                  </div>
                </div>
              </td>
            </tr>

          </tbody>
        </table>

        <div class="d-flex justify-content-end me-1">
          <button class="btn btn-primary" :disabled="disable_save" @click="open_confirm_modal">
            {{ _i18n('save_settings') }}
          </button>
        </div>
      </div>
    </div>
  </div>

  <ModalSnmpInterfacesAutoRole ref="modal_save_config" @confirm="exec_save_config" />
</template>

<script setup>
/* Imports */
import { ref, onMounted } from "vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as ModalSnmpInterfacesAutoRole } from "./modal-snmp-interfaces-auto-role.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

/* ******************************************************************** */

const _i18n = (t) => i18n(t);

const get_roles_url  = `${http_prefix}/lua/pro/rest/v2/get/snmp/interface_roles_options.lua`;
const post_bulk_url  = `${http_prefix}/lua/pro/rest/v2/set/snmp/auto_assign_role.lua`;

const props = defineProps({
  context: Object,
});

const disable_save = ref(true);

/* Filter field */
const interface_filter_value = ref("");

/* Role selector */
const role_options_list = ref([]);
const selected_role = ref({});

/* Modal ref */
const modal_save_config = ref(null);


/* ******************************************************************** */

onMounted(() => {
  ntopng_utility.http_request(`${get_roles_url}`)
    .then((roles_rsp) => {
      if (roles_rsp && roles_rsp.length > 0) {
        role_options_list.value = roles_rsp.map((item) => ({ value: item.value, label: item.label }));
        const other = role_options_list.value.find((o) => o.value === "other");
        selected_role.value = other ?? role_options_list.value[role_options_list.value.length - 1];
      }
    })
    .catch((err) => console.error('Error retrieving SNMP interface roles', err));
});

function update_save_button_state() {
  disable_save.value =
    !interface_filter_value.value ||
    interface_filter_value.value.trim() === "" ||
    !selected_role.value?.value;
}

function open_confirm_modal() {
  modal_save_config.value.show();
}

function exec_save_config() {
  const params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    interface_name_filter: interface_filter_value.value.trim(),
    role: selected_role.value?.value ?? "other",
  };
  const headers = { "Content-Type": "application/json" };
  ntopng_utility.http_request(`${post_bulk_url}`, {
    method: "post",
    headers,
    body: JSON.stringify(params),
  })
    .then((data) => {
      if (data == null || data.rc < 0) {
        const err = data?.rc_str_hr || i18n("error");
        modal_save_config.value.show_error(err);
        return;
      }
      modal_save_config.value.show_success(data);
    })
    .catch((err) => {
      console.error('Error saving SNMP interfaces config', err);
      modal_save_config.value.show_error(i18n("error"));
    });
}
</script>

<style scoped>
.table_length {
  display: table;
  width: 100%;
}
</style>
