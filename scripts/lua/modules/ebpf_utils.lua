--
-- (C) 2017-21 - ntop.org
--
local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

local ntop_info = ntop.getInfo()

local os_utils = require "os_utils"

local ebpf_utils = {}

function ebpf_utils.draw_processes_graph(host_info)
   print[[

<div align="center" id="chart"></div>

<script>
draw_processes_graph(']] print(ntop.getHttpPrefix()) print[[',']] print("chart") print[[',']] print(hostinfo2hostkey(host_info)) print[[');
</script>
]]
end

function ebpf_utils.draw_flow_processes_graph(width, height, url)
   print [[
    <script type="text/javascript">

var m = [20, 120, 20, 120],
    w = ]] print(width) print[[ - m[1] - m[3],
    h = ]] print(height) print[[ - m[0] - m[2],
    i = 0,
    root;

var tree = d3.layout.tree()
    .size([h, w]);

var diagonal = d3.svg.diagonal()
    .projection(function(d) { return [d.y, d.x]; });

var vis = d3.select("#sprobe").append("svg:svg")
    .attr("width", w + m[1] + m[3])
    .attr("height", h + m[0] + m[2])
    .append("svg:g")
    .attr("transform", "translate(" + m[3] + "," + m[0] + ")");

function nodecolor(node) {
   var ret = "Burlywood";

  if(node == "host") ret = "lightsteelblue";
  else if(node == "proc") ret = "red";

  return(ret);
}

d3.json("]] print(url) print[[", function(json) {
  root = json;
  root.x0 = h / 2;
  root.y0 = 0;

  function toggleAll(d) {
    if (d.children) {
      d.children.forEach(toggleAll);
      toggle(d);
    }
  }

  // Initialize the display to show a few nodes.
//  root.children.forEach(toggleAll);

  sprobe_update(root);
});

function sprobe_update(source) {
  var duration = d3.event && d3.event.altKey ? 5000 : 500;

  // Compute the new tree layout.
  var nodes = tree.nodes(root).reverse();

  // Normalize for fixed-depth.
  nodes.forEach(function(d) { d.y = d.depth * 180; });

  // Update the nodes…
  var node = vis.selectAll("g.node")
      .data(nodes, function(d) { return d.id || (d.id = ++i); });

  // Enter any new nodes at the parent's previous position.
  var nodeEnter = node.enter().append("svg:g")
      .attr("class", "node")
      .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
      .on("click", function(d) {
		   if(d.link) {
		     window.location.href = d.link;
		   } else {
			   toggle(d);
			   update(d);
		    }
		   });

  nodeEnter.append("svg:circle")
      .attr("r", 1e-6)
      .style("fill", function(d) { return(nodecolor(d.type)); }
  );

  nodeEnter.append("svg:text")
      .attr("x", function(d) { return d.children || d._children ? -10 : 10; })
      .attr("dy", ".35em")
      .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
      .text(function(d) { return d.name; })
      .style("fill-opacity", 1e-6);

  // Transition nodes to their new position.
  var nodeUpdate = node.transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });

  nodeUpdate.select("circle")
      .attr("r", 4.5)
      .style("fill", function(d) { return(nodecolor(d.type)); }
  );

  nodeUpdate.select("text")
      .style("fill-opacity", 1);

  // Transition exiting nodes to the parent's new position.
  var nodeExit = node.exit().transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
      .remove();

  nodeExit.select("circle")
      .attr("r", 1e-6);

  nodeExit.select("text")
      .style("fill-opacity", 1e-6);

  // Update the links…
  var link = vis.selectAll("path.link")
      .data(tree.links(nodes), function(d) { return d.target.id; });

  // Enter any new links at the parent's previous position.
  link.enter().insert("svg:path", "g")
      .attr("class", "link")
      .attr("d", function(d) {
	var o = {x: source.x0, y: source.y0};
	return diagonal({source: o, target: o});
      })
    .transition()
      .duration(duration)
      .attr("d", diagonal);

  // Transition links to their new position.
  link.transition()
      .duration(duration)
      .attr("d", diagonal);

  // Transition exiting nodes to the parent's new position.
  link.exit().transition()
      .duration(duration)
      .attr("d", function(d) {
	var o = {x: source.x, y: source.y};
	return diagonal({source: o, target: o});
      })
      .remove();

  // Stash the old positions for transition.
  nodes.forEach(function(d) {
    d.x0 = d.x;
    d.y0 = d.y;
  });
}

// Toggle children.
function toggle(d) {
  if (d.children) {
    d._children = d.children;
    d.children = null;
  } else {
    d.children = d._children;
    d._children = null;
  }
}

    </script>

<div class="circle" style="background: lightsteelblue;"><div style="font-size: 11px; margin-left: 13px;">&nbsp;Host</div></div>
<p>
<div class="circle" style="background: #ff0000;"><div style="font-size: 11px; margin-left: 13px;">Process</div></div>

]]

end

function ebpf_utils.draw_ndpi_piecharts(ifstats, url, host_info, username, pid_name)
   local refresh_rate

   local have_nedge = ntop.isnEdge()
   if have_nedge then
      refresh_rate = 5
   else
      refresh_rate = getInterfaceRefreshRate(ifstats["id"])
   end

   print [[

  <table class="table table-bordered table-striped">
    <tr>
      <th class="text-start" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("protocol")})) print[[</th>
      <td>
	<div class="pie-chart" id="topApplicationProtocols"></div>
      </td>
      <td colspan=2>
	<div class="pie-chart" id="topApplicationBreeds"></div>
      </td>
    </tr>
    <tr>
      <th class="text-start" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("category")})) print[[</th>
      <td colspan=2>
	<div class="pie-chart" id="topApplicationCategories"></div>
      </td>
    </tr>
  </table>

	<script type='text/javascript'>
	       var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
	       window.onload=function() {]]

   print[[ do_pie("#topApplicationProtocols", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/]] print(url) print[[', { ebpf_data: "applications" ]]
   if host_info then print(", "..hostinfo2json(host_info)) end
   if username then print(", username: '"..username.."'") end
   if pid_name then print(", pid_name: '"..pid_name.."'") end
   print [[ }, "", refresh); ]]

   print[[ do_pie("#topApplicationCategories", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/]] print(url) print[[', { ebpf_data: "categories" ]]
   if host_info then print(", "..hostinfo2json(host_info)) end
   if username then print(", username: '"..username.."'") end
   if pid_name then print(", pid_name: '"..pid_name.."'") end
   print [[ }, "", refresh); ]]

   print[[do_pie("#topApplicationBreeds", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/]] print(url) print[[', { ebpf_data: "breeds" ]]
   if host_info then print(", "..hostinfo2json(host_info)) end
   if username then print(", username: '"..username.."'") end
   if pid_name then print(", pid_name: '"..pid_name.."'") end
   print [[ }, "", refresh);]]

   print[[
				}

	    </script>
]]
end

function ebpf_utils.draw_flows_datatable(ifstats, host_info, username, pid_name)
   print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_flows_data.lua?]]
   print(table.tconcat({username = username, pid_name = pid_name, host = hostinfo2hostkey(host_info)}, "=", "&"))
   print ('";')

   local show_vlan
   if ifstats.vlan then show_vlan = true else show_vlan = false end

   local active_flows_msg = i18n("flows_page.active_flows",{filter=""})
   if not interface.isPacketInterface() then
      active_flows_msg = i18n("flows_page.recently_active_flows",{filter=""})
   elseif interface.isPcapDumpInterface() then
      active_flows_msg = i18n("flows")
   end

   local dt_buttons = ''
   -- TODO: add application filter, etc.
   dt_buttons = "["..dt_buttons.."]"

   print [[
	 $("#table-flows").datatable({
	 url: url_update,
	 buttons: ]] print(dt_buttons) print[[,
	 tableCallback: function()  {
	 ]] initFlowsRefreshRows() print[[
	 },
	 showPagination: true,
	       ]]

   print('title: "'..active_flows_msg..'",')

   -- Set the preference table
   local preference = tablePreferences("rows_number", _GET["perPage"])
   if preference ~= "" then
      print ('perPage: '..preference.. ",\n")
   end

   print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

   print [[
		columns: [
	   {
	title: "Key",
	 field: "key",
	 hidden: true
	 }, {
			       field: "hash_id",
			       hidden: true,
			     },
			     {
			     title: "",
				 field: "column_key",
			     css: {
				textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("protocol")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }
				 },]]

   if show_vlan then

      if ifstats.vlan then
	 print('{ title: "'..i18n("vlan")..'",\n')
      end


      print [[
	 field: "column_vlan",
	 sortable: true,
		 css: {
	      textAlign: 'center'
	   }

	 },
]]
   end
   print [[
			     {
			     title: "]] print(i18n("client")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("server")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
			     css: {
				textAlign: 'center'
			       }
			       },
			     {
			     title: "]] print(i18n("breakdown")) print[[",
				 field: "column_breakdown",
				 sortable: true,
			     css: {
				textAlign: 'center'
			       }
			       },
			     {
			     title: "]] print(i18n("flows_page.actual_throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
			     css: {
				textAlign: 'right'
			     }
				 },
			     {
			     title: "]] print(i18n("flows_page.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
			     css: {
				textAlign: 'right'
			     }

				 }
			     ,{
			     title: "]] print(i18n("info")) print[[",
				 field: "column_info",
				 sortable: true,
			     css: {
				textAlign: 'left'
			     }
				 }
			     ]
	       });
]]

   if ntop.isnEdge() then
      printBlockFlowJs()
   end

   print[[
       </script>

   ]]
end

return ebpf_utils
