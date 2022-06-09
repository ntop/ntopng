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



<div class="container">
    <div class="row">
	<div class="col-12">
          <div id="chart" style="margin-left: auto; margin-right: auto;"></div>
	</div>
     </div>
</div>

<script type="text/javascript">
d3.sankey = function() {
  var sankey = {},
      nodeWidth = 24,
      nodePadding = 8,
      size = [1, 1],
      nodes = [],
      links = [];

  sankey.nodeWidth = function(_) {
    if (!arguments.length) return nodeWidth;
    nodeWidth = +_;
    return sankey;
  };

  sankey.nodePadding = function(_) {
    if (!arguments.length) return nodePadding;
    nodePadding = +_;
    return sankey;
  };

  sankey.nodes = function(_) {
    if (!arguments.length) return nodes;
    nodes = _;
    return sankey;
  };

  sankey.links = function(_) {
    if (!arguments.length) return links;
    links = _;
    return sankey;
  };

  sankey.size = function(_) {
    if (!arguments.length) return size;
    size = _;
    return sankey;
  };

  sankey.layout = function(iterations) {
    computeNodeLinks();
    computeNodeValues();
    computeNodeBreadths();
    computeNodeDepths(iterations);
    computeLinkDepths();
    return sankey;
  };

  sankey.relayout = function() {
    computeLinkDepths();
    return sankey;
  };

  sankey.link = function() {
    var curvature = .5;

    function link(d) {
      var x0 = d.source.x + d.source.dx,
          x1 = d.target.x,
          xi = d3.interpolateNumber(x0, x1),
          x2 = xi(curvature),
          x3 = xi(1 - curvature),
          y0 = d.source.y + d.sy + d.dy / 2,
          y1 = d.target.y + d.ty + d.dy / 2;
      return "M" + x0 + "," + y0
           + "C" + x2 + "," + y0
           + " " + x3 + "," + y1
           + " " + x1 + "," + y1;
    }

    link.curvature = function(_) {
      if (!arguments.length) return curvature;
      curvature = +_;
      return link;
    };

    return link;
  };

  // Populate the sourceLinks and targetLinks for each node.
  // Also, if the source and target are not objects, assume they are indices.
  function computeNodeLinks() {
    nodes.forEach(function(node) {
      node.sourceLinks = [];
      node.targetLinks = [];
    });
    links.forEach(function(link) {
      var source = link.source,
          target = link.target;
      if (typeof source === "number") source = link.source = nodes[link.source];
      if (typeof target === "number") target = link.target = nodes[link.target];
      source.sourceLinks.push(link);
      target.targetLinks.push(link);
    });
  }

  // Compute the value (size) of each node by summing the associated links.
  function computeNodeValues() {
    nodes.forEach(function(node) {
      node.value = Math.max(
        d3.sum(node.sourceLinks, value),
        d3.sum(node.targetLinks, value)
      );
    });
  }

  // Iteratively assign the breadth (x-position) for each node.
  // Nodes are assigned the maximum breadth of incoming neighbors plus one;
  // nodes with no incoming links are assigned breadth zero, while
  // nodes with no outgoing links are assigned the maximum breadth.
  function computeNodeBreadths() {
    var remainingNodes = nodes,
        nextNodes,
        x = 0;

    while (remainingNodes.length) {
      nextNodes = [];
      remainingNodes.forEach(function(node) {
        node.x = x;
        node.dx = nodeWidth;
        node.sourceLinks.forEach(function(link) {
          nextNodes.push(link.target);
        });
      });
      remainingNodes = nextNodes;
      ++x;
    }

    //
    moveSinksRight(x);
    scaleNodeBreadths((size[0] - nodeWidth) / (x - 1));
  }

  function moveSourcesRight() {
    nodes.forEach(function(node) {
      if (!node.targetLinks.length) {
        node.x = d3.min(node.sourceLinks, function(d) { return d.target.x; }) - 1;
      }
    });
  }

  function moveSinksRight(x) {
    nodes.forEach(function(node) {
      if (!node.sourceLinks.length) {
        node.x = x - 1;
      }
    });
  }

  function scaleNodeBreadths(kx) {
    nodes.forEach(function(node) {
      node.x *= kx;
    });
  }

  function computeNodeDepths(iterations) {
    var nodesByBreadth = d3.nest()
        .key(function(d) { return d.x; })
        .sortKeys(d3.ascending)
        .entries(nodes)
        .map(function(d) { return d.values; });

    //
    initializeNodeDepth();
    resolveCollisions();
    for (var alpha = 1; iterations > 0; --iterations) {
      relaxRightToLeft(alpha *= .99);
      resolveCollisions();
      relaxLeftToRight(alpha);
      resolveCollisions();
    }

    function initializeNodeDepth() {
      var ky = d3.min(nodesByBreadth, function(nodes) {
        return (size[1] - (nodes.length - 1) * nodePadding) / d3.sum(nodes, value);
      });

      nodesByBreadth.forEach(function(nodes) {
        nodes.forEach(function(node, i) {
          node.y = i;
          node.dy = node.value * ky;
        });
      });

      links.forEach(function(link) {
        link.dy = link.value * ky;
      });
    }

    function relaxLeftToRight(alpha) {
      nodesByBreadth.forEach(function(nodes, breadth) {
        nodes.forEach(function(node) {
          if (node.targetLinks.length) {
            var y = d3.sum(node.targetLinks, weightedSource) / d3.sum(node.targetLinks, value);
            node.y += (y - center(node)) * alpha;
          }
        });
      });

      function weightedSource(link) {
        return center(link.source) * link.value;
      }
    }

    function relaxRightToLeft(alpha) {
      nodesByBreadth.slice().reverse().forEach(function(nodes) {
        nodes.forEach(function(node) {
          if (node.sourceLinks.length) {
            var y = d3.sum(node.sourceLinks, weightedTarget) / d3.sum(node.sourceLinks, value);
            node.y += (y - center(node)) * alpha;
          }
        });
      });

      function weightedTarget(link) {
        return center(link.target) * link.value;
      }
    }

    function resolveCollisions() {
      nodesByBreadth.forEach(function(nodes) {
        var node,
            dy,
            y0 = 0,
            n = nodes.length,
            i;

        // Push any overlapping nodes down.
        nodes.sort(ascendingDepth);
        for (i = 0; i < n; ++i) {
          node = nodes[i];
          dy = y0 - node.y;
          if (dy > 0) node.y += dy;
          y0 = node.y + node.dy + nodePadding;
        }

        // If the bottommost node goes outside the bounds, push it back up.
        dy = y0 - nodePadding - size[1];
        if (dy > 0) {
          y0 = node.y -= dy;

          // Push any overlapping nodes back up.
          for (i = n - 2; i >= 0; --i) {
            node = nodes[i];
            dy = node.y + node.dy + nodePadding - y0;
            if (dy > 0) node.y -= dy;
            y0 = node.y;
          }
        }
      });
    }

    function ascendingDepth(a, b) {
      return a.y - b.y;
    }
  }

  function computeLinkDepths() {
    nodes.forEach(function(node) {
      node.sourceLinks.sort(ascendingTargetDepth);
      node.targetLinks.sort(ascendingSourceDepth);
    });
    nodes.forEach(function(node) {
      var sy = 0, ty = 0;
      node.sourceLinks.forEach(function(link) {
        link.sy = sy;
        sy += link.dy;
      });
      node.targetLinks.forEach(function(link) {
        link.ty = ty;
        ty += link.dy;
      });
    });

    function ascendingSourceDepth(a, b) {
      return a.source.y - b.source.y;
    }

    function ascendingTargetDepth(a, b) {
      return a.target.y - b.target.y;
    }
  }

  function center(node) {
    return node.y + node.dy / 2;
  }

  function value(link) {
    return link.value;
  }

  return sankey;
};

</script>

<script>
]]
-- Create javascript vlan boolean variable
if (_ifstats.iface_vlan) then print("var iface_vlan = true;") else print("var iface_vlan = false;") end

print [[

var sankey_has_chart = false;

function sankey() {
  var w = $("#chart").width();
  var h = window.innerHeight / 2;

  var margin = {top: 10, right: 10, bottom: 10, left: 10},
      width = w - margin.left - margin.right,
      height = h - margin.top - margin.bottom;

  var formatNumber = d3.format(",.0f"),
    format = function(sent, rcvd) { return "[sent: " + NtopUtils.bytesToVolume(sent) + ", rcvd: " + NtopUtils.bytesToVolume(rcvd)+"]"; },
    color = d3.scale.category20();

]]
-- Default value
active_sankey = "host"
local debug = false

if(_GET["host"] ~= nil) then
   print('d3.json("'..ntop.getHttpPrefix()..'/lua/iface_flows_sankey.lua?ifid='..(_ifstats.id)..'&' ..hostinfo2url(hostkey2hostinfo(_GET["host"])).. '"')
else
   print('d3.json("'..ntop.getHttpPrefix()..'/lua/iface_flows_sankey.lua"')
end


if (debug) then io.write("Active sankey: "..active_sankey.."\n") end

print [[
    , function(hosts) {

    if ((hosts.links.length == 0) && (hosts.nodes.length == 0)) {
      if(! sankey_has_chart)
	$('#alert_placeholder').html("<div class=\"alert alert-warning\"><button type=\"button\" class=\"close\" data-bs-dismiss=\"alert\">x</button><strong>Warning: </strong>]] print(i18n("no_talkers_for_the_host")) print[[.</div>");
      return;
    }

  $('#alert_placeholder').html("");
  d3.select("#chart").select("svg").remove();
  sankey_has_chart = true;

  var sankey_width = width + margin.left + margin.right;
  var sankey_height = height + margin.top + margin.bottom;

  var svg_sankey = d3.select("#chart").append("svg")
    .attr("width", sankey_width)
    .attr("height", sankey_height)
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

url = ntop.getHttpPrefix().."/lua/flows_stats.lua?"

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
    .text(function(d) { return d.source.name + " - " + d.target.name + "\n" + NtopUtils.bytesToVolume(d.value)+ "\n Double click to show more information about this flows." ; });
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

