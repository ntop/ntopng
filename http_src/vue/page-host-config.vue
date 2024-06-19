<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="m-3">
    <h5>{{ _i18n('host_config.host_config') }}</h5>
    <hr>
    <div class="m-4 card card-shadow">
      <div class="card-body">
        <div class="table table-striped table-bordered col-sm-12">
          <tbody class="table_length">
            <tr>
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-8">
                    <b>{{ _i18n('host_config.host_alias') }}</b><br>
                    <small>{{ _i18n('host_config.host_alias_description') }}</small>
                  </div>
                  <div class="col-4 form-group d-flex justify-content-end">
                    <div class="form-check w-75">
                      <input ref="host_alias" class="form-control" :placeholder="_i18n('host_config.custom_name')"
                        value="" @input="update_save_button_state">
                    </div>
                  </div>
                </div>
              </td>
            </tr>

            <tr>
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-8">
                    <b>{{ _i18n('host_notes') }}</b><br>
                    <small>{{ _i18n('host_config.host_notes_description') }}</small>
                  </div>
                  <div class="col-4 form-group d-flex justify-content-end">
                    <div class="form-check w-75">
                      <input ref="host_notes" type="text" class="form-control"
                        :placeholder="_i18n('host_config.custom_notes')" value="" @input="update_save_button_state">
                    </div>
                  </div>
                </div>
              </td>
            </tr>

            <tr>
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-10">
                    <b>{{ host_pool_title }}</b><br>
                    <small>{{ host_pool_description }}</small>
                  </div>
                  <div class="col-2 form-group d-flex justify-content-end" :key="pool_key">
                    <SelectSearch ref="host_pools" @select_option="update_selected_pool"
                      v-model:selected_option="selected_pool" :options="host_pools_list">
                    </SelectSearch>
                  </div>
                </div>
              </td>
            </tr>

            <tr v-if="show_drop_host_traffic">
              <td>
                <div class="d-flex align-items-center">
                  <div class="col-11">
                    <b>{{ _i18n('host_config.drop_all_host_traffic') }}</b><br>
                    <small>{{ _i18n('host_config.drop_all_host_traffic_description') }}</small>
                  </div>
                  <div class="col-1 form-group d-flex justify-content-end">
                    <div class="form-check form-switch">
                      <input ref="toggle_drop_host_traffic" class="form-check-input" type="checkbox" value="0"
                        @click="change_toggle_drop_host_traffic">
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
import { ref, onMounted, onBeforeMount } from "vue";
import { default as SelectSearch } from "./select-search.vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

/* ******************************************************************** */

/* Consts */
const _i18n = (t) => i18n(t);

const get_url = `${http_prefix}/lua/rest/v2/get/host/config.lua`;
const post_url = `${http_prefix}/lua/rest/v2/set/host/config.lua`;
const pool_url = `${http_prefix}/lua/rest/v2/get/pools.lua`

const disable_save = ref(true);
const props = defineProps({
  context: Object,
});

const initial_host_alias = ref(false);
const host_alias = ref(null);

const initial_host_notes = ref(false);
const host_notes = ref(null);

const show_drop_host_traffic = ref(true);
const toggle_drop_host_traffic_changed = ref(false);
const toggle_drop_host_traffic = ref(null);

const host_pools = ref(null);
const selected_pool = ref({});
const initial_selected_pool = ref(0);
const host_pools_list = ref([]);
const host_pool_title = ref(i18n("host_config.host_pool"))
const host_pool_description = ref(i18n("host_config.host_pool_description"))
const pool_key = ref(0)

onMounted(async () => {
  const extra_params = ntopng_url_manager.get_url_object();
  const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const host_config = await ntopng_utility.http_request(`${get_url}?${url_params}`);
  show_drop_host_traffic.value = host_config.has_traffic_policies;
  if (host_config.drop_traffic == '0' ||
    host_config.drop_traffic == '') {
    toggle_drop_host_traffic.value.value = '0';
    toggle_drop_host_traffic.value.removeAttribute('checked');
  } else {
    toggle_drop_host_traffic.value.value = '1';
    toggle_drop_host_traffic.value.setAttribute('checked', 'checked');
  }

  host_alias.value.value = host_config.alias
  initial_host_alias.value = host_config.alias
  host_notes.value.value = host_config.notes
  initial_host_notes.value = host_config.notes
  
  const rsp = await ntopng_utility.http_request(pool_url);
  rsp.forEach((item) => {
    host_pools_list.value.push({
      value: item.pool_id,
      label: item.name
    })
  })
  selected_pool.value = host_pools_list.value.filter((item) => item.value === host_config.host_pool_id)[0]
  initial_selected_pool.value = selected_pool.value.value;
  if(show_drop_host_traffic.value) {
    host_pool_title.value = i18n("nedge.user")
    host_pool_description.value = i18n("host_config.nedge_user_description")
  }
  pool_key.value = 1 /* Trick used to re-render the dropdown */
});

function update_selected_pool(item) {
  update_save_button_state()
}

function update_save_button_state() {
  disable_save.value = (!toggle_drop_host_traffic_changed.value) &&
    (initial_host_alias.value === host_alias.value.value) &&
    (initial_host_notes.value === host_notes.value.value) &&
    (initial_selected_pool.value === selected_pool.value.value);
}

function change_toggle_drop_host_traffic() {
  toggle_drop_host_traffic_changed.value = !toggle_drop_host_traffic_changed.value;
  toggle_drop_host_traffic.value.value == '1' ?
    toggle_drop_host_traffic.value.value = '0' :
    toggle_drop_host_traffic.value.value = '1';
  update_save_button_state()
}

async function reload_page() {
  const extra_params = ntopng_url_manager.get_url_object();
  const params = {
    csrf: props.context.csrf,
    drop_host_traffic: toggle_drop_host_traffic?.value?.value,
    pool: selected_pool.value.value,
    custom_name: host_alias.value.value,
    custom_notes: host_notes.value.value,
    ...extra_params
  };
  const headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(`${post_url}`, { method: 'post', headers, body: JSON.stringify(params) })
  ntopng_url_manager.reload_url();
}
</script>

<style scoped>
.table_length {
  display: table;
  width: 100%;
}
</style>