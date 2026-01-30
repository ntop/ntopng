<!-- (C) 2022-26 - ntop.org     -->
<template>
  <div class="m-3">
    <h5>{{ _i18n('modify_flowdev_settings') }}</h5>
    <hr>
    <div class="m-4 card card-shadow">
      <div class="card-body">
        <div class="table-responsive">
          <table class="table table-striped table-bordered">
            <tbody class="table_length">
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_alias') }}</b><br>
                    </div>
                    <div class="col-4">
                      <input type="text" ref="custom_name" class="form-control border" @input="checkDisabled">
                    </div>
                  </div>
                </td>
              </tr>
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_exporter_site') }}</b><br>
                    </div>
                    <div class="col-4">
                        <SelectSearch
                          v-model:selected_option="currentSelectedOption"
                          :options="exporterSitesOptions"
                          :disabled="false"
                          @select_option="onSelectExporterSite"
                        />
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="d-flex justify-content-end me-1">
          <button class="btn btn-primary" :class="[disabled ? 'disabled' : '']" @click="updateFlowDevAlias" id="save">
            {{ _i18n("save_settings") }} </button>

        </div>
      </div>
    </div>
  </div>

</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as SelectSearch } from "./select-search.vue";

const _i18n = (t) => i18n(t);
const custom_name = ref(null);
const prev_name = ref('');
const disabled = ref(true);
const props = defineProps({
  context: Object
});

const exporterSites = ref([]);
const prevExporterSite = ref('');

const exporterSitesOptions  = ref([]);
const currentSelectedOption = ref({
  value: '',
  label: '' 
});


const get_flowdev_alias_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/alias.lua?flowdev_ip=${get_ip_from_url()}&ifid=${props.context.ifid}`
const update_flowdev_alias_url = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/alias.lua`
const get_exporter_sites_url = `${http_prefix}/lua/pro/rest/v2/get/exporter_site/exporter_sites_list.lua`
const update_flowdev_exporter_site_url = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/exporter_site.lua`
const get_flowdev_exporter_site_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/exporter_site.lua?flowdev_ip=${get_ip_from_url()}&ifid=${props.context.ifid}`


onMounted(async () => {
  getFlowDevAlias();
  getExporterSites();
});

function get_ip_from_url() {
  return ntopng_url_manager.get_url_entry('ip')
}

async function getFlowDevAlias() {
  const rsp = await ntopng_utility.http_request(`${get_flowdev_alias_url}`, { method: 'get' });
  custom_name.value.value = rsp || props.ip;
  prev_name.value = custom_name.value.value;
}

const updateFlowDevAlias = async function () {
  const params = {
    csrf: props.context.csrf,
    ip: ntopng_url_manager.get_url_entry('ip'),
    alias: custom_name.value.value,
    ifid: props.context.ifid
  };
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(update_flowdev_alias_url, { method: 'post', headers: headers, body: JSON.stringify(params) });

  const params_es = {
    csrf: props.context.csrf,
    ip: ntopng_url_manager.get_url_entry('ip'),
    exporter_site_id: currentSelectedOption.value.value,
    ifid: props.context.ifid,
  };
  let headers_es = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(update_flowdev_exporter_site_url, { method: 'post', headers: headers_es, body: JSON.stringify(params_es) });

  disabled.value = true;
}

const checkDisabled = function () {
  if (prev_name.value === custom_name.value.value &&
      prevExporterSite.value === currentSelectedOption.value.value) {
    disabled.value = true;
  } else {
    disabled.value = false;
  }
}

async function getExporterSites() {
  const rsp = await ntopng_utility.http_request(
    get_exporter_sites_url,
    { method: 'get' }
  );
  exporterSites.value = rsp || [];

  exporterSitesOptions.value = exporterSites.value.map(site => ({
    value: site.id,
    label: site.name
  }));

  const res = await ntopng_utility.http_request(`${get_flowdev_exporter_site_url}`, { method: 'get' });

  if (res.id != undefined && res.name != undefined){
    currentSelectedOption.value = {
      value: res.id,
      label: res.name
    }
    prevExporterSite.value = currentSelectedOption.value.value;
  }
}

function onSelectExporterSite(option) {
  currentSelectedOption.value = {
    value: option.value,
    label: option.label
  }
  checkDisabled();
}

</script>