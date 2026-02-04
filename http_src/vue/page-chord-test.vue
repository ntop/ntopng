<!--
  (C) 2025 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="card card-shadow">
                <div class="card-body" ref="body_div" style="height: 70vh;">
                    <ChordChart ref="chord_chart" :no_data_message="no_data_message"
                        :chord_data="chord_data">
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
const chord_data = ref({});

const chord_rest_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/chord_test.lua`

onBeforeMount(() => {
});

onMounted(() => {
    set_chord_data();
});

const reload = function () {
    set_chord_data();
}

async function set_chord_data() {
    let data = await get_chord_data();
    chord_data.value = data;
}

async function get_chord_data() {
    try {
        const url_params = ntopng_url_manager.get_url_object();
        const url = NtopUtils.buildURL(chord_rest_url, url_params);
        const response = await ntopng_utility.http_request(url);

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
.card-shadow {
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}
</style>
