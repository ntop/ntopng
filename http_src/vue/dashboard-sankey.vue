<!--
  (C) 2023 - ntop.org
-->

<template>
<div ref="body_div">
  <Sankey
    ref="sankey_chart"
    :width="width"
    :height="height"
    :no_data_message="no_data_message"
    :sankey_data="sankey_data"
    @node_click="on_node_click">
  </Sankey> 
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";
import { default as Sankey } from "./sankey.vue";

const _i18n = (t) => i18n(t);
const no_data_message = _i18n('ports_analysis.no_data')

const sankey_chart = ref(null);
const sankey_data = ref({});
const body_div = ref(null);
const width = ref(null);
const height = ref(null);
const height_per_row = 62.5 /* px */

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    filters: Object
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    update_sankey();
}, { flush: 'pre', deep: true });

onBeforeMount(() => {
});

onMounted(() => {
    update_height();
    update_width();

    init();
});

function init() {
    update_sankey();
}

const update_sankey = function() {
  set_sankey_data();
}

async function set_sankey_data() {
    let data = await get_sankey_data();    
    sankey_data.value = data;
}

async function get_sankey_data() {
    const url = `${http_prefix}${props.params.url}`;

    const query_params = {
        ifid: props.ifid,
         epoch_begin: props.epoch_begin,
         epoch_end: props.epoch_end,
         sankey_version: 3,
         ...props.params.url_params,
        ...props.filters
    }

    let graph = await props.get_component_data(url, query_params, undefined, props.epoch_begin);

    graph = make_complete_graph(graph);

    const sankey_data = get_sankey_data_from_rest_data(graph);
    
    /* In case no data is returned, show the No Data message */
    (sankey_data.links.length > 0 && sankey_data.nodes.length > 0) ? 
        sankey_chart.value.set_no_data_flag(false) : 
        sankey_chart.value.set_no_data_flag(true);
  
    return sankey_data;
}

// remove all links with a not existing node
function make_complete_graph(graph) {
    let f_log_link = (l) => console.error(`link (source: ${l.source_node_id}, target: ${l.target_node_id}) removed for not existing source/target node`);    
    let links = get_links_with_existing_node(graph, f_log_link);
    return { nodes: graph.nodes, links };
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
    link: link.optional_info.link,
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
      link: link_to_nodes.link,
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

function on_node_click(node) {
    if (node.is_link_node == true) { return; }
    if (node.link) { ntopng_url_manager.go_to_url(node.link); }
}

function update_height() {
    height.value = height_per_row * props.max_height;
}

function update_width() {
    width.value = $(body_div.value).width();
}
</script>

<style>
</style>
