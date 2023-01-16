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
import { default as Sankey2 } from "./sankey_3.vue";

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
    }
    sankey_data.value = data;
}

async function get_sankey_data() {
    const url_request = get_sankey_url();
    let graph = await ntopng_utility.http_request(url_request);
    console.log(graph);
    // add_fake_circular_link(graph);
    graph = make_complete_graph(graph);
    graph = make_dag_graph(graph);
    const sankey_data = get_sankey_data_from_rest_data(graph);
    return sankey_data;
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
    let node_dict = {}, link_to_nodes_dict = {};
    // create a node dict
    res.nodes.forEach((node) => node_dict[node.node_id] = node);
    
    let f_get_link_node_id = (link) => {
	return `${link.source_node_id}_${link.label}`; 
    };
    // merge all links by label
    res.links.forEach((link) => {
	let link_node_id = f_get_link_node_id(link);
	let link_to_nodes = link_to_nodes_dict[link_node_id];
	if (link_to_nodes == null) {
	    link_to_nodes = {
		id: link_node_id,
		label: link.label,
		node_links: [],		
	    };
	    link_to_nodes_dict[link_node_id] = link_to_nodes;
	}
	link_to_nodes.node_links.push({
	    source: node_dict[link.source_node_id],
	    target: node_dict[link.target_node_id],
	    value: link.value,
	});	
    });
    
    // create nodes and links
    let nodes = res.nodes.map((n) => n), links = [];
    for (let link_node_id in link_to_nodes_dict) {
	let link_to_nodes = link_to_nodes_dict[link_node_id];
	let link_node = {
	    node_id: link_to_nodes.id,
	    label: link_to_nodes.label,
	};
	nodes.push(link_node);
	link_to_nodes.node_links.forEach((link) => {
	    links.push({
		source_node_id: link.source.node_id,
		target_node_id: link_node.node_id,
		label: `${link.source.label} - ${link.target.label}: ${link_node.label}`,
		value: link.value,
	    });
	    links.push({
		source_node_id: link_node.node_id,
		target_node_id: link.target.node_id,
		label: `${link.source.label} - ${link.target.label}: ${link_node.label}`,
		value: link.value,
	    });
	});
    }
    let sankey_nodes = nodes.map((n, index) => {
	return { index, label: n.label, data: n };
    });
    let sankey_node_dict = {};    
    sankey_nodes.forEach((sn, index) => sankey_node_dict[sn.data.node_id] = sn);
    let sankey_links = links.map((l) => {
	let source_index = sankey_node_dict[l.source_node_id].index;
	let target_index = sankey_node_dict[l.target_node_id].index;
	return {
	    source: source_index,
	    target: target_index,
	    value: l.value,
	    label: l.label,
	};
    });
    return { nodes: sankey_nodes, links: sankey_links };
}

// remove all links with a not existing node
function make_complete_graph(graph) {
    let f_log_link = (l) => console.error(`link (source: ${l.source_node_id}, target: ${l.target_node_id}) removed for not existing source/target node`);    
    let links = get_links_with_existing_node(graph, f_log_link);
    return { nodes: graph.nodes, links };
}

// remeove all circular links and return a dag graph
function make_dag_graph(graph) {    
    let nodes_dest_dict = {}; // dictionary { [node_source_id]: nodes_target[] }
    graph.links.forEach((l) => {
	let nodes_dest = nodes_dest_dict[l.source_node_id];
	if (nodes_dest == null) {
	    nodes_dest = [];
	    nodes_dest_dict[l.source_node_id] = nodes_dest;
	}
	nodes_dest.push(l.target_node_id);
    });
    let nodes_to_check = {}; // temp dictionary used from f_add_circular_link 
    graph.nodes.forEach((n) => {
	nodes_to_check[n.node_id] = { checked: false, visited: false };
    });

    // circular links dict (key: `${source_node_id}_${target_node_id}`)
    let circular_links = {};
    let f_get_link_key = (source_id, target_id) => `${source_id}_${target_id}`;
    
    // deep navigate starting from node_id and add circular_links visited in circular_links dict 
    let f_set_circular_links = (node_id, from_node_id) => {
	let node_to_check = nodes_to_check[node_id];
	if (node_to_check.checked == true) { return; }
	else if (node_to_check.visited == true) {
	    let link_key = f_get_link_key(from_node_id, node_id);
	    circular_links[link_key] = true;
	    console.error(`Link (source: ${from_node_id}, target: ${node_id} ) is a circular link`);
	    node_to_check.visited = false;
	    return;
	}
	node_to_check.visited = true;
	let nodes_dest = nodes_dest_dict[node_id];
	if (nodes_dest != null) {
	    for (let i = 0; i < nodes_dest.length; i += 1) {
		let target_node_id = nodes_dest[i];
		f_set_circular_links(target_node_id, node_id);	    
	    }
	}
	node_to_check.visited = false;
	node_to_check.checked = true;
    };
    // set circular_links dictionary
    graph.nodes.forEach((n) => f_set_circular_links(n.node_id));
    
    // remove no dag nodes/links
    let f_filter_link = (l) => {
	let link_key = f_get_link_key(l.source_node_id, l.target_node_id);
	let take_link = circular_links[link_key] == null;
	return take_link;
    };
    let f_log_link = (l) => console.error(`link (source: ${l.source_node_id}, target: ${l.target_node_id}) removed for circular links`);
    let links = filter_log(graph.links, f_filter_link, f_log_link);
    
    let f_log_node = (n) => console.error(`node ${n.node_id} removed for circular links`);
    let nodes = get_nodes_with_existing_link({nodes: graph.nodes, links}, f_log_node);

    // return a dag graph
    return { nodes, links };
}

function get_links_with_existing_node(graph, f_log) {
    let node_dict = {};
    graph.nodes.forEach((n) => node_dict[n.node_id] = true);
    let f_filter = (l) => node_dict[l.source_node_id] != null && node_dict[l.target_node_id] != null;    
    let links = filter_log(graph.links, f_filter, f_log);
    return links;
}

function get_nodes_with_existing_link(graph, f_log) {
    let link_source_dict = {};
    let link_target_dict = {};
    graph.links.forEach((l) => {
	link_source_dict[l.source_node_id] = true;
	link_target_dict[l.target_node_id] = true;
    });
    let f_filter = (n) => link_source_dict[n.node_id] == true || link_target_dict[n.node_id] == true;
    let nodes = filter_log(graph.nodes, f_filter, f_log);
    return nodes;
}

// log elements deleted if f_log != null
function filter_log(elements, f_filter, f_log) {
    return elements.filter((e) => {
	const take_element = f_filter(e);
	if (take_element == false && f_log != null) {
	    f_log(e);
	}
	return take_element;
    });
}

function add_fake_circular_link(graph) {
    const node_id_0 = "node_id_0", node_id_1 = "node_id_1";
    graph.nodes.push({ node_id: node_id_0, label: node_id_0 });
    graph.nodes.push({ node_id: node_id_1, label: node_id_1 });
    graph.links.push({ source_node_id: node_id_0, target_node_id: node_id_1, value: 10, label: "${node_id_0}_${node_id_1}" });
    graph.links.push({ source_node_id: node_id_1, target_node_id: node_id_0, value: 10, label: "${node_id_1}_${node_id_0}" });
}

</script>






