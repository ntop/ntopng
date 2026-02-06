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
            <NoteList :note_list="note_list"></NoteList>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as ChordChart } from "./chord-chart.vue";
import { default as NoteList } from "./note-list.vue";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const no_data_message = _i18n('flows_page.no_data')
const is_sites_map = ref(0);


const note_list_exporters_map = [
  _i18n("exporter_sites_page.exporters_map_notes")
]

const note_list_sites_map = [
  _i18n("exporter_sites_page.sites_map_notes")
]

const chord_data = ref({});

const note_list = computed(() => {
  const url_params = ntopng_url_manager.get_url_object();
  if (url_params && url_params.site_mode) {
    return note_list_sites_map;
  }
  return note_list_exporters_map;
});

const chord_rest_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/map.lua`

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
    // Colors are assigned by chord-chart.vue using color-utils.js, consistent coloring across refresh
    chord_data.value = data;
}

async function get_chord_data() {
    try {
        const url_params = ntopng_url_manager.get_url_object();
        console.log(url_params)
        const url = NtopUtils.buildURL(chord_rest_url, url_params);
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
.card-shadow {
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}
</style>
