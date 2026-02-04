<!-- (C) 2022-26 - ntop.org     -->
<template>
  <div class="m-3">
    <!-- Page header -->
    <h5>{{ _i18n('modify_flowdev_settings') }}</h5>
    <hr>

    <!-- Main settings card -->
    <div class="m-4 card card-shadow">
      <div class="card-body">
        <!-- Settings table -->
        <div class="table-responsive">
          <table class="table table-striped table-bordered">
            <tbody class="table_length">
              <!-- Flow device alias row -->
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_alias') }}</b><br>
                    </div>
                    <div class="col-4">
                      <!-- Alias input field with change detection -->
                      <input type="text" ref="aliasInput" class="form-control border" @input="validateFormChanges">
                    </div>
                  </div>
                </td>
              </tr>

              <!-- Exporter site selection row -->
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_exporter_site') }}</b><br>
                    </div>
                    <div class="col-4">
                      <!-- Dropdown for exporter site selection -->
                      <SelectSearch v-model:selected_option="selectedExporterSite" :options="exporterSiteOptions"
                        :disabled="false" @select_option="handleExporterSiteSelect" />
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Action buttons -->
        <div class="d-flex justify-content-end me-1">
          <!-- Save button - disabled when no changes detected -->
          <button class="btn btn-primary" :class="[isSaveDisabled ? 'disabled' : '']" @click="saveFlowDeviceSettings"
            id="save">
            {{ _i18n("save_settings") }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as SelectSearch } from "./select-search.vue";

// Internationalization helper
const _i18n = (t) => i18n(t);

// Template refs
const aliasInput = ref(null);

// Form state
const originalAlias = ref(''); // Original alias value for change detection
const isSaveDisabled = ref(true); // Controls save button state

// Component props
const props = defineProps({
  context: Object // Contains ifid, csrf, and other context data
});

// Exporter sites data
const exporterSites = ref([]); // Raw exporter sites from API
const originalExporterSiteId = ref(''); // Original site ID for change detection
const exporterSiteOptions = ref([]); // Formatted options for dropdown
const selectedExporterSite = ref({
  value: '',
  label: ''
});

// API endpoint URLs
const FLOWDEV_CONFIG_UPDATE_URL = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/config.lua`;
const EXPORTER_SITES_LIST_URL = `${http_prefix}/lua/pro/rest/v2/get/exporter_site/exporter_sites_list.lua`;
const FLOWDEV_EXPORTER_CONFIG_GET_URL = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/config.lua?flowdev_ip=${getDeviceIpFromUrl()}&ifid=${props.context.ifid}`;

/**
 * Vue lifecycle hook: Called when component is mounted to DOM
 * Loads initial data for the form
 */
onMounted(async () => {
  await loadExporterSitesList();
  await loadFlowDeviceConfiguration();
});

/**
 * Extracts the device IP address from URL parameters
 * 
 * @returns {string} The IP address from URL
 */
function getDeviceIpFromUrl() {
  return ntopng_url_manager.get_url_entry('ip')
}

/**
 * Loads the current flow device alias from the server
 * and populates the input field with the value
 */
async function loadFlowDeviceConfiguration() {
  const response = await ntopng_utility.http_request(`${FLOWDEV_EXPORTER_CONFIG_GET_URL}`, {
    method: 'get'
  });

  // Use response alias or fallback to device IP
  if (response) {
    // Get the Alias
    const ip = getDeviceIpFromUrl()
    const aliasValue = response.alias || ip;
    aliasInput.value.value = aliasValue;
    originalAlias.value = aliasValue;

    // Get the exporter site
    if (response.exporter_site && response.exporter_site.id) {
      selectedExporterSite.value = {
        value: response.exporter_site.id,
        label: response.exporter_site.name
      };
    } else {
      // No site found, use the default one, that is in the first position of the entire list
      selectedExporterSite.value = exporterSiteOptions.value[0]
    }
    originalExporterSiteId.value = selectedExporterSite.value.value;
  }
}

/**
 * Saves the updated flow device settings (alias and exporter site)
 * to the server and disables the save button on success
 */
const saveFlowDeviceSettings = async function () {
  const requestData = {
    csrf: props.context.csrf,
    ip: ntopng_url_manager.get_url_entry('ip'),
    exporter_site_id: selectedExporterSite.value.value,
    alias: aliasInput.value.value,
    ifid: props.context.ifid,
  };

  const requestHeaders = {
    'Content-Type': 'application/json'
  };

  await ntopng_utility.http_request(
    FLOWDEV_CONFIG_UPDATE_URL,
    {
      method: 'post',
      headers: requestHeaders,
      body: JSON.stringify(requestData)
    }
  );

  // Update original values and disable save button
  originalAlias.value = aliasInput.value.value;
  originalExporterSiteId.value = selectedExporterSite.value.value;
  isSaveDisabled.value = true;
}

/**
 * Validates whether form has been modified and updates save button state
 * Compares current values with original values to detect changes
 */
const validateFormChanges = function () {
  const isAliasChanged = originalAlias.value !== aliasInput.value.value;
  const isExporterSiteChanged = originalExporterSiteId.value !== selectedExporterSite.value.value;

  isSaveDisabled.value = !(isAliasChanged || isExporterSiteChanged);
}

/**
 * Loads the list of available exporter sites from the server
 * and sets up the dropdown options
 */
async function loadExporterSitesList() {
  const response = await ntopng_utility.http_request(
    EXPORTER_SITES_LIST_URL,
    { method: 'get' }
  );

  exporterSites.value = response || [];
  const tmpSites = exporterSites.value.map(site => ({
    value: site.id,
    label: site.name
  }));
  
  exporterSiteOptions.value = [
    tmpSites.find(e => e.value == 0),
    ...tmpSites.filter(site => site.value != 0).sort(sortByLabel)
  ];
}

function sortByLabel(a, b) {
  return a.label.localeCompare(b.label, 'it', { sensitivity: 'base' });
}

/**
 * Handles selection of an exporter site from the dropdown
 * 
 * @param {Object} option - Selected option object with value and label
 */
function handleExporterSiteSelect(option) {
  selectedExporterSite.value = {
    value: option.value,
    label: option.label
  };
  validateFormChanges();
}

</script>