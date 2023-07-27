<!-- (C) 2023 - ntop.org -->
<template>
    <div class='row'>
        <template v-for="c in components">
            <div :class="'col-' + c.width" class="widget-box-main-dashboard">
                <div class="widget-box">
                    <h4>{{ _i18n(c.i18n_name) }}</h4>
                    <small>
                      <SimpleTable v-if="c.component == 'simple-table'"
                        :i18n_title="c.i18n_name"
                        :ifid="c.ifid ? c.ifid : context.ifid"
                        :params="c.params"></SimpleTable>
                      <span v-if="c.component == 'live-chart'">(this is a live chart)</span>
                      <span v-if="c.component == 'timeseries-chart'">(this is a timeseries chart)</span>
                    </small>
                </div>
            </div>
        </template>
    </div> <!-- div row -->
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_status_manager, ntopng_custom_events, ntopng_url_manager, ntopng_utility, ntopng_sync } from "../services/context/ntopng_globals_services";

import NtopUtils from "../utilities/ntop-utils";
import TableUtils from "../utilities/table-utils";

import { ntopChartApex } from "../components/ntopChartApex.js";

import { default as SimpleTable } from "./simple-table.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as Navbar } from "./page-navbar.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as Spinner } from "./spinner.vue";
import { default as Switch } from "./switch.vue";

const components = ref([]);

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const page_id = "page-dashboard";
const default_ifid = props.context.ifid;
const page = ref("");

onBeforeMount(async () => {
    load_components();
});

onMounted(async () => {
    register_components_on_status_update();
});

async function register_components_on_status_update() {
    ntopng_status_manager.on_status_change(page.value, (new_status) => {
        let url_params = ntopng_url_manager.get_url_params();

        //refresh

    }, false);
}

async function load_components() {
    let url_request = `${http_prefix}/lua/pro/rest/v2/get/dashboard/template.lua?template=default`;
    let res = await ntopng_utility.http_request(url_request);
    components.value = res.list;
}

</script>

<style scoped></style>
