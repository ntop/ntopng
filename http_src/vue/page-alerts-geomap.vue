<template>
    <Geomap :ifid="ifid":tooltipFormatter="formatTooltipData" :geomapDataArray="geomapDataArray" :getGeomapData="getGeomapData"></Geomap>
</template>

<script setup>
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
import FormatterUtils from "../utilities/formatter-utils.js";
import Geomap from "./geomap.vue"

const props = defineProps({
    context: Object,
});

const ifid = String(props.context.ifid);
const alerts_url = "/lua/pro/rest/v2/get/alert/geomap/alerts.lua"
const geomapDataArray = ref([]);

onMounted(async () => {
    init_url_params();
})

const create_url = (url) => {
    let req_params = get_extra_params_obj();
    let params_inserted = 0;

    for (let param in req_params) {
        if (params_inserted > 0) {
            url += '&';
        }

        url += `${param}=${encodeURIComponent(req_params[param])}`;
        params_inserted += 1;
    }

    return url;
}

function init_url_params() {
    ntopng_url_manager.set_key_to_url("ifid", ifid);

    if (ntopng_url_manager.get_url_entry("epoch_begin") == null
        || ntopng_url_manager.get_url_entry("epoch_end") == null) {
        let now = Date.now();
        let default_epoch_begin = Number.parseInt((now - 1000 * 30 * 60) / 1000);
        let default_epoch_end = Number.parseInt(now / 1000);
        ntopng_url_manager.set_key_to_url("epoch_begin", default_epoch_begin);
        ntopng_url_manager.set_key_to_url("epoch_end", default_epoch_end);
    }
}

function add_filter(filter, value) {
    ntopng_url_manager.set_key_to_url(filter, value);
}

function reset_filters() {
    init_url_params();
}

function get_url_param(param) {
    let params = ntopng_url_manager.get_url_object();
    for (const param_key in params) {
        if (param === param_key) {
            return params[param];
        }
    }

    return null;
}

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

// Fetch and process alert data
async function getGeomapData() {
    try {

        if (geomapDataArray.value.length > 0) return;
        //build url
        let url = `${http_prefix}${alerts_url}?`;
        
        url = create_url(url);
        
        let headers = {
            "Content-Type": "application/json",
        };
        const rsp = await ntopng_utility.http_request(url, { method: "get", headers });
        console.log(`Got Data, len: ${geomapDataArray.value.length}`)
        
        if (rsp) {
            if (rsp.length > 0) {
                geomapDataArray.value = rsp;
            }
        }

    } catch (error) {
        console.error('Error fetching or processing data:', error);
    }
};

const formatTooltipData = (geomapElement, countryName) => {
    const { country_code, alerts_count, severity, color } = geomapElement;

    // Map severity to a Bootstrap badge color
    const severityBadgeColor = {
        "Error": "danger",
        "Warning": "warning",
        "Info": "info"
    }[severity] || "secondary";

    // The country_code is usually what's used for flag sprites (e.g., 'us', 'fr', 'de')
    const flagClass = country_code ? `flag-${country_code.toLowerCase()}` : '';

    return `
        <div class="custom-tooltip-content p-2">
            <div class="tooltip-header mb-2">
                <h6 class="mb-1 fw-bold">
                    <img src='${http_prefix}/dist/images/blank.gif' class='flag ${flagClass}' alt="${countryName} flag">
                    ${countryName}
                </h6>
            </div>
            <hr class="my-2">
            <div class="tooltip-body">
                <div class="row mb-1">
                    <div class="col-6"><strong>Alerts:</strong></div>
                    <div class="col-6 text-end">
                        <span>${alerts_count}</span>
                    </div>
                </div>
                <div class="row">
                    <div class="col-6"><strong>Severity:</strong></div>
                    <div class="col-6 text-end">
                        <span class="badge bg-${severityBadgeColor}">${severity}</span>
                    </div>
                </div>
            </div>
        </div>
    `;
};

</script>