--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
local hosts_stats = interface.getHostsInfo()
local num = hosts_stats["numHosts"]
hosts_stats = hosts_stats["hosts"]

if(num > 0) then
print [[

<style>


.node {
  border: solid 1px white;
  font: 10px sans-serif;
  line-height: 12px;
  overflow: hidden;
  position: absolute;
  text-indent: 2px;
}

</style>
<script src="http://d3js.org/d3.v3.min.js"></script>

<hr>
<h2>]] print(i18n("tree_map.hosts_treemap")) print[[</H2>
<div id='chart'></div>

<span class="row-fluid marketing">
<div class="span11">&nbsp;</div><div><small><A HREF="http://bl.ocks.org/mbostock/4063582"><i class="fa fa-question-sign fa-lg"></i></A></small></div>
</span>
<script>

   var margin = {top: 0, right: 0, bottom: 0, left: 0},
    width = 960 - margin.left - margin.right,
    height = 500 - margin.top - margin.bottom;

var color = d3.scale.category20c();

var treemap = d3.layout.treemap()
.size([width, height])
.sticky(true)
.value(function(d) { return d.size; });

       var div = d3.select("#chart").append("div")
       .style("position", "relative")
       .style("width", (width + margin.left + margin.right) + "px")
       .style("height", (height + margin.top + margin.bottom) + "px")
       .style("left", margin.left + "px")
       .style("top", margin.top + "px");

       d3.json("]]
print (ntop.getHttpPrefix())
print [[/lua/get_treemap.lua", function(error, root) {
				   var node = div.datum(root).selectAll(".node")
				   .data(treemap.nodes)
				   .enter().append("div")
				   .attr("class", "node")
				   .call(position)
				   .style("background", function(d) { return d.children ? color(d.name) : null; })
					  .html(function(d) {
						      if(d.children) return(null);
						   else {
							 if(d.name != "Other Hosts") {
							    return("<A HREF=\"]]
print (ntop.getHttpPrefix())
print [[/lua/host_details.lua?host="+d.name+"\">"+d.name+"</A>");
							 } else 
							 return(d.name);
						      }
						   });

						d3.selectAll("input").on("change", function change() {
    var value = this.value === "count"
											 ? function() { return 1; }
											      : function(d) { return d.size; };

												   node
												   .data(treemap.value(value).nodes)
												   .transition()
												   .duration(1500)
												   .call(position);
												});
											   });

					      function position() {
					    this.style("left", function(d) { return d.x + "px"; })
					       .style("top", function(d) { return d.y + "px"; })
					      .style("width", function(d) { return Math.max(0, d.dx - 1) + "px"; })
					     .style("height", function(d) { return Math.max(0, d.dy - 1) + "px"; });
				 }

</script>


]]
else 
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("no_results_found") .. "</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
