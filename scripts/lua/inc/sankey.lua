--
-- (C) 2014-15 - ntop.org
--

_ifstats = interface.getStats()

print [[

<div id = "alert_placeholder"></div>

<style>

.node rect {
  cursor: move;
  fill-opacity: .9;
  shape-rendering: crispEdges;
}

.node text {
  pointer-events: none;
  text-shadow: 0 1px 0 #fff;
}

.link {
  fill: none;
  stroke: #000;
  stroke-opacity: .2;
}

.link:hover {
  stroke-opacity: .5;
}

</style>

<div id="chart" style="margin-left: auto; margin-right: auto;"></div>
<script src="]] print(ntop.getHttpPrefix()) print[[/js/sankey.js"></script>

<script>
]]
-- Create javascript vlan boolean variable
if (_ifstats.iface_vlan) then print("var iface_vlan = true;") else print("var iface_vlan = false;") end

print [[

var sankey_has_chart = false;

function sankey() {

  var w = $("#chart").width();
  var h = window.innerHeight / 2;

  var margin = {top: 1, right: 10, bottom: 1, left: 10},
      width = w - margin.left - margin.right,
      height = h - margin.top - margin.bottom;

  var formatNumber = d3.format(",.0f"),
    format = function(sent, rcvd) { return "[sent: " + bytesToVolume(sent) + ", rcvd: " + bytesToVolume(rcvd)+"]"; },
    color = d3.scale.category20();

]]
-- Default value
active_sankey = "host"
local debug = false

if(_GET["sprobe"] ~= nil) then
   print('d3.json("'..ntop.getHttpPrefix()..'/lua/sprobe_hosts_data.lua"');
else
   if(_GET["host"] ~= nil) then
      print('d3.json("'..ntop.getHttpPrefix()..'/lua/iface_flows_sankey.lua?ifid='..(_ifstats.id)..'&' ..hostinfo2url(hostkey2hostinfo(_GET["host"])).. '"')
   elseif((_GET["hosts"] ~= nil) and (_GET["aggregation"] ~= nil)) then
      print('d3.json("'..ntop.getHttpPrefix()..'/lua/hosts_comparison_sankey.lua?ifid='..(_ifstats.id)..'&'..'hosts='.._GET["hosts"] .. '&aggregation='.._GET["aggregation"] ..'"')
      active_sankey = "comparison"
   elseif(_GET["hosts"] ~= nil) then
      print('d3.json("'..ntop.getHttpPrefix()..'/lua/hosts_comparison_sankey.lua?ifid='..(_ifstats.id)..'&'..'hosts='.._GET["hosts"] ..'"')
      active_sankey = "comparison"
   else
      print('d3.json("'..ntop.getHttpPrefix()..'/lua/iface_flows_sankey.lua"')
   end
end

if (debug) then io.write("Active sankey: "..active_sankey.."\n") end

print [[
    , function(hosts) {

    if ((hosts.links.length == 0) && (hosts.nodes.length == 0)) {
      if(! sankey_has_chart)
	$('#alert_placeholder').html('<div class="alert alert-warning"><button type="button" class="close" data-dismiss="alert">x</button><strong>Warning: </strong>]] print(i18n("no_talkers_for_the_host")) print[[.</div>');
      return;
    }

  $('#alert_placeholder').html("");
  d3.select("#chart").select("svg").remove();
  sankey_has_chart = true;

  var svg_sankey = d3.select("#chart").append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  var sankey = d3.sankey()
    .nodeWidth(15)
    .nodePadding(10)
    .size([width, height]);

  var path = sankey.link();
  sankey
    .nodes(hosts.nodes)
    .links(hosts.links)
    .layout(32);

]]


if (active_sankey == "host") then

print [[

  /* Color the link according to traffic prevalence */
  var colorlink = function(d){
    if (d.sent > d.rcvd) return color(d.source.name);
    else return color(d.target.name);
  }

     var link = svg_sankey.append("g").selectAll(".link")
	  .data(hosts.links)
	  .enter().append("path")
	  .attr("class", "link")
	  .attr("d", path)
	  .style("stroke-width", function(d) { return Math.max(1, d.dy); })
	  .style("stroke", function(d){ return d.color = colorlink(d); })
	  .sort(function(a, b) { return b.dy - a.dy; })
    .on("dblclick", function(d) {
        url_ref = "]]
print (ntop.getHttpPrefix())
print [[/lua/hosts_comparison.lua?hosts="+escape(d.source.host);

        if(iface_vlan )
          url_ref  += "@"+escape(d.source.vlan);

        url_ref += ","+escape(d.target.host);

        if(iface_vlan )
          url_ref  += "@"+escape(d.target.vlan);

          window.location.href = url_ref;
      });

	link.append("title")
	  .text(function(d) { return d.source.name + " - " + d.target.name + "\n" + format(d.sent, d.rcvd) + "\n Double click to show more information about the flows between this two host." ; });

	var node = svg_sankey.append("g").selectAll(".node")
	  .data(hosts.nodes)
	  .enter().append("g")
	  .attr("class", "node")
	  .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })
	  .call(d3.behavior.drag()
		.origin(function(d) { return d; })
		.on("dragstart", function() { this.parentNode.appendChild(this); })
		.on("drag", dragmove));


	node.append("rect")
	  .attr("height", function(d) { return d.dy; })
	  .attr("width", sankey.nodeWidth())
	  .style("fill", function(d) { return d.color = color(d.name.replace(/ .*/, "")); })
	  .style("stroke", function(d) { return d3.rgb(d.color).darker(2); })
	  .append("title")
	  .text(function(d) { return d.name + "\n" + format(d.value); });

	/* Hook for clicking on host name */
	node.append("rect")
	  .attr("x", -4 -100)
	  .attr("y", function(d) { return (d.dy/2)-7; })
	  .attr("height", 12)
	  .attr("width", 150)
	  .style("opacity", "0")
	  .on("click", function(d) { window.location.href = "]]
print (ntop.getHttpPrefix())
print [[/lua/host_details.lua?host="+escape(d.host)+"@"+escape(d.vlan);  })
	  .attr("transform", null)
	  .filter(function(d) { return d.x < width / 2; })
	  .attr("x", 4 + sankey.nodeWidth())
	  .append("title")
	  .text(function(d) { return "Host: " + d.host + "\nVlan: " + d.vlan});

	node.append("text")
	  .attr("x", -6)
	  .attr("y", function(d) { return d.dy / 2; })
	  .attr("dy", ".35em")
	  .attr("text-anchor", "end")
	  .attr("transform", null)
	  .text(function(d) { return (d.name); })
	  .filter(function(d) { return d.x < width / 2; })
	  .attr("x", 6 + sankey.nodeWidth())
	  .attr("text-anchor", "start");
    ]]


elseif(active_sankey == "comparison") then

_ifstats = interface.getStats()

if(_ifstats.iface_sprobe) then
   url = ntop.getHttpPrefix().."/lua/sflows_stats.lua?"
else
   url = ntop.getHttpPrefix().."/lua/flows_stats.lua?"
end

print [[

  /* Color the link according to traffic volume */
  var colorlink = function(d){
    return color(d.value);
  }

  var aggregation_to_param = {
    l4proto: "application",
    ndpi: "application",
    port: "port",
  };

  var link = svg_sankey.append("g").selectAll(".link")
    .data(hosts.links)
    .enter().append("path")
    .attr("class", "link")
    .attr("d", path)
    .style("stroke-width", function(d) { return Math.max(1, d.dy); })
    .style("stroke", function(d){ return d.color = colorlink(d); })
    .sort(function(a, b) { return b.dy - a.dy; })
   .on("dblclick", function(d) { window.location.href = "]]

print(url.."hosts=".._GET["hosts"])

  print [[&aggregation="+escape(d.aggregation)+"&"+aggregation_to_param[d.aggregation]+"="+escape(d.target.name) ;  });


  link.append("title")
    .text(function(d) { return d.source.name + " - " + d.target.name + "\n" + bytesToVolume(d.value)+ "\n Double click to show more information about this flows." ; });

  var node = svg_sankey.append("g").selectAll(".node")
    .data(hosts.nodes)
    .enter().append("g")
    .attr("class", "node")
    .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })
    .call(d3.behavior.drag()
    .origin(function(d) { return d; })
    .on("dragstart", function() { this.parentNode.appendChild(this); })
    .on("drag", dragmove));


  node.append("rect")
    .attr("height", function(d) { return d.dy; })
    .attr("width", sankey.nodeWidth())
    .style("fill", function(d) { return d.color = color(d.name.replace(/ .*/, "")); })
    .style("stroke", function(d) { return d3.rgb(d.color).darker(2); })
    .append("title")
    .text(function(d) {
        return (d.name);
      });

  /* Hook for clicking on host name */
  node.append("rect")
    .attr("x", -4 -100)
    .attr("y", function(d) { return (d.dy/2)-7; })
    .attr("height", 12)
    .attr("width", 150)
    .style("opacity", "0")
    .attr("transform", null)
    .filter(function(d) { return d.x < width / 2; })
    .attr("x", 4 + sankey.nodeWidth())
    .append("title")
    .text(function(d) { return "Ip: " + d.ip + " Vlan: " + d.vlan});

  node.append("text")
    .attr("x", -6)
    .attr("y", function(d) { return d.dy / 2; })
    .attr("dy", ".35em")
    .attr("text-anchor", "end")
    .attr("transform", null)
    .text(function(d) {
        return (d.name);
     })
    .filter(function(d) { return d.x < width / 2; })
    .attr("x", 6 + sankey.nodeWidth())
    .attr("text-anchor", "start");

    ]]
end


print [[
  function dragmove(d) {
    d3.select(this).attr("transform", "translate(" + d.x + "," + (d.y = Math.max(0, Math.min(height - d.dy, d3.event.y))) + ")");
    sankey.relayout();
    link.attr("d", path);
  }
 });
}

sankey();

// Refresh every 5 seconds
var sankey_interval = window.setInterval(sankey, 5000);

</script>]]

