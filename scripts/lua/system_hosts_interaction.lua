--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

if(host_ip == nil) then
   host_ip = _GET["host"]
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

if(host_ip ~= nil) then
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
      if(host_ip == nil) then
   print("<hr><h2>Top System Hosts Interaction</H2>")
      else
   name = host_name
   if(name == nil) then name = host_ip end
   print("<hr><h2>"..name.." Interactions</H2><i class=\"fa fa-chevron-left fa-lg\"></i><small><A onClick=\"javascript:history.back()\">Back</A></small>")
      end
   end

print [[

<script>

var graph = new Springy.Graph();

var layout = new Springy.Layout.ForceDirected(
  graph,
  400.0, // stiffness
  100.0, // repulsion
  0.8    // damping
);

jQuery(function () {
  var springy = window.springy = jQuery('#chart-canvas').springy({
    graph: graph,
    nodeSelected: function (node) {
      //node.data.label;
    }
  });
});

function draw(translatePos){
  var canvas = document.getElementById("chart-canvas");
  //var context = canvas.getContext("2d");
  //context.clearRect(0, 0, canvas.width, canvas.height);
  canvas.style.zoom = 100+'%';  
}

window.onload = function(){
  var canvas = document.getElementById("chart-canvas");
  var startDragOffset = {};
  var mouseDown = false;

  var translatePos = {
    x: canvas.width / 2,
    y: canvas.height / 2
  };

  canvas.addEventListener("mousedown", function(evt){
    mouseDown = true;
    startDragOffset.x = evt.clientX - translatePos.x;
    startDragOffset.y = evt.clientY - translatePos.y;
  });

  canvas.addEventListener("mouseup", function(evt){
    mouseDown = false;
  });

  canvas.addEventListener("mouseover", function(evt){
    mouseDown = false;
  });

  canvas.addEventListener("mouseout", function(evt){
    mouseDown = false;
  });

  canvas.addEventListener("mousemove", function(evt){
    if (mouseDown) {
      translatePos.x = evt.clientX - startDragOffset.x;
      translatePos.y = evt.clientY - startDragOffset.y;
      draw(translatePos);
    }
  });

  draw(translatePos);
};

function getJSONData(url, params, error_message) {
  var jsonData = null;
    
  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    data: params,
    async: false,
    success: function(content) {
      jsonData = content; //jQuery.parseJSON(content);
    },
    error: function(content) {
      console.log(content);
    }
  });

  return jsonData;
}

function readableBytes(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
};

var colorGen = d3.scale.category20();
var explode_process = '';

function refreshGraph() {
  var nodes = {};
  var max_node_bytes = 0;
  var max_link_bytes = 0;
  var filtered_links = [];
  var systems = {};

  var links = getJSONData("]]
print (ntop.getHttpPrefix())
print [[/lua/get_system_hosts_interaction.lua");
  
  function addNode(node_id, id, name, bytes, type, process_name, icon_url, exploded) {
    var description;
    if (name == "Remote Hosts") {
      description = name;
       icon_url = ".. ntop.getHttpPrefix() .. "/img/interaction-graph-icons/remote_hosts.png";
    } else {
      description = process_instance_to_string(id);
    }
    if (!nodes[node_id]) nodes[node_id] = { id: node_id, name: name, bytes: 0, type: type, description: description, process_name: process_name, icon_url: icon_url, instances: {} };

    if (!nodes[node_id]['instances'][id]) nodes[node_id]['instances'][id] = 1;
    else nodes[node_id]['instances'][id]++;
    if (Object.keys(nodes[node_id]['instances']).length > 1 && name != "Remote Hosts" && !exploded) 
      nodes[node_id]['description'] = 'Double-Click to expand';

    nodes[node_id]['bytes'] += bytes;

    if (nodes[node_id]['bytes'] > max_node_bytes) max_node_bytes = nodes[node_id]['bytes'];
  }

  links.forEach(function(link) {
    if (!systems[link.client_system_id]) systems[link.client_system_id] = 0;
    if (!systems[link.server_system_id]) systems[link.server_system_id] = 0;
    systems[link.client_system_id]++;
    systems[link.server_system_id]++;
  });

  links.forEach(function(link) {

    // adding system id prefix in case of multiple systems
    if (Object.keys(systems).length > 1) {
      link.client_name = link.client_system_id + ":" + link.client_name; 
      link.server_name = link.server_system_id + ":" + link.server_name;
    }

    //trick to group remote hosts
    if (link.client_type == "host") link.client_name = "Remote Hosts";
    if (link.server_type == "host") link.server_name = "Remote Hosts";

    var source = link.client_name,
        target = link.server_name;

    var source_exploded = 0,
        target_exploded = 0;

    var client_process_name = link.client_name,
        server_process_name = link.server_name;

    if (explode_process != '') {
      // filtering exploded process
      if (explode_process != source && explode_process != target) return; /* skip this link */

      if (explode_process == source) {
        source_exploded = 1;
        source = link.client; 
        link.client_name = link.client_name + process_instance_suffix(link.client); 
      }

      if (explode_process == target) { 
        target_exploded = 1;
        target = link.server; 
        link.server_name = link.server_name + process_instance_suffix(link.server); 
      }
    }

    addNode(source, link.client, link.client_name, link.bytes, link.client_type, client_process_name, link.client_icon, source_exploded);
    addNode(target, link.server, link.server_name, link.bytes, link.server_type, server_process_name, link.server_icon, target_exploded);

    if (link.cli2srv_bytes > max_link_bytes) max_link_bytes = link.cli2srv_bytes;
    if (link.srv2cli_bytes > max_link_bytes) max_link_bytes = link.srv2cli_bytes;

    link.source = nodes[source];
    link.target = nodes[target];

    // aggregating links with same source/target
    var link_found = 0;
    filtered_links.forEach(function(flink) {
      if (flink.client_name == link.client_name && flink.server_name == link.server_name) {
        flink.bytes += link.bytes;
        flink.cli2srv_bytes += link.cli2srv_bytes;
        flink.srv2cli_bytes += link.srv2cli_bytes;
        link_found = 1;
      }
    });

    if (!link_found)
      filtered_links.push(link);
  });

  // cleanup 
  graph.filterNodes(function(node) { 
    if (nodes[node.data.id]) {
      nodes[node.data.id].created = 1; 
      nodes[node.data.id].obj = node;
      return true;
    } else {
      return false;
    } 
  });
  graph.filterEdges(function(edge) { 
    return false; 
  });

  // adding nodes to the graph
  for (node_id in nodes) {
    /* Node attributes:
      id
      name
      bytes
      type
      description
      process_name
      icon_url
    */
    if (!nodes[node_id].created) {
      nodes[node_id].created = 1;

      var image = null;
      if (nodes[node_id].icon_url) {
        image = {};
        image.src = nodes[node_id].icon_url;
      }
      nodes[node_id].obj =  graph.newNode({
        id: node_id,
        label: nodes[node_id].process_name,
        ip: nodes[node_id].description,
        ondoubleclick: function(n) {
          if (n.label == explode_process || n.label == "Remote Hosts") explode_process = '';
          else explode_process = n.label;
          refreshGraph();
        },
        image: image
      });
    }
  }

  // adding links to the graph
  filtered_links.forEach(function(link) {
    var color = colorGen(link.client_name);
    /* Link attributes:
      client - 0-192.168.1.205-6232
      client_system_id - 0
      client_name - links2
      client_type - syshost
      server - 0-173.194.116.23
      server_system_id - 0
      server_name - mil01s19-in-f23.1e10...
      server_type - host
      bytes - 2250886
      cli2srv_bytes - 2248400
      srv2cli_bytes - 2486
    */
    graph.newEdge(
      link.source.obj, 
      link.target.obj, 
      {
        color: color,
        weight: getWeight(link.cli2srv_bytes),
        label: readableBytes(link.cli2srv_bytes)
      }
    );
    graph.newEdge(
      link.target.obj, 
      link.source.obj, 
      {
        color: color,
        weight: getWeight(link.srv2cli_bytes),
        label: readableBytes(link.srv2cli_bytes)
      }
    );
  });

  function getWeight(size) {
    var weight = (size ? Math.sqrt((size / max_link_bytes) * 100) / Math.PI : 1);
    if (weight < 1) weight = 1;
    return weight;
  }

  function process_instance_suffix(id) {
    var info = id.split("-");
    var string = ":" + info[1];
    if (info[2]) string += ":" + info[2];
    return string;
  }

  function process_instance_to_string(id) {
    var info = id.split("-");
    var string = "System: " + info[0] + " IP: " + info[1];
    if (info[2]) string += " PID: " + info[2];
    return string;
  }

}

refreshGraph();
setInterval(function() {
  refreshGraph();
}, 2000);

</script>

<div id="chart">
  <canvas id="chart-canvas" width="960" height="500" />
</div>

]]
else
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No results found</div>")
end

if(mode ~= "embed") then
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
