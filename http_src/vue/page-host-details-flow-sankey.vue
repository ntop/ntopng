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
        <div class="align-items-center justify-content-end mb-3" style="height: 70vh;">
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
	    @node_click="on_node_click"
	    :sankey_data="sankey_data">
          </Sankey2>
	</div>
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
import { default as sankeyUtils } from "../utilities/map/sankey_utils.js";

const props = defineProps({
  is_local: Boolean
});

const _i18n = (t) => i18n(t);
const url = `${http_prefix}/lua/pro/rest/v2/get/host/flows/data.lua`;

const sankey_format_list = [
    { filter_name: 'hosts_type', key: 3, id: 'local_origin_remote_target', title: _i18n('flows_page.local_cli_remote_srv'), label: _i18n('flows_page.local_cli_remote_srv'), filter_icon: false, countable: false },
    { filter_name: 'hosts_type', key: 4, id: 'remote_origin_local_target', title: _i18n('flows_page.local_srv_remote_cli'), label: _i18n('flows_page.local_srv_remote_cli'), filter_icon: false, countable: false },
    { filter_name: 'hosts_type', key: 5, id: 'all_hosts', title: _i18n('flows_page.all_flows'), label: _i18n('flows_page.all_flows'), filter_icon: false, countable: false },
];

if(props.is_local) {
  sankey_format_list.unshift({ filter_name: 'hosts_type', key: 1, id: 'local_only', title: _i18n('flows_page.local_only'), label: _i18n('flows_page.local_only'), filter_icon: false, countable: false })
} else {
  sankey_format_list.unshift({ filter_name: 'hosts_type', key: 2, id: 'remote_only', title: _i18n('flows_page.remote_only'), label: _i18n('flows_page.remote_only'),  filter_icon: false, countable: false })
}

const active_hosts_type = ref(sankey_format_list[0]);

const sankey_data = ref({});

onBeforeMount(() => {});

onMounted(() => { 
    update_sankey(active_hosts_type);
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
    //host=' .. flow["cli.ip"] .. '&vlan=' .. flow["vlan"]
    
    
    console.log(node);
}

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
    // let graph = await sankeyUtils.get_data();
    let graph = await ntopng_utility.http_request(url_request);
    console.log(graph);
    // add_fake_circular_link(graph);
    graph = make_complete_graph(graph);
    let main_node_id = get_main_node_id();
    let sankey_data = get_sankey_data_from_rest_data(graph, main_node_id);
    // sankey_data = make_dag_graph(sankey_data);
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

function get_main_node_id() {
    return ntopng_url_manager.get_url_entry("host");
}

function get_sankey_data_from_rest_data(graph, main_node_id) {
    if (graph.nodes.length == 0 && graph.links.length == 0) { return graph; }
    let node_dict = {};
    // create a node dict
    graph.nodes.forEach((node) => node_dict[node.node_id] = node);

    //get link direction 
    const f_get_link_direction = (link) => {
	if (link.source_node_id == main_node_id) {
	    return -1;
	} else if (link.target_node_id == main_node_id) {
	    return 1;
	}
	throw `Wrong direction link ${link.source_node_id} -> ${link.target_node_id}`;
    };

    // get node id with direction
    const f_get_node_direction_id = (node_id, direction) => {
	if (node_id == main_node_id) {
	    return node_id;
	}
	return `${direction}_${node_id}`; 
    };

    // create a new graph duplicating all nodes with different direction
    let graph2_node_dict = {};
    let graph2 = { nodes: [], links: [] };    
    graph.links.forEach((link) => {	
	let direction = f_get_link_direction(link);
	let new_link = {
	    source_node_id: f_get_node_direction_id(link.source_node_id, direction),
	    target_node_id: f_get_node_direction_id(link.target_node_id, direction),
	    label: link.label,
	    value: link.value,
	    data: link,
	};
	let new_node;
	if (direction == -1) {
	    let n = node_dict[link.target_node_id];
	    new_node = { node_id: new_link.target_node_id, label: n.label, data: n };
	} else {
	    let n = node_dict[link.source_node_id];
	    new_node = { node_id: new_link.source_node_id, label: n.label, data: n };
	}
	graph2.links.push(new_link);
	if (graph2_node_dict[new_node.node_id] == null) {
	    graph2_node_dict[new_node.node_id] = true;
	    graph2.nodes.push(new_node);
	}
    });
    let main_node = node_dict[main_node_id];
    graph2.nodes.push({node_id: main_node.node_id, label: main_node.label, data: main_node });

    // update node dict
    graph2.nodes.forEach((node) => node_dict[node.node_id] = node);
    
    // return the link node_id 
    const f_get_link_node_id = (link) => {
	let direction = f_get_link_direction(link);
	return `${direction}_${link.label}`; 
	// return `${link.source_node_id}_${link.label}`; 
    };

    let link_to_nodes_dict = {}; // key: link node id, value: links
    // merge all links by link node_id
    graph2.links.forEach((link) => {
	let link_node_id = f_get_link_node_id(link);
	let link_to_nodes = link_to_nodes_dict[link_node_id];
	if (link_to_nodes == null) {
	    link_to_nodes = {
		id: link_node_id,
		label: link.label,
		data: { ...link, is_link_node: true },
		node_links: [],
	    };
	    link_to_nodes_dict[link_node_id] = link_to_nodes;
	}
	link_to_nodes.node_links.push({
	    source: node_dict[link.source_node_id],
	    target: node_dict[link.target_node_id],
	    value: get_link_value(link),
	});
    });

    // create nodes and links graph, creating a new node for each link
    let nodes = graph2.nodes.map((n) => n), links = [];
    for (let link_node_id in link_to_nodes_dict) {
	let link_to_nodes = link_to_nodes_dict[link_node_id];
	let link_node = {
	    node_id: link_to_nodes.id,	    
	    label: link_to_nodes.label,
	    data: link_to_nodes.data,
	};
	nodes.push(link_node);
	link_to_nodes.node_links.forEach((link) => {
	    links.push({
		source_node_id: link.source.node_id,
		target_node_id: link_node.node_id,
		label: `${link.source.label} - ${link.target.label}: ${link_node.label}`,
		value: link.value,
		data: link,
	    });
	    links.push({
		source_node_id: link_node.node_id,
		target_node_id: link.target.node_id,
		label: `${link.source.label} - ${link.target.label}: ${link_node.label}`,
		value: link.value,
		data: link,
	    });
	});
    }

    let sankey_node_dict = {}; // key: node_id, value: sankey_node
    let sankey_nodes = [];
    nodes.map((n, index) => {
	let sankey_node = { index, node_id: n.node_id, label: n.label, data: n.data };
	sankey_node_dict[n.node_id] = sankey_node;
	sankey_nodes.push(sankey_node);
    });
    let sankey_links = links.map((l) => {
	let source = sankey_node_dict[l.source_node_id];
	let target = sankey_node_dict[l.target_node_id];
	return {
	    source: source.index,
	    target: target.index,
	    source_node_id: source.index,
	    target_node_id: target.index,
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

function get_link_value(link) {
    return link.data?.info?.traffic;
}

</script>






