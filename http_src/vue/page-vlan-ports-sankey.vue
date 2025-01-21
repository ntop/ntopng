<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card card-shadow">
      <Loading v-if="loading"></Loading>
      <div class="card-body">
        <div class="align-items-center justify-content-end mb-2" :class="[loading ? 'ntopng-gray-out' : '']" style="height: 70vh;" ref="body_div">
          <div class="d-flex align-items-center flex-row-reverse mb-2">
            <div>
              <label class="my-auto me-1"></label>
              <div>
                <button class="btn btn-link m-1" tabindex="0" type="button" @click="reload">
                  <span><i class="fas fa-sync"></i></span>
                </button>
              </div>
            </div>
            <template v-for="(value, key, index) in available_filters">
              <div class="m-1" v-if="value.length > 0">
                <div style="min-width: 14rem;">
                  <label class="my-auto me-1">{{ _i18n('server_ports.' + key) }}: </label>
                  <SelectSearch
                    v-model:selected_option="active_filter_list[key]"
                    :options="value"
                    @select_option="click_item">
                  </SelectSearch>
                </div>
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

          <Sankey
          ref="sankey_chart"
          :width="width"
          :height="height"
          :no_data_message="no_data_message"
          :sankey_data="sankey_data"
          @update_width="update_width"
          @update_height="update_height"
          @node_click="on_node_click">
          </Sankey>        
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

const active_filter_list = {}
const props = defineProps({
  ifid: Number,
  available_filters: Object,
});

const _i18n = (t) => i18n(t);
const max_entries_reached = ref(false)
const max_entry_title = _i18n('ports_analysis.max_entries')
const no_data_message = _i18n('ports_analysis.no_data')
const sankey_chart = ref(null)
const body_div = ref(null);
const width = ref(null);
const height = ref(null);
const sankey_data = ref({});
const live_rest = `${http_prefix}/lua/pro/rest/v2/get/vlan/live_ports.lua`
const historical_rest = `${http_prefix}/lua/pro/rest/v2/get/vlan/historical_ports.lua`
const loading = ref(false)

onBeforeMount(() => {
  /* Before mounting the various widgets, update the url to the correct one, by adding ifid, ecc. */
  const timeframe = ntopng_url_manager.get_url_entry('timeframe');
  const vlan = ntopng_url_manager.get_url_entry('vlan');
  const l4_proto = ntopng_url_manager.get_url_entry('l4proto');
  
  if(!timeframe) ntopng_url_manager.set_key_to_url('timeframe', 'none') /* Default live */
  if(!vlan) ntopng_url_manager.set_key_to_url('vlan', 'none') /* Default all VLANs */
  if(!vlan) ntopng_url_manager.set_key_to_url('l4proto', 'none') /* Default no protocol */
  
  ntopng_url_manager.set_key_to_url('ifid', props.ifid) /* Current interface */

  for(const [name, filters] of Object.entries(props.available_filters)) {
    filters.forEach((filter) => {
      filter.filter_name = name
      if(filter.currently_active)
        active_filter_list[name] = filter;
    })
  }
});

onMounted(() => {
  update_height();
  update_width();
  update_sankey();
});

function on_node_click(node) {
  if (node.is_link_node == true) { return; }
  if (node.link) { ntopng_url_manager.go_to_url(node.link); }
}

const reload = function() {
  update_sankey()
}

const click_item = function(item) {
  ntopng_url_manager.set_key_to_url(item.filter_name, item.id)
  update_sankey();
}

const update_sankey = function() {
  set_sankey_data();
}

function check_max_entries(data) {
  max_entries_reached.value = data.max_entries_reached
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
  check_max_entries(graph);
  graph = make_complete_graph(graph);
  const sankey_data = get_sankey_data_from_rest_data(graph);
  /* In case no data is returned, show the No Data message */
  (sankey_data.links.length > 0 && sankey_data.nodes.length > 0) ? 
    sankey_chart.value.set_no_data_flag(false) : 
    sankey_chart.value.set_no_data_flag(true);
  
  
  return sankey_data;
}

function get_sankey_url() {
  let vlan = ntopng_url_manager.get_url_entry("vlan");
  let timeframe = ntopng_url_manager.get_url_entry("timeframe");
  let l4proto = ntopng_url_manager.get_url_entry("l4proto");
  if(vlan == 'none') { vlan = ''; }
  if(timeframe == 'none') { timeframe = ''; }
  if(l4proto == 'none') { l4proto = ''; }
  
  let url_request = '';
  let params = {
    ifid: ntopng_url_manager.get_url_entry("ifid"),
    vlan: vlan,
    timeframe: timeframe,
    l4proto: l4proto
  };
  let url_params = ntopng_url_manager.obj_to_url_params(params);

  if(timeframe == '') { url_request = `${live_rest}?${url_params}`; }
  else { url_request = `${historical_rest}?${url_params}`; }

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

function update_height() {
  height.value = $(body_div.value).height() - 100;
}

function update_width() {
  width.value = $(body_div.value).width() - 10;
}

</script>






