<template>
    <div class="m-2 mb-3">
        <div class="mb-3 d-flex flex-column" style="height: 60vh;">
            <div class="d-flex align-items-center mb-2">
                <div class="d-flex no-wrap">
                    <div class="m-1">
                        <div style="min-width: 16rem;">
                            <label class="me-1">{{ _i18n('criteria') }}: </label>
                            <SelectSearch v-model:selected_option="active_sankey_type" :options="sankey_format_list"
                                @select_option="add_sankey_filter">
                            </SelectSearch>
                        </div>
                    </div>
                </div>
            </div>
            <Loading v-if="loading"></Loading>
            <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data"
                :autorefresh="autoRefreshEnabled" @node_click="on_node_click" @autorefresh_toggle="onAutoRefreshToggle">
            </Sankey>
        </div>
        <div class="card-footer">
            <NoteList :note_list="note_list"> </NoteList>
        </div>
    </div>
</template>


<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as Loading } from "./loading.vue"
import { default as Sankey } from "./sankey.vue";
import { default as SelectSearch } from "./select-search.vue";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const first_open = ref(true);
const sankey_url = `${http_prefix}/lua/rest/v2/get/asn/sankey.lua`;
const sankey_chart = ref(null)
const sankey_data = ref({});
const loading = ref(false);
const no_data_message = i18n("no_data_available")
const autoRefreshEnabled = ref(false);
const active_sankey_type = ref({})
const sankey_format_list = [
    { key: "criteria_as", value: 'ingress_egress_traffic_criteria', label: _i18n('as_overview.ingress_egress_traffic_criteria') },
    { key: "criteria_as", value: 'ingress_traffic_criteria', label: _i18n('as_overview.ingress_traffic_criteria') },
    { key: "criteria_as", value: 'egress_traffic_criteria', label: _i18n('as_overview.egress_traffic_criteria') },
    { key: "criteria_as", value: 'total_traffic_criteria', label: _i18n('as_overview.total_traffic_criteria') },
];

const note_list = [
    _i18n("as_overview.note_ingress_egress"),
]
/* ************************************** */

onBeforeMount(() => {
    const criteria = ntopng_url_manager.get_url_entry("criteria_as");
    active_sankey_type.value = sankey_format_list[0];
    if (criteria) {
        sankey_format_list.forEach((element) => {
            if (element.value == criteria) {
                active_sankey_type.value = element
            }
        })
    }
})

const onAutoRefreshToggle = (enabled) => {
    autoRefreshEnabled.value = enabled;
}

onMounted(() => {
    update_sankey_data();
    setInterval(() => {
        first_open.value = false;

        // refresh only if autorefresh is enabled
        if (autoRefreshEnabled.value) {
            update_sankey_data()
        }
    }, 10000 /* 10 sec refresh */)
})

/* ************************************** */

const add_sankey_filter = async (opt) => {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    update_sankey_data();
}

const update_sankey_data = async () => {
    loading.value = true;
    let data = await get_sankey_data();
    sankey_data.value = data;
    loading.value = false;
}

const get_sankey_data = async () => {
    const url_request = get_sankey_url();
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

const get_sankey_url = () => {
    let params = {
        ifid: props.context.ifid,
        ...get_extra_params_obj()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${sankey_url}?${url_params}`;
    return url_request;
}

function on_node_click(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ***************************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};


</script>