<!--
  (C) 2013-24 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="card card-shadow">
                <Loading v-if="loading"></Loading>
                <div class="card-body">
                    <div class="align-items-center justify-content-end mb-3"
                        :class="[loading ? 'ntopng-gray-out' : '']" style="height: 70vh;">
                        <div class="d-flex align-items-center mb-2">
                            <div class="d-flex no-wrap ms-auto">
                                <div class="m-1">
                                    <div style="min-width: 16rem;">
                                        <label class="my-auto me-1">{{ _i18n('criteria') }}: </label>
                                        <SelectSearch v-model:selected_option=" active_hosts_type "
                                            :options=" sankey_format_list " @select_option=" update_sankey ">
                                        </SelectSearch>
                                    </div>
                                </div>
                                <div>
                                    <label class="my-auto me-1"></label>
                                    <div>
                                        <button class="btn btn-link m-1" tabindex="0" type="button" @click=" reload ">
                                            <span><i class="fas fa-sync"></i></span>
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <Sankey ref="sankey_chart" @node_click=" on_node_click " :sankey_data="sankey_data" ></Sankey>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as SelectSearch } from "./select-search.vue"
import { default as Loading } from "./loading.vue"
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Sankey } from "./sankey.vue";

const props = defineProps({
    is_local: Boolean
});

const _i18n = (t) => i18n(t);
const url = `${http_prefix}/lua/pro/rest/v2/get/exporters/sankey.lua`;
const sankey_chart = ref(null)
const loading = ref(false);

const sankey_format_list = [
    { filter_name: 'criteria', key: 3, id: 'flow_volume_criteria', title: _i18n('exporters_page.flow_volume_criteria'), label: _i18n('exporters_page.flow_volume_criteria'), filter_icon: false, countable: false },
    { filter_name: 'criteria', key: 4, id: 'flow_drops_criteria', title: _i18n('exporters_page.flow_drops_criteria'), label: _i18n('exporters_page.flow_drops_criteria'), filter_icon: false, countable: false },
];

const active_hosts_type = ref(sankey_format_list[3]);

const sankey_data = ref({});

onBeforeMount(() => { });

onMounted(() => {
    update_sankey();
});

function on_node_click(node) {
    if (node.is_link_node == true) { return; }
    let url_obj = {
        host: node.info.ip,
        vlan: node.info.vlan,
    };
    let url_params = ntopng_url_manager.obj_to_url_params(url_obj);
    const host_url = `${http_prefix}/lua/host_details.lua?${url_params}`;
    ntopng_url_manager.go_to_url(host_url);
}

const update_sankey = function () {
    set_sankey_data();
}

const reload = function () {
    update_sankey()
}

async function set_sankey_data() {
    loading.value = true;
    let data = await get_sankey_data();
    sankey_data.value = data;
    loading.value = false;
}

async function get_sankey_data() {
    const url_request = get_sankey_url();
    let graph = await ntopng_utility.http_request(url_request);
    graph.nodes.forEach((node, i) => {
        node.index = i
    })
    graph.links.forEach((link, i) => {
        let node = graph.nodes.find((el) => el.node_id == link.source_node_id)
        link.source = node.index;
        node = graph.nodes.find((el) => el.node_id == link.target_node_id)
        link.target = node.index;
    })
    return graph
}

function get_sankey_url() {
    let params = {
        ifid: ntopng_url_manager.get_url_entry("ifid"),
    };
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${url}?${url_params}`;
    return url_request;
}
</script>






