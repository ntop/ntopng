<template>
    <div class="row">
        <div class="col-md-6 col-lg-6">
            <div class="card shadow-sm">
                <div class="card-header bg-white py-3">
                    <h5 class="card-title mb-0">{{_i18n("exporter_sites_page.exporters_map")}}</h5>
                </div>
                <div class="card-body" ref="exporters_body_div" style="height: 70vh;">
                    <ChordChart ref="exporters_chord_chart" :no_data_message="no_data_message"
                        :chord_data="exporters_chord_data">
                    </ChordChart>
                </div>
            </div>
        </div>
        <div class="col-md-6 col-lg-6">
            <div class="card shadow-sm">
                <div class="card-header bg-white py-3">
                    <h5 class="card-title mb-0">{{_i18n("exporter_sites_page.sites_map")}}</h5>
                </div>
                <div class="card-body" ref="sites_body_div" style="height: 70vh;">
                    <ChordChart ref="sites_chord_chart" :no_data_message="no_data_message"
                        :chord_data="sites_chord_data">
                    </ChordChart>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as ChordChart } from "./chord-chart.vue";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const no_data_message = _i18n('flows_page.no_data')
const exporters_chord_data = ref({});
const sites_chord_data = ref({});

const exporters_map_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/map.lua`
const sites_map_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/map.lua`

onBeforeMount(() => {
});

onMounted(() => {
    set_exporters_chord_data();
    set_sites_chord_data();
});

const reload = function () {
    set_exporters_chord_data();
    set_sites_chord_data();
}

async function set_exporters_chord_data() {
    let data = await get_chord_data(exporters_map_url, {});
    exporters_chord_data.value = data;
}

async function set_sites_chord_data() {
    let data = await get_chord_data(sites_map_url, { site_mode: 1 });
    sites_chord_data.value = data;
}

async function get_chord_data(rest_url, extra_params = {}) {
    try {
        const url_params = { ...ntopng_url_manager.get_url_object(), ...extra_params };
        const url = NtopUtils.buildURL(rest_url, url_params);
        const response = await ntopng_utility.http_request(url);

        console.log(response)
        if (response) {
            return response;
        }

    } catch (error) {
        console.warn('Could not fetch chord data from API', error);
    }

    // empty data if fetch fails
    return { names: [], colors: [], matrix: [] };
}

defineExpose({ reload });

</script>

<style scoped>
.card {
    border: none;
    border-radius: 8px;
}

.card-header {
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}
</style>
