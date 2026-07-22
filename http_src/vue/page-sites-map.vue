<!-- (C) 2026 - ntop.org -->
<template>
    <div class="m-2 mb-3">
        <div class="position-relative" style="height: calc(100vh - 220px); min-height: 420px;">
            <Loading :isLoading="loading" />
            <GeomapCartography v-if="!loading" height="100%" :sites="markers" :tooltipFormatter="formatTooltipData"
                :enableSearch="true" :showLabels="false" />
            <NoData v-if="!loading && markers.length === 0" :show="true" />
        </div>
    </div>
</template>

<script setup>
import { ref, computed, onBeforeMount } from "vue";
import { default as Loading } from "./loading.vue";
import { default as NoData } from "./components/no-data.vue";
import { default as GeomapCartography } from "./geomap-cartography.vue";
import { default as dataUtils } from "../utilities/data-utils.js";

const props = defineProps({
    context: Object,
});

const API_GET_SITES = `${http_prefix}/lua/pro/rest/v2/get/sites/list.lua`;

const loading = ref(true);
const sitesList = ref([]);

const markers = computed(() => sitesList.value
    .filter((s) => !dataUtils.isZeroOrEmptyString(s.latitude) && !dataUtils.isZeroOrEmptyString(s.longitude))
    .map((s) => ({ lat: Number(s.latitude), lng: Number(s.longitude), label: s.name, type: "Branch", status: "Online" })));

function formatTooltipData(site) {
    return `
        <div class="custom-tooltip-content">
            <h6>${site.label ?? ''}</h6>
            <hr/>
            <small>${site.lat}, ${site.lng}</small>
        </div>
    `;
}

onBeforeMount(async () => {
    try {
        sitesList.value = await ntopng_utility.http_request(API_GET_SITES);
    } catch (err) {
        console.error("Error retrieving sites list:", err);
        sitesList.value = [];
    }
    loading.value = false;
});
</script>
