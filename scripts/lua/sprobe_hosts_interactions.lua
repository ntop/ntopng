--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

if(mode ~= "embed") then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   active_page = "hosts"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
end

print("<hr><h2>Hosts Interaction</H2>")

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
      console.log(error_message);
    }
  });

  return jsonData;
}

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
print [[/lua/sprobe_hosts_interactions_data.lua");
  
  function addNode(node_id, name, system_id, num_procs, bytes, type, icon_url) {
    if (!nodes[node_id]) nodes[node_id] = { id: node_id, name: name, system_id: system_id, num_procs: num_procs, bytes: 0, type: type, icon_url: icon_url };
    nodes[node_id]['bytes'] += bytes;
    if (nodes[node_id]['bytes'] > max_node_bytes) max_node_bytes = nodes[node_id]['bytes'];
  }

  links.forEach(function(link) {

    source = link.source.split("@");
    target = link.target.split("@");
    link.source   = source[0];
    link.target   = target[0];
    link.source_system_id = source[1];
    link.target_system_id = target[1];

    addNode(link.source, link.source_name, link.source_system_id, link.source_num, link.cli2srv_bytes, link.source_type, link.source_icon);
    addNode(link.target, link.target_name, link.target_system_id, link.target_num, link.srv2cli_bytes, link.target_type, link.target_icon);

    link.source = nodes[link.source];
    link.target = nodes[link.target];

    if (link.cli2srv_bytes > max_link_bytes) max_link_bytes = link.cli2srv_bytes;
    if (link.srv2cli_bytes > max_link_bytes) max_link_bytes = link.srv2cli_bytes;

    /*
    // aggregating links with same source/target
    var link_found = 0;
    filtered_links.forEach(function(flink) {
      if (flink.client_name == link.client_name && flink.server_name == link.server_name) {
        flink.cli2srv_bytes += link.cli2srv_bytes;
        flink.srv2cli_bytes += link.srv2cli_bytes;
        link_found = 1;
      }
    });

    if (!link_found)
    */
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
      system_id
      num_procs
      bytes
      type
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
        label: nodes[node_id].name,
        ip: nodes[node_id].system_id,
        ondoubleclick: function(n) {
	  //TODO /lua/sprobe_host_process.lua?host=" + link.source + "&pid=" + link.source_system_id + "&pid_name="+link.source_name
          //refreshGraph();
        },
        image: image
      });
    }
  }

  // adding links to the graph
  filtered_links.forEach(function(link) {
    var color = colorGen(link.client_name);
    /* Link attributes:
      source
      source_name
      source_system_id
      source_num
      source_type
      source_icon
      target
      target_name
      target_system_id
      target_num
      target_type
      target_icon
      cli2srv_bytes
      srv2cli_bytes
    */
    graph.newEdge(
      link.source.obj, 
      link.target.obj, 
      {
        color: color,
        weight: getWeight(link.cli2srv_bytes),
        label: bytesToSize(link.cli2srv_bytes)
      }
    );
    graph.newEdge(
      link.target.obj, 
      link.source.obj, 
      {
        color: color,
        weight: getWeight(link.srv2cli_bytes),
        label: bytesToSize(link.srv2cli_bytes)
      }
    );
  });

  function getWeight(size) {
    var weight = (size ? Math.sqrt((size / max_link_bytes) * 100) / Math.PI : 1);
    if (weight < 1) weight = 1;
    return weight;
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

if(mode ~= "embed") then
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
