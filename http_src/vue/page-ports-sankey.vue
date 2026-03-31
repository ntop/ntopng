<!--
  (C) 2013-22 - ntop.org
-->

<template>
    <div class="button-group mb-2 d-flex align-items-center">
        <template v-for="(value, index) in page_filters">
            <div v-if="value.length > 0" class="dropdown me-2 d-flex"><span
                    class="no-wrap d-flex align-items-center filters-label me-2"><b>{{ _i18n('server_ports.' + key) }}:
                    </b></span>
                <SelectSearch v-model:selected_option="active_filter_list[key]" :options="value"
                    @select_option="changedOption">
                </SelectSearch>
            </div>
        </template>
        <template v-if="max_entries_reached == true">
            <div class="mt-auto m-1" :title=max_entry_title style="cursor: help;">
                <button type="button" class="btn btn-link" disabled>
                    <i class="text-danger fa-solid fa-triangle-exclamation"></i>
                </button>
            </div>
        </template>
    </div>


    <div class="m-2 mb-3">
        <div class="mb-3 d-flex flex-column" style="height: 70vh;">
            <Loading :isLoading="loading"></Loading>
            <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data"
                @node_click="onNodeClick" @autorefresh_toggle="onAutoRefreshToggle">
            </Sankey>
        </div>
        <div class="card-footer">
            <NoteList :note_list="note_list"> </NoteList>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as SelectSearch } from "./select-search.vue"
import { default as Loading } from "./loading.vue"
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Sankey } from "./sankey.vue";
import { default as NoteList } from "./note-list.vue";

const active_filter_list = {}

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const max_entries_reached = ref(false)
const max_entry_title = _i18n('ports_analysis.max_entries')
const no_data_message = _i18n('ports_analysis.no_data')
const sankey_chart = ref(null)
const page_filters = ref({})
const sankey_data = ref({});
const live_rest = `${http_prefix}/lua/pro/rest/v2/get/vlan/live_ports.lua`
const historical_rest = `${http_prefix}/lua/pro/rest/v2/get/vlan/historical_ports.lua`
let current_rest = live_rest
const loading = ref(true)
const note_list = [
    _i18n("server_ports.notes"),
];

onBeforeMount(() => {
    for (const [name, filters] of Object.entries(props.context.available_filters)) {
        filters.forEach((filter) => {
            filter.filter_name = name
            if (filter.currently_active)
                active_filter_list[name] = filter;
        })
        page_filters.value[name] = filters
    }
});

onMounted(() => {
    updateSankeyData();
});

/* ************************************** */

const updateSankeyData = async () => {
    loading.value = true;
    let data = await getSankeyData();
    sankey_data.value = data;
    loading.value = false;
}

/* ************************************** */

const changedOption = (opt) => {
    ntopng_url_manager.set_key_to_url(opt.filter_name, opt.id)
    updateSankeyData();
}

/* ************************************** */

const getSankeyData = async () => {
    const url_request = getSankeyUrl();
    let graph = await ntopng_utility.http_request(url_request);
    graph.nodes.forEach((node, i) => {
        node.index = i
    })
    graph.links.forEach((link, i) => {
        if (link.value === 0) {
            link.value = 1
        }
        let node = graph.nodes.find((el) => el.node_id == link.source_node_id)
        link.source = node.index;
        node = graph.nodes.find((el) => el.node_id == link.target_node_id)
        link.target = node.index;
    })

    return graph
}

/* ***************************************************** */

const getExtraParameters = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

const getSankeyUrl = () => {
    let params = {
        ifid: props.context.ifid,
        ...getExtraParameters()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${current_rest}?${url_params}`;
    return url_request;
}

/* ************************************** */

function onNodeClick(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ************************************** */

const onAutoRefreshToggle = (enabled) => {
    if (enabled) {
        intervalId = setInterval(() => {
            updateSankeyData()
        }, 10000 /* 10 sec refresh */)
    } else {
        clearInterval(intervalId);
    }
}

</script>