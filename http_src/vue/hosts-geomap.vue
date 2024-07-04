<!-- (C) 2022 - ntop.org     -->
<template>
    <div class='row'>
        <div class='col-12'>
            <div class="card card-shadow">
                <div class="card-body">

                    <div class="row">
                        <div class="col-sm-2">
                            <SelectSearch :id="selectSearch" :options="dropdownOptions"
                                :selected_option="selectedHostType" v-model="selectedHostType"
                                @update:selected_option="updateSelectedOption">
                            </SelectSearch>
                        </div>

                        <div class='col-md-12 col-lg-12 col-xs-12 mb-4'>

                            <br>

                            <template>
                                <div v-if="showAlert" :class="['alert', alertClass]" id="geomap-alert" role="alert">
                                    <span id="error-message">{{ alertMessage }}</span>
                                    <button type="button" class="btn-close" @click="closeAlert"
                                        aria-label="Close"></button>
                                </div>
                            </template>
                            <div class="d-flex justify-content-center align-items-center" :style="[(is_host_details) ? 'height: 65vh;' : 'height: 75vh']"
                                id="map-canvas">
                            </div>
                        </div>
                    </div>
                </div> <!-- card body -->

            </div>
        </div>
    </div> <!-- div row -->

</template>

<script setup>
import { ref, onMounted } from "vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services";

import { default as SelectSearch } from "./select-search.vue"

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const is_host_details = ref(false);
const ifid = props.context.ifid;

// select search
const selectSearch = ref('selectSearch');
const dropdownOptions = ref([
    { id: 0, label: "Active Hosts" },
    { id: 1, label: "Alerted Hosts" },
    { id: 2, label: "Local Hosts" },
    { id: 3, label: "Remote Hosts" },
])
const selectedHostType = ref(dropdownOptions.value[0])
// Error message refs
const alertMessage = ref('');
const alertClass = ref('alert-warning');
const showAlert = ref(false);

let hosts = null;
let map = null;
let markers = null;

const default_coords = [41.9, 12.4833333];
const zoom_level = 4;

let endpoint = `${http_prefix}/lua/rest/v2/get/geo_map/hosts.lua?`;
let baseEndpoint = "";

onMounted(() => {
    // set host type -> see dropdownOptions for available options
    ntopng_url_manager.set_key_to_url("hosts_category", 0)
    ntopng_url_manager.set_key_to_url("ifid", ifid)

    init_map()
})

const display_localized_error = (error_code) => {
    alertMessage.value = `${i18n('geo_map.geolocation_warning')}: ${i18n('geo_map.using_default_location')}`;

    // Set the alert class
    alertClass.value = 'alert-warning';

    // Show the alert
    showAlert.value = true;
}

const display_localized_no_geolocation_msg = () => {

    alertMessage.value = `${i18n('geo_map.unavailable_geolocation')}: ${i18n('geo_map.using_default_location')}`;

    // Set the alert class
    alertClass.value = 'alert-danger';

    // Show the alert
    showAlert.value = true;
}

function closeAlert() {
    showAlert.value = false;
}
const red_marker = L.icon();

const info_key_names = {
    "scoreClient": i18n("score_as_client"),
    "scoreServer": i18n("score_as_server"),
    "country": i18n("nation"),
    "totalFlows": i18n("flows"),
    "city": i18n("city"),
    "numAlerts": i18n("num_alerts"),
};


const create_marker = (h) => {
    h = JSON.parse(JSON.stringify(h));
    // sort to keep ordered layout in map marker popup window
    const sortedResponse = ["country", "city", "ip", "numAlerts", "scoreClient", "scoreServer"]

    const settings = { title: h.name };
    if (h.isRoot) settings.icon = red_marker;

    const ip = h.ip
    const lat = h.lat;
    const lng = h.lng;
    const name = h.name;
    let name_ip = ip;
    let extra_info = '';

    // IP is the first value of the marker window when clicked
    extra_info += `<div> IP: <a href='${http_prefix}/lua/host_details.lua?host=${ip}'>${name_ip}</a></br>`

    // Formatting the extra info to print into the Geo Map
    for (const key of sortedResponse) {
        
        // handle flag
        if (key === "country") {
            extra_info += `<a href='/lua/hosts_stats.lua?country=${h[key]}'><img src='/dist/images/blank.gif' class='flag flag-${h[key].toLowerCase()}'></a>&nbsp&nbsp`
        }

        // check if i18n is defined for the current key and print the output on the marker popup
        if ((h[key] !== undefined) && (info_key_names[key] !== undefined)) {
            extra_info += info_key_names[key] + ": <b>" + h[key] + "</b></br>";
        }
    }

    if (h["flow_status"]) {
        let flow_status = i18n_ext.flow_status + ":</br>";
        for (const prop in h["flow_status"]) {
            flow_status = flow_status + "<b>" + h["flow_status"][prop]["num_flows"] + " Flows, " + h["flow_status"][prop]["label"] + "</b></br>";
        }
        extra_info = extra_info + flow_status;
    }

    extra_info += "</div>"

    if (name)
        name_ip = name + "</br>" + name_ip;

    return L.marker(L.latLng(lat, lng), settings).bindPopup(extra_info);
}


const display_errors = (errors) => {
    const error_messages = {
        1: 'Permission denied',
        2: 'Position unavailable',
        3: 'Request timeout'
    };
    const error_code = error_messages[errors.code];

    show_positions({ coords: { latitude: 0, longitude: 0 } });

    if (errors.code != 1) {
        display_localized_error(error_code);
    }
}

const init_map = (newEndpoint = null, _baseEndpoint = null) => {
    endpoint = newEndpoint || endpoint;
    baseEndpoint = _baseEndpoint;

    if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(show_positions, display_errors,
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    }
}

async function redraw_hosts() {
    // clear markers if defined
    if (markers != null) {
        markers.clearLayers();
    }

    // get data
    const url = `${http_prefix}${endpoint}${ntopng_url_manager.get_url_params()}`
    const rsp = await ntopng_utility.http_request(url);
    ntopng_url_manager.get_url_entry('host') ? 
        is_host_details.value = true :
        is_host_details.value = false;

    // draw map markers
    draw_markers(rsp, markers, map);
}

const draw_markers = (hosts, map_markers, map) => {
    hosts.forEach(h => {
        map_markers.addLayer(
            create_marker(h)
        );

        // make a transitions to the root host
        if (h.isRoot) {
            map.flyTo([h.lat, h.lng], zoom_level);
        }
    });

    map.addLayer(map_markers);
}

async function updateSelectedOption(selectedOption) {
    // set url param hosts_category to the id of selected host category
    ntopng_url_manager.set_key_to_url("hosts_category", selectedOption.id)
    redraw_hosts()
}

async function show_positions(current_user_position) {

    // these are two map providers provided by: https://leaflet-extras.github.io/leaflet-providers/preview/
    const layers = {
        light: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        //light: "https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png",
        //light: "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}",
        //dark: "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png"
    };
    // select the right layer
    const layer = layers.light;
    const user_coords = [current_user_position.coords.latitude, current_user_position.coords.longitude];

    if (user_coords[0] == 0 && user_coords[1] == 0) {
        /* Do not even report the info/error to the user, this is
         * not relevant as the map functionality is not impacted */
        //display_localized_no_geolocation_msg();
        //console.log("Geolocation unavailable, using default location");

        user_coords[0] = default_coords[0], user_coords[1] = default_coords[1];
    }

    const hosts_map = L.map('map-canvas').setView(user_coords || default_coords, zoom_level);
    map = hosts_map;

    const map_markers = L.markerClusterGroup({
        maxClusterRadius: 100,
        spiderLegPolylineOptions: {
            opacity: 0
        }
    });

    markers = map_markers;
    map = hosts_map;

    L.tileLayer(layer, {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
    }).addTo(hosts_map);

    if (hosts != null) {
        draw_markers(hosts, map_markers, hosts_map);
        return;
    }

    // get updated data
    redraw_hosts()
}



</script>

<style scoped></style>
