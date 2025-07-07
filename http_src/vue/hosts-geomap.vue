<template>
    <div class="row">
        <div class="col-12">
            <div class="card card-shadow">
                <div class="card-body">
                    <div class="row">
                        <div class="col-sm-2">
                            <SelectSearch :id="selectSearch" :options="dropdownOptions"
                                :selected_option="selectedHostType" v-model="selectedHostType"
                                @update:selected_option="updateSelectedOption" />
                        </div>

                        <div class="col-md-12 col-lg-12 col-xs-12 mb-4">
                            <br />
                            <template>
                                <div v-if="showAlert" :class="['alert', alertClass]" id="geomap-alert" role="alert">
                                    <span id="error-message">{{ alertMessage }}</span>
                                    <button type="button" class="btn-close" @click="closeAlert"
                                        aria-label="Close"></button>
                                </div>
                            </template>

                            <Geomap :tooltipFormatter="formatTooltipData"
                                :geomapDataArray="geomapDataArray" :getGeomapData="getGeomapData"
                                :style="[(is_host_details) ? 'height: 65vh;' : 'height: 75vh']" :glowDots="false"/>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import Geomap from "./geomap.vue";
import SelectSearch from "./select-search.vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services";

const props = defineProps({
    context: Object,
});

const ifid = props.context.ifid;
const is_host_details = ref(false);
const geomapDataArray = ref([]);

const dropdownOptions = ref([
    { id: 0, label: "Active Hosts" },
    { id: 1, label: "Alerted Hosts" },
    { id: 2, label: "Local Hosts" },
    { id: 3, label: "Remote Hosts" },
]);
const selectSearch = ref("selectSearch");
const selectedHostType = ref(dropdownOptions.value[0]);

const alertMessage = ref("");
const alertClass = ref("alert-warning");
const showAlert = ref(false);

const endpoint = `/lua/rest/v2/get/geo_map/hosts.lua?`;

onMounted(() => {
    ntopng_url_manager.set_key_to_url("hosts_category", 0);
    ntopng_url_manager.set_key_to_url("ifid", ifid);
    getGeomapData();
});

function closeAlert() {
    showAlert.value = false;
}

// formatting function to handle tooltip formatter
function formatTooltipData(host) {
  if (!host) return "";

  let html = `<div>`;

  // IP with clickable link
  if (host.ip) {
    html += `IP: <a href='${http_prefix}/lua/host_details.lua?host=${host.ip}'>${host.ip}</a><br>`;
  }

  // Country with flag and link
  if (host.country) {
    const countryCode = (host.country_code || host.country).toLowerCase();
    html += `Country: <b>${host.country}</b><a href='/lua/hosts_stats.lua?country=${host.country}'>
                <img src='/dist/images/blank.gif' class='flag flag-${countryCode}' />
             </a><br>`;
  }

  // City
  if (host.city) {
    html += `City: <b>${host.city}</b><br>`;
  }

  // Alerts Count
  html += `Alerts Count: <b>${host.numAlerts ?? 0}</b><br>`;

  // Score As Client
  html += `Score As Client: <b>${host.scoreClient ?? 0}</b><br>`;

  // Score As Server
  html += `Score As Server: <b>${host.scoreServer ?? 0}</b>`;

  html += `</div>`;

  return html;
}


async function getGeomapData() {
    // flush data before calling endpoint to remove data points that are not of this element
    geomapDataArray.value = [];

    const url = `${http_prefix}${endpoint}${ntopng_url_manager.get_url_params()}`;
    try {
        const rsp = await ntopng_utility.http_request(url);
        geomapDataArray.value = rsp;
        is_host_details.value = !!ntopng_url_manager.get_url_entry("host");
    } catch (error) {
        displayLocalizedError(error);
    }
}

async function updateSelectedOption(option) {
    ntopng_url_manager.set_key_to_url("hosts_category", option.id);
    getGeomapData();
}

function displayLocalizedError(error) {
    alertMessage.value = `${i18n("geo_map.geolocation_warning")}: ${i18n("geo_map.using_default_location")}`;
    alertClass.value = "alert-warning";
    showAlert.value = true;
}
</script>

<style scoped></style>