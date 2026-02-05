<!-- 
<template>
    <div class="row">
        <div class="card card-shadow">
            <div class="card-body">
                <Transition name="add-effect" mode="out-in">
                    <div class="position-relative">
                        <NetworkMap ref="network_map_test" :empty_message="no_data_message"
                            :page_csrf="props.context.csrf" :url="exporters_map_url"
                            :url_params="getExtraParameters()" :map_id="'network_map_test'">
                        </NetworkMap>
                    </div>
                </Transition>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as Loading } from "./loading.vue"
import { default as NetworkMap } from "./network-map.vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const no_data_message = i18n('no_data_available')
const loading = ref(true);
//const network_map_test_url = `${http_prefix}/lua/rest/v2/get/ntopng/test_rest.lua`
const exporters_map_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/map.lua`

/* ************************************** */

function onNodeClick(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ************************************** */

const getExtraParameters = () => {
    const extra_params = ntopng_url_manager.get_url_object();
    console.log(extra_params)
    return {
        enabled: false,
        ...extra_params
    };
};

/* ************************************** */

/* ************************************** */

onBeforeMount(() => { })

/* ************************************** */

</script>

<style scoped>
.add-effect-move,
/* apply transition to moving elements */
.add-effect-enter-active,
.add-effect-leave-active {
    transition: all 0.35s ease;
}

/* Transform: positive pixels, the effects let enters the component
 * from the right, negative pixels from the left
 */
.add-effect-enter-from {
    opacity: 0;
    transform: translateX(-60px);
}

.add-effect-leave-to {
    opacity: 0;
    transform: translateX(0px);
}

/* ensure leaving items are taken out of layout flow so that moving
   animations can be calculated correctly. */
.add-effect-leave-active {
    position: absolute;
}

.slider-connect {
    background: none !important;
}
</style>
-->
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

const chord_rest_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporters_map.lua`

onBeforeMount(() => {
});

onMounted(() => {
    set_chord_data();
});

const reload = function () {
    set_chord_data();
}

async function set_chord_data() {
    console.log('test')
    let data = await get_chord_data();
    chord_data.value = data;
}

async function get_chord_data() {
    try {
        const url_params = ntopng_url_manager.get_url_object();
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
