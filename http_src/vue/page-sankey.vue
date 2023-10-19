<!-- (C) 2022 - ntop.org     -->
<template>
<div>
  <svg
    ref="sankey_chart_ref"
    :width="sankey_size.width"
    :height="sankey_size.height"
    style="margin:10px;">
    <defs />
    <g class="nodes" style="stroke: #000;strokeOpacity: 0.5;"/>
    <g class="links"
       style="stroke: #000;strokeOpacity: 0.3; fill: none;"/>
    <g class="texts" />
  </svg>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, watch } from "vue";
import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";

const d3 = d3v7;

const props = defineProps({
    width: Number,
    height: Number,
});

const sankey_chart_ref = ref(null);
const sankey_size = ref({});

onBeforeMount(async() => {});

onMounted(async () => {    
    draw_sankey();
});

async function draw_sankey() {
    const colors = d3.scaleOrdinal(d3.schemeCategory10);
    let data = await get_sankey_data();
    const size = get_size();
    sankey_size.value = size;
    const { links, nodes } = calculate_sankey(data, size.width - 10, size.height - 5);
    
    d3.select(sankey_chart_ref.value)
	.select("g.nodes")
	.selectAll("rect")
	.data(nodes)
	.join(
            (enter) => {
		const e = enter.append("rect");
		
		e.attr("x", (d) => d.x0).attr("y", (d) => d.y0);
		
		e.transition(d3.easeLinear)
		    .delay(1000)
		    .duration(500)
		    .attr("height", (d) => d.y1 - d.y0)
		    .attr("width", (d) => d.x1 - d.x0)
		    .attr("dataIndex", (d) => d.index)
		    .attr("fill", (d) => colors(d.index / nodes.length));
		e.append("title").text((d) => `${d.name}\n${d.hours}`);
            },
            (update) =>
		update
		.transition(d3.easeLinear)
		.delay(500)
		.duration(500)
		.attr("x", (d) => d.x0)
		.attr("y", (d) => d.y0)
		.attr("height", (d) => d.y1 - d.y0)
		.attr("width", (d) => d.x1 - d.x0)
		.attr("dataIndex", (d) => d.index)
		.attr("fill", (d) => colors(d.index / nodes.length))
		.select("title")
		.text((d) => `${d.name}\n${d.hours}`),
            (exit) =>
		exit.transition(d3.easeLinear).duration(500).style("opacity", 0).remove()
	).on("dblclick", function(data) {
	    //todo portare fuori
	    // data = data.currentTarget.__data__
	    // const sourceLink = data.sourceLinks;
	    // const targetLink = data.targetLinks;
	    // const link = (sourceLink && sourceLink[0]) ? sourceLink[0] : targetLink[0];
	    
	    // if(link) {
	    //   /* Get the node link from the rest */
	    //   if(link.source.id === data.id) {
	    //     if(link.source_link && link.source_link !== '')
	    //       window.open(link.source_link, '_blank');
	    //   } else if(link.target.id === data.id) {
	    //     if(link.target_link && link.target_link !== '')
	    //       window.open(link.target_link, '_blank');
	    //   } 
	    // } 
	});
    
    d3.select(sankey_chart_ref.value)
	.select("g.texts")
	.selectAll("text")
	.data(nodes)
	.join(
            (enter) => {
		const e = enter.append("text");
		
		e.transition(d3.easeLinear)
		    .delay(1000)
		    .duration(500)
		    .attr("x", (d) => (d.x0 < size.width / 2 ? d.x1 + 6 : d.x0 - 6))
		    .attr("y", (d) => (d.y1 + d.y0) / 2)
		    .attr("fill", (d) => d3.rgb(colors(d.index / nodes.length)).darker())
		    .attr("alignment-baseline", "middle")
		    .attr("text-anchor", (d) =>
			  d.x0 < size.width / 2 ? "start" : "end"
			 )
		    .attr("font-size", 9)
		    .text((d) => d.name);
            },
            (update) =>
		update
		.transition(d3.easeLinear)
		.delay(500)
		.duration(500)
		.attr("x", (d) => (d.x0 < size.width / 2 ? d.x1 + 6 : d.x0 - 6))
		.attr("y", (d) => (d.y1 + d.y0) / 2)
		.attr("fill", (d) => d3.rgb(colors(d.index / nodes.length)).darker())
		.attr("text-anchor", (d) =>
		      d.x0 < size.width / 2 ? "start" : "end"
		     )
		.attr("font-size", 9)
		.text((d) => d.name),
            (exit) =>
		exit
		.transition(d3.easeLinear)
            /* .delay(500) */
		.duration(500)
		.style("opacity", 0)
		.remove()
	);
    
    d3.select(sankey_chart_ref.value)
	.select("defs")
	.selectAll("linearGradient")
	.data(links)
	.join(
            (enter) => {
		const lg = enter.append("linearGradient");
		
		lg.attr("id", (d) => `gradient-${d.index}`)
		    .attr("gradientUnits", "userSpaceOnUse")
		    .attr("x1", (d) => d.source.x1)
		    .attr("x2", (d) => d.target.x0);
		
		lg.append("stop")
		    .attr("offset", "0")
		    .attr("stop-color", (d) => colors(d.source.index / nodes.length));
		
		lg.append("stop")
		    .attr("offset", "100%")
		    .attr("stop-color", (d) => colors(d.target.index / nodes.length));
            },
            (update) => {
		update
		    .attr("id", (d) => `gradient-${d.index}`)
		    .attr("gradientUnits", "userSpaceOnUse")
		    .attr("x1", (d) => d.source.x1)
		    .attr("x2", (d) => d.target.x0);
		update.selectAll("stop").remove();
		update
		    .append("stop")
		    .attr("offset", "0")
		    .attr("stop-color", (d) => colors(d.source.index / nodes.length));
		
		update
		    .append("stop")
		    .attr("offset", "100%")
		    .attr("stop-color", (d) => colors(d.target.index / nodes.length));
            },
            (exit) => exit.remove()
	);
    
    d3.select(sankey_chart_ref.value)
	.select("g.links")
	.selectAll("path")
	.data(links)
	.join(
            (enter) => {
		const e = enter.append("path");
		e.transition(d3.easeLinear)
		    .delay(1000)
		    .duration(500)
		    .attr("d", d3.sankeyLinkHorizontal())
		    .attr("stroke", (d) => `url(#gradient-${d.index}`)
		    .attr("stroke-width", (d) => d.width);
		e.append("title").text((d) => `${d.hours}`);
            },
            (update) =>
		update
		.transition(d3.easeLinear)
		.delay(500)
		.duration(500)
		.attr("d", d3.sankeyLinkHorizontal())
		.attr("stroke", (d) => `url(#gradient-${d.index}`)
		.attr("stroke-width", (d) => d.width)
		.select("title")
		.text((d) => `${d.hours}`),
            (exit) =>
		exit
		.transition(d3.easeLinear)
            /* .delay(1000) */
		.duration(500)
		.style("opacity", 0)
		.remove()
	);
}

async function get_sankey_data() {
    const rsp = [
	{
	    "link_color": "#e377c2",
	    "source_color": "#e377c2",
	    "source_link": "/lua/host_details.lua?page=flows&host=192.168.1.7&vlan=0&application=IGMP",
	    "target": "224.0.0.251",
	    "source": "IGMP",
	    "link": "IGMP",
	    "target_link": "/lua/host_details.lua?host=224.0.0.251&vlan=0",
	    "target_node": "224.0.0.251",
	    "source_node": "192.168.1.7",
	    "value": 60
	},
	{
	    "link_color": "#e377c2",
	    "source_link": "/lua/host_details.lua?host=192.168.1.7&vlan=0",
	    "target": "IGMP",
	    "source": "192.168.1.7",
	    "link": "IGMP",
	    "target_link": "/lua/host_details.lua?page=flows&host=192.168.1.7&vlan=0&application=IGMP",
	    "target_node": "224.0.0.2",
	    "target_color": "#e377c2",
	    "source_node": "192.168.1.7",
	    "value": 120
	},
	{
	    "link_color": "#e377c2",
	    "source_color": "#e377c2",
	    "source_link": "/lua/host_details.lua?page=flows&host=192.168.1.7&vlan=0&application=IGMP",
	    "target": "224.0.0.2",
	    "source": "IGMP",
	    "link": "IGMP",
	    "target_link": "/lua/host_details.lua?host=224.0.0.2&vlan=0",
	    "target_node": "224.0.0.2",
	    "source_node": "192.168.1.7",
	    "value": 60
	},
	{
	    "link_color": "#bcbd22",
	    "source_link": "/lua/host_details.lua?host=192.168.1.7&vlan=0",
	    "target": "MDNS",
	    "source": "192.168.1.7",
	    "link": "MDNS",
	    "target_link": "/lua/host_details.lua?page=flows&host=192.168.1.7&vlan=0&application=MDNS",
	    "target_node": "224.0.0.251",
	    "target_color": "#bcbd22",
	    "source_node": "192.168.1.7",
	    "value": 396
	},
	{
	    "link_color": "#bcbd22",
	    "source_color": "#bcbd22",
	    "source_link": "/lua/host_details.lua?page=flows&host=192.168.1.7&vlan=0&application=MDNS",
	    "target": "224.0.0.251",
	    "source": "MDNS",
	    "link": "MDNS",
	    "target_link": "/lua/host_details.lua?host=224.0.0.251&vlan=0",
	    "target_node": "224.0.0.251",
	    "source_node": "192.168.1.7",
	    "value": 396
	}
    ];
    
/*
    let data = {
	// nodes: [
	//     { index: 0, name: "Liikevaihto", value: 100, hours: "100%" },
	//     { index: 1, name: "Kiinteät kulut", value: 75, hours: "85%" },
	//     { index: 2, name: "Muuttuvat kulut", value: 10, hours: "3:00" },
	//     { index: 3, name: "Palkkakulut", value: 69, hours: "1:20" },
	//     { index: 4, name: "Muut kiinte", value: 6, hours: "1:40" },
	//     { index: 5, name: "Kate", value: 15, hours: "1:40" }
	// ],
	nodes: [
	    { index: 0, name: "Liikevaihto", hours: "100%" },
	    { index: 1, name: "Kiinteät kulut", hours: "85%" },
	    { index: 2, name: "Muuttuvat kulut", hours: "3:00" },
	    { index: 3, name: "Palkkakulut", hours: "1:20" },
	    { index: 4, name: "Muut kiinte", hours: "1:40" },
	    { index: 5, name: "Kate", hours: "1:40" }
	],
	links: [
	    { source: 0, target: 1, value: 75, hours: "+1:00" },
	    { source: 0, target: 2, value: 10, hours: "+2:00" },
	    { source: 1, target: 3, value: 69, hours: "+1:20" },
	    { source: 1, target: 4, value: 6, hours: "+1:40" },
	    { source: 0, target: 5, value: 15, hours: "+1:40" }
	]
    };
*/
    data = wrap_graph_rsp(rsp);

    //debugger;
    return data;
}

function wrap_graph_rsp(rsp) {
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
    rsp.forEach((el) => {
	f_add_node(el.source, el.source_link, el.source_color);
	f_add_node(el.target, el.target_link, el.target_color);
	f_add_link(el.source, el.target, el.value, el.link);
    });
    return { nodes, links };
}

function get_size() {
    let width = props.width;
    if (width == null) { width = window.innerWidth - 200; }
    let height = props.height;
    if (height == null) { height = window.innerHeight - 50; }

    return { width, height };
}

function calculate_sankey(data, width, height) {
    const sankeyimpl = d3.sankey()
	  .nodeAlign(d3.sankeyCenter)
	  .nodeWidth(10)
	  .nodePadding(10)
	  .extent([
	      [0, 5],
	      [width, height]
	  ]);
    
    return sankeyimpl(data);
}

const _i18n = (t) => i18n(t);

</script>

<style>
.node rect {
  fill-opacity: 0.9;
  shape-rendering: crispEdges;
}

.node text {
  pointer-events: none;
  text-shadow: 0 1px 0 #fff;
}

.link {
  fill: none;
  stroke: #000;
  stroke-opacity: 0.2;
}

.link:hover {
  stroke-opacity: 0.5;
}
</style>
