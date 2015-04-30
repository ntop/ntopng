--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- host_info = url2hostinfo(_GET)


if(host_ip == nil) then
   host_info = url2hostinfo(_GET)
else
  -- print("host_ip:"..host_ip.."<br>")
  host_info = {}
  host_info = hostkey2hostinfo(host_ip)
end

if(mode == nil) then
   mode  = _GET["mode"]
end

if(host_name == nil) then
   host_name = _GET["name"]
end

if(mode ~= "embed") then
   sendHTTPHeader('text/html; charset=iso-8859-1')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   active_page = "hosts"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
end

num_top_hosts = 10

if(host_info["host"] ~= nil) then
   num = 1
else
   interface.select(ifname)
   hosts_stats = interface.getHostsInfo()
   num = 0
   for key, value in pairs(hosts_stats) do
      num = num + 1
   end
end

if(num > 0) then
   if(mode ~= "embed") then
      if(host_info["host"] == nil) then
	 print("<hr><h2>Top Hosts Interaction</H2>")
      else
	 name = host_name
	 if(name == nil) then name = host_info["host"] end
	 print("<hr><h2>"..name.." Interactions</H2><i class=\"fa fa-chevron-left fa-lg\"></i><small><A onClick=\"javascript:history.back()\">Back</A></small>")
      end
   end

print [[
<style>
svg {
 font: 10px sans-serif;
}

.axis path, .axis line {
 fill: none;
 stroke: #000;
 shape-rendering: crispEdges;
}

sup, sub {
  line-height: 0;
}

    q:before, blockquote:before {
 content: "?";
}

    q:after, blockquote:after {
 content: "?";
}

    blockquote:before {
 position: absolute;
 left: 2em;
}

    blockquote:after {
 position: absolute;
}

  </style>
  <style>
#chart {
height: 
]]

if(mode ~= "embed") then
   print("600") 
elseif(interface.getNumAggregatedHosts() > 0) then
   print("400") 
else
   print("300") 
end

print [[
px;
}
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

       circle.node-dot {
       fill: DarkSlateGray;
       stroke: SlateGray;
       stroke-width: 1px;
       }


       path.link {
       fill: none;
       stroke: SlateGray;
       stroke-width: 1.5px;
       }

       marker#defaultMarker {
       fill: SlateGray;
       }

       path.link.defaultMarker {
       stroke: SlateGray;
       }

       circle {
       fill: #ccc;
       stroke: #333;
       stroke-width: 1.5px;
       }

       text {
	 pointer-events: none;
       }

       text.shadow {
       stroke: #fff;
       stroke-width: 3px;
       stroke-opacity: .8;
       }

       </style><style>path.link.proposer{stroke:red;}
       marker#bus{fill:blue;}
       marker#manual{fill:red;}
       path.link.direct{stroke:green;  }
       path.link.bus{stroke:blue;} 
       path.link.manual{stroke:red;stroke-dasharray: 0, 2 1;} </style><script>
       /**
	* do the force vizualization
	* @param {string} divName name of the div to hold the tree
	* @param {object} inData the source data
	*/
       function doTheTreeViz(divName, inData) {
	 // tweak the options
	 var options = $.extend({
	   stackHeight : 12,
	       radius : 5,
	       fontSize : 12,
	       labelFontSize : 8,
	       nodeLabel : null,
	       markerWidth : 0,
	       markerHeight : 0,
	       width : $(divName).outerWidth(),
	       gap : 1.5,
	       nodeResize : "",
	       linkDistance : 30,
	       charge : -120,
	       styleColumn : null,
	       styles : null,
	       linkName : null,
	       height : $(divName).outerHeight()
	       }, inData.d3.options);
	 // set up the parameters
	 options.gap = options.gap * options.radius;
	 var width = options.width;
	 var height = options.height;
	 var data = inData.d3.data;
	 var nodes = data.nodes;
	 var links = data.links;
	 var color = d3.scale.category10();

	 color["local"]  = "#aec7e8";
	 color["remote"] = "#bcbd22";
	 color["sun"]    = "#fd8d3c";
	 color["aggregation"]    = "#008d3c";
	 
	 var force = d3.layout.force().nodes(nodes).links(links).size([width, height]).linkDistance(options.linkDistance).charge(options.charge).on("tick", tick).start();

	 var main = d3.select(divName).append("svg:svg").attr("width", width).attr("height", height);

   var svg = main.append('svg:g')
    .call(d3.behavior.zoom().on("zoom", rescale))
    .on("dblclick.zoom", null);

    function rescale() {
      trans=d3.event.translate;
      scale=d3.event.scale;

      svg.attr("transform",
          "translate(" + trans + ")"
          + " scale(" + scale + ")");
    }

	 // get list of unique values in stylecolumn
	 linkStyles = [];
	 if (options.styleColumn) {
	   var x;
	   for (var i = 0; i < links.length; i++) {
	     if (linkStyles.indexOf( x = links[i][options.styleColumn].toLowerCase()) == -1)
	       linkStyles.push(x);
	   }
	 } else
	   linkStyles[0] = "defaultMarker";

	 // do we need a marker?

	 if (options.markerWidth) {
	   svg.append("svg:defs").selectAll("marker").data(linkStyles).enter().append("svg:marker").attr("id", String).attr("viewBox", "0 -5 10 10").attr("refX", 15).attr("refY", -1.5).attr("markerWidth", options.markerWidth).attr("markerHeight", options.markerHeight).attr("orient", "auto").append("svg:path").attr("d", "M0,-5L10,0L0,5");
	 }

	 var path = svg.append("svg:g").selectAll("path").data(force.links()).enter().append("svg:path").attr("class", function(d) {
	     return "link " + (options.styleColumn ? d[options.styleColumn].toLowerCase() : linkStyles[0]);
	   }).attr("marker-end", function(d) {
	       return "url(#" + (options.styleColumn ? d[options.styleColumn].toLowerCase() : linkStyles[0] ) + ")";
	     });

	 var circle = svg.append("svg:g").selectAll("circle")
    .data(force.nodes())
    .enter()
    .append("svg:circle")
      .attr("r", function(d) {
	      return getRadius(d);
	     })
      .style("fill", function(d) {
				  return color[d.group];
	     })
      .call(force.drag)
      //.on("mousedown", 
       // function(d) { 
          // disable zoom
       //   svg.call(d3.behavior.zoom().on("zoom"), null);
      //  })
      //.on("mouseup", 
      //  function(d) { 
         // enable zoom
      //   svg.call(d3.behavior.zoom().on("zoom"), rescale);
      //  })
          ;

	 if (options.nodeLabel) {
	   circle.append("title").html(function(d) {
	       return d[options.nodeLabel];
	     });  	  
	 }

         circle.on("dblclick", function(d) { if(d.link.length > 0) { window.location.href = d.link; } } );
    
	 if (options.linkName) {
	   path.append("title").text(function(d) {
	       return d[options.linkName];
	     });
	 }
	 var text = svg.append("svg:g").selectAll("g").data(force.nodes()).enter().append("svg:g");

	 // A copy of the text with a thick white stroke for legibility.
	 text.append("svg:text").attr("x", options.labelFontSize).attr("y", ".31em").attr("class", "shadow").text(function(d) {
	     return d[options.nodeLabel];
	   });

	 text.append("svg:text").attr("x", options.labelFontSize).attr("y", ".31em").text(function(d) {
	     return d[options.nodeLabel];
	   });
	 function getRadius(d) {
	   return options.radius * (options.nodeResize ? Math.sqrt(d[options.nodeResize]) / Math.PI : 1);
	 }

	 // Use elliptical arc path segments to doubly-encode directionality.
	 function tick() {
	   path.attr("d", function(d) {
	       var dx = d.target.x - d.source.x, dy = d.target.y - d.source.y, dr = Math.sqrt(dx * dx + dy * dy);
	       return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
	     });

	   circle.attr("transform", function(d) {
	       return "translate(" + d.x + "," + d.y + ")";
	     });

	   text.attr("transform", function(d) {
	       return "translate(" + d.x + "," + d.y + ")";
	     });
	 }

       }
       </script><script> 

window['ntopData'] = {"d3":{"options":
			    {"radius":"16","fontSize":"30","labelFontSize":"30","charge":"-2000","nodeResize":"count","nodeLabel":"label","markerHeight":"6","markerWidth":"6","styleColumn":"styleColumn","linkName":"group"},
		       "data":{"links":[

]]

-- Nodes

interface.select(ifname)

if(host_info["host"] == nil) then
   hosts_stats = getTopInterfaceHosts(num_top_hosts, true)
else
   hosts_stats = {}
   hosts_stats[host_info["host"]] = interface.getHostInfo(host_info["host"],host_info["vlan"])
end

hosts_id = {}
ids = {}

num = 0
links = 0
local host

for key, values in pairs(hosts_stats) do
  
  host = interface.getHostInfo(key)

  if(host ~= nil) then
    -- init host
    if(hosts_id[key] == nil) then
      hosts_id[key] = { }
      hosts_id[key]['count'] = 0
      hosts_id[key]['id'] = num
      ids[num] = key
      key_id = num
      num = num + 1
    else
      key_id = hosts_id[key]['id']
    end

    -- client contacts
    if(host["contacts"]["client"] ~= nil) then
      for k,v in pairs(host["contacts"]["client"]) do 
        
        if(hosts_id[k] == nil) then
          hosts_id[k] = { }
          hosts_id[k]['count'] = 0
          hosts_id[k]['id'] = num
          ids[num] = k
          peer_id = num
          num = num + 1
        else
          peer_id = hosts_id[k]['id']
        end

        hosts_id[key]['count'] = hosts_id[key]['count'] + v
        if(links > 0) then print(",") end
        print('\n{"source":'..key_id..',"target":'..peer_id..',"depth":6,"count":'..v..',"styleColumn":"client","linkName":""}')
        links = links + 1
      end
    end

    -- server contacts
    if(host["contacts"]["server"] ~= nil) then
      for k,v in pairs(host["contacts"]["server"]) do 
        
        if(hosts_id[k] == nil) then
          hosts_id[k] = { }
          hosts_id[k]['count'] = 0
          hosts_id[k]['id'] = num
          ids[num] = k
          peer_id = num
          num = num + 1
        else
          peer_id = hosts_id[k]['id']
        end

        hosts_id[key]['count'] = hosts_id[key]['count'] + v
        if(links > 0) then print(",") end
        print('\n{"source":'..key_id..',"target":'..peer_id..',"depth":6,"count":'..v..',"styleColumn":"server"}')
        links = links + 1
      end
    end
  end
end

aggregation_ids = {}

if(host_info["host"] ~= nil) then
   aggregations = interface.getAggregationsForHost(host_info["host"])
else
   aggregations = {}
end

for name,num_contacts in pairs(aggregations) do
   aggregation_ids[name] = num

   hosts_id[name] = { }
   hosts_id[name]['count'] = num_contacts
   hosts_id[name]['id'] = num
   ids[num] = name

   if(links > 0) then print(",") end
   print('\n{"source":'..num..',"target": 0,"depth":6,"count":'..num_contacts..',"styleColumn":"aggregation"}')
   links = links + 1

   num = num + 1
end

tot_hosts = num

print [[

],"nodes":[
]]

-- Nodes

min_size = 5
maxval = 0
for k,v in pairs(hosts_id) do 
  if(v['count'] > maxval) then maxval = v['count'] end
end

num = 0
for i=0,tot_hosts-1 do
  k = ids[i]
  v = hosts_id[k]
  k_info = hostkey2hostinfo(k)
  
  target_host = interface.getHostInfo(k)

  if(target_host ~= nil) then 

    name = target_host["name"] 
    if(name ~= nil) then 
      name = name
    else
      name = ntop.getResolvedAddress(k_info["host"])
      target_host["name"] = name
    end

    if(target_host['localhost'] ~= nil) then label = "local" else label = "remote" end      
  
  else

    name = k  
    if(aggregations[k] ~= nil) then label = "aggregation" else label = "remote" end

  end

  if ((host_info["host"] ~= nil) and (host_info["host"] == k_info["host"])) then label = "sun" end
    -- f(name == k) then name = ntop.getResolvedAddress(k) end
  if(name == nil) then name = k end
  
  if(maxval == 0) then 
    tot = maxval
  else
    tot = math.floor(0.5+(v['count']*100)/maxval) 
    if(tot < min_size) then tot = min_size end
  end

  if(num > 0) then print(",") end
  print('\n{"name":"'.. name ..'","count":'.. tot ..',"group":"' .. label .. '","linkCount": '.. tot .. ',"label":"'.. name..'"')

  if(target_host ~= nil) then
    -- Host still in memory      
    if((host_info["host"] == nil) or (k_info["host"] ~= host_info["host"])) then
      print(', "link": "'..ntop.getHttpPrefix()..'/lua/hosts_interaction.lua?"}')
    else
      print(', "link": "'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='.. k.. '"}')
    end
  else
    -- print('->>'..k..'<<-\n')
    if(aggregations[k] ~= nil) then
      print(', "link": "'..ntop.getHttpPrefix()..'/lua/aggregated_host_details.lua?host='.. k .. '"}')
    else
    -- Host purged ?
      print(', "link": ""}')
    end

  end

  num = num + 1
end

if ((num == 0) and (host_info["host"] ~= nil)) then
   tot = 1
   label = ""
   name = host_info["host"]
   print('\n{"name":"'.. name ..'","count":'.. tot ..',"group":"' .. label .. '","linkCount": '.. tot .. ',"label":"'.. name..'", "link": "'..ntop.getHttpPrefix()..'/lua/host_details.lua?host='.. hostinfo2hostkey(host_info).. '"}')
end

print [[

	   ]
}}};


</script>

<div id="chart"></div>

<p>&nbsp;<p><small><b>NOTE</b></small>
<ol>
]]

if(host_info["host"] ~= nil) then
   print('<li><small>This map is centered on host <font color="#fd8d3c">'.. hostinfo2hostkey(host_info))
   if(host_name ~= nil) then print('('.. host_name .. ')') end
   print('</font>. Clicking on this host you will visualize its details.</small></li>\n')
else
   print('<li><small>This map depicts the interactions of the top  '.. num_top_hosts .. ' hosts.</small></li>\n')
end
   print('<li><small>Color map: <font color=#aec7e8><b>local</b></font>, <font color=#bcbd22><b>remote</b></font>, <font color=#008d3c><b>aggregation</b></font>, <font color=#fd8d3c><b>focus</b></font> host.</small></li>\n')
print [[
<li> <small>Click is enabled only for hosts that have not been purged from memory.</small></li>
</ol>

<!-- http://ramblings.mcpher.com/Home/excelquirks/d3 -->
  <script type="text/javascript">
       doTheTreeViz("#chart", ntopData);
  </script>

]]
else
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No results found</div>")
end

if(mode ~= "embed") then
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
