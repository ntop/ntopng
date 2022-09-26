<!-- (C) 2022 - ntop.org     -->
<template>
  <div id="my_dataviz">
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, watch } from "vue";
import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
});

onBeforeMount(async() => {
    
    
});

let d3 = d3v7;
onMounted(async () => {
    // set the dimensions and margins of the graph
    var margin = {top: 10, right: 10, bottom: 10, left: 10},
	width = 450 - margin.left - margin.right,
	height = 480 - margin.top - margin.bottom;
    
    // append the svg object to the body of the page
    var svg = d3.select("#my_dataviz").append("svg")
	.attr("width", width + margin.left + margin.right)
	.attr("height", height + margin.top + margin.bottom)
	.append("g")
	.attr("transform",
              "translate(" + margin.left + "," + margin.top + ")");
    
    let graph = {
	"nodes":[
	    {"node":0,"name":"node0"},
	    {"node":1,"name":"node1"},
	    {"node":2,"name":"node2"},
	    {"node":3,"name":"node3"},
	    {"node":4,"name":"node4"}
	],
	"links":[
	    {"source":0,"target":2,"value":2},
	    {"source":1,"target":2,"value":2},
	    {"source":1,"target":3,"value":2},
	    {"source":0,"target":4,"value":2},
	    {"source":2,"target":3,"value":2},
	    {"source":2,"target":4,"value":2},
	    {"source":3,"target":4,"value":4}
	]
    };
    console.log(graph);    
    
    // svg.append("g")
    // 	.attr("fill", "none")
    // 	.attr("stroke", "#000")
    // 	.attr("stroke-opacity", 0.2)
    // 	.selectAll("path")
    // 	.data(graph.links)
    // 	.join("path")
    // 	.attr("d", d3.sankeyLinkHorizontal())
    // 	.attr("stroke-width", function(d) { return d.width; });
    // return;


    // Color scale used
    var color = d3.scaleOrdinal(d3.schemeCategory10);
    
    // Set the sankey diagram properties
    var sankey = d3.sankey()
	.nodeWidth(36)
	.nodePadding(290)
	.size([width, height]);
    
    // load the data
    // let graph = await ntopng_utility.http_request("https://raw.githubusercontent.com/holtzy/D3-graph-gallery/master/DATA/data_sankey.json");
    // return;
    // Constructs a new Sankey generator with the default settings.
    sankey
	.nodes(graph.nodes)
	.links(graph.links)
    // .extent([0,0], [1000, 1000]);
    
    
    // add in the links
    var link = svg.append("g")
	.selectAll(".link")
	.data(graph.links)
	.enter()
	.append("path")
	.attr("class", "link")
	// .attr("d", sankey.link() )
	.style("stroke-width", function(d) { return Math.max(1, d.dy); })
	.sort(function(a, b) { return b.dy - a.dy; });
    
    // add in the nodes
    var node = svg.append("g")
	.selectAll(".node")
	.data(graph.nodes)
	.enter().append("g")
	.attr("class", "node")
	.attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })
	.call(d3.drag()
	      .subject(function(d) { return d; })
	      .on("start", function() { this.parentNode.appendChild(this); })
	      .on("drag", dragmove));
    
    // add the rectangles for the nodes
    node
	.append("rect")
	.attr("height", function(d) { return d.dy; })
	.attr("width", sankey.nodeWidth())
	.style("fill", function(d) { return d.color = color(d.name.replace(/ .*/, "")); })
	.style("stroke", function(d) { return d3.rgb(d.color).darker(2); })
    // Add hover text
	.append("title")
	.text(function(d) { return d.name + "\n" + "There is " + d.value + " stuff in this node"; });
    
    // add in the title for the nodes
    node
	.append("text")
        .attr("x", -6)
        .attr("y", function(d) { return d.dy / 2; })
        .attr("dy", ".35em")
        .attr("text-anchor", "end")
        .attr("transform", null)
        .text(function(d) { return d.name; })
	.filter(function(d) { return d.x < width / 2; })
        .attr("x", 6 + sankey.nodeWidth())
        .attr("text-anchor", "start");
    
    // the function for moving the nodes
    function dragmove(d) {
	d3.select(this)
	    .attr("transform",
		  "translate("
		  + d.x + ","
		  + (d.y = Math.max(
		      0, Math.min(height - d.dy, d3.event.y))
		    ) + ")");
	sankey.relayout();
	link.attr("d", sankey.link() );
    }	
});

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
