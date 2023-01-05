<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card card-shadow">
      <!-- <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100"> -->
        <!-- <div class="text-center"> -->
        <!--   <div class="spinner-border text-primary mt-5" role="status"> -->
        <!--     <span class="sr-only position-absolute">Loading...</span> -->
        <!--   </div> -->
        <!-- </div> -->
      <!-- </div> -->
      <div class="card-body">
        <div class="d-flex align-items-center mb-2">
          <div class="d-flex no-wrap">
            <div>
              <SelectSearch
                v-model:selected_option="active_hosts_type"
                :options="sankey_format_list"
                @select_option="update_sankey">
              </SelectSearch>
            </div>
          </div>
        </div>

        <Sankey2
	  :sankey_data="sankey_data">
        </Sankey2>        
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as SelectSearch } from "./select-search.vue"
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Sankey2 } from "./sankey_2.vue";

const props = defineProps({
});

const _i18n = (t) => i18n(t);
const url = `${http_prefix}/lua/pro/rest/v2/get/host/flows/data.lua`;

const sankey_format_list = [
    { filter_name: 'hosts_type', key: 1, id: 'local_only', title: _i18n('flows_page.local_only'), label: _i18n('flows_page.local_only'), filter_icon: false, countable: false },
    //  { filter_name: 'hosts_type', key: 2, id: 'remote_only', title: _i18n('flows_page.remote_only'), label: _i18n('flows_page.remote_only'),  filter_icon: false, countable: false },
    { filter_name: 'hosts_type', key: 2, id: 'local_origin_remote_target', title: _i18n('flows_page.local_cli_remote_srv'), label: _i18n('flows_page.local_cli_remote_srv'), filter_icon: false, countable: false },
    { filter_name: 'hosts_type', key: 3, id: 'remote_origin_local_target', title: _i18n('flows_page.local_srv_remote_cli'), label: _i18n('flows_page.local_srv_remote_cli'), filter_icon: false, countable: false },
    { filter_name: 'hosts_type', key: 4, id: 'all_hosts', title: _i18n('flows_page.all_flows'), label: _i18n('flows_page.all_flows'), filter_icon: false, countable: false },
];

const active_hosts_type = ref(sankey_format_list[0]);

const sankey_data = ref({});

onBeforeMount(() => {});

onMounted(() => { 
    update_sankey(active_hosts_type);
});

const update_sankey = function() {
    let entry = active_hosts_type.value;
    ntopng_url_manager.set_key_to_url(entry.filter_name, entry.id);
    set_sankey_data();
}

async function set_sankey_data() {
    let data = await get_sankey_data();
    if (data.nodes.length == 0 || data.links.length == 0) {
	console.log("Empty Data");
	return;
    }
    sankey_data.value = data;
}

async function get_sankey_data() {
    const url_request = get_sankey_url();
    let res = await ntopng_utility.http_request(url_request);
    console.log(res);
    const data = get_sankey_data_from_rest_data(res);
    return data;
}

function get_sankey_url() {
    let params = {
	host: ntopng_url_manager.get_url_entry("host"),
	vlan: ntopng_url_manager.get_url_entry("vlan"),
	ifid: ntopng_url_manager.get_url_entry("ifid"),
	hosts_type: ntopng_url_manager.get_url_entry("hosts_type"),
    };
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${url}?${url_params}`;
    return url_request;
}

function get_sankey_data_from_rest_data(res) {
    let nodes = [];
    let links = [];

    let nodes_added_dict = {};
    let links_added_dict = {};
    const f_add_node = (node_id, href, color) => {
	if (nodes_added_dict[node_id] != null) { return; }
	let index = nodes.length;
	nodes_added_dict[node_id] = index;
	let new_node = { index, name: node_id, href, color };
	nodes.push(new_node);
    };
    const f_add_link = (source, target, value, label) => {
	const source_index = nodes_added_dict[source];
	const target_index = nodes_added_dict[target];
	let new_link = { source: source_index, target: target_index, value, label };
	links.push(new_link);
    };
    res.forEach((el) => {
	f_add_node(el.source, el.source_link, el.source_color);
	f_add_node(el.target, el.target_link, el.target_color);
	f_add_link(el.source, el.target, el.value, el.link);
    });
    return { nodes, links };
}

</script>






