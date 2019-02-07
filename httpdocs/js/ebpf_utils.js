function draw_processes_graph(http_prefix, graph_div_id, host) {
    var links;
    var nodes = {};

    var url = http_prefix + '/lua/get_processes_graph_data.lua?host=' + host;

    d3.json(url, function(error, json) {
	if(error)
	    return console.warn(error);

	links = json;
	var _link;

	// Compute the distinct nodes from the links.
	links.forEach(function(link) {
	    if(link.source_pid == -1) {
		/* IP Address -> PID */
		_link = http_prefix + "/lua/host_details.lua?host=" + link.source;
	    } else {
		/* PID -> IP Address */
		_link = http_prefix + "/lua/process_details.lua?pid=" + link.source_pid + "&pid_name=" + link.source_name + "&host=" + host + "&page=flows";
	    }

	    link.source = nodes[link.source]
		|| (nodes[link.source] = {
		    name: link.source_name, num:link.source,
		    link: _link, type: link.source_type, pid: link.source_pid
		});

	    if(link.target_pid == -1) {
		/* IP Address -> PID */
		_link = http_prefix + "/lua/host_details.lua?host=" + link.target;
	    } else {
		/* PID -> IP Address */
		_link = http_prefix + "/lua/process_details.lua?pid=" + link.target_pid + "&pid_name=" + link.target_name + "&host=" + host + "&page=flows";
	    }

	    link.target = nodes[link.target]
		|| (nodes[link.target] = {
		    name: link.target_name, num: link.target,
		    link: _link, type: link.target_type, pid: link.target_pid
		});
	});

	var width = 960, height = 500, arrow_size = 6;
	var color = d3.scale.category10();

	/* Same colors as those used in the flow_details.lua page to represent hosts and processes */
	color["proc"] = "red";
	color["host"] = "lightsteelblue";

	var force = d3.layout.force()
	    .nodes(d3.values(nodes))
	    .links(links)
	    .size([width, height])
	    .linkDistance(120) // Arc length
	    .charge(-400)
	    .on("tick", tick)
	    .start();

	var svg = d3.select("#" + graph_div_id).append("svg")
	    .attr("id", "ebpf_graph")
	    .attr("width", width)
	    .attr("height", height);

	// Per-type markers, as they don't inherit styles.
	svg.append("defs").selectAll("marker")
	    .data(["proc2proc", "proc2host", "host2proc", "host2host"])
	    .enter().append("marker")
	    .attr("id", function(d) { return d; })
	    .attr("viewBox", "0 -5 10 10")
	    .attr("refX", 15)
	    .attr("refY", -1.5)
	    .attr("markerWidth", arrow_size).attr("markerHeight", arrow_size)
	    .attr("orient", "auto")
	    .append("path")
	    .attr("d", "M0,-5L10,0L0,5");

	var path = svg.append("g").selectAll("path")
	    .data(force.links())
	    .enter().append("path")
	    .attr("class", function(d) { return "link " + d.type; })
	    .attr("marker-end", function(d) { return "url(#" + d.type + ")"; });


	var circle = svg.append("g").selectAll("circle")
	    .data(force.nodes())
	    .enter().append("circle")
	    .attr("class", "ebpf_circle")
	    .attr("r", 8) /* Radius */
	    .style("fill", function(d) { return color[d.type]; })
	    .call(force.drag)
	    .on("dblclick", function(d) {
		window.location.href = d.link;
	    } );

	// Circle label
	var text = svg.append("g").selectAll("text")
	    .data(force.nodes())
	    .enter().append("text")
	    .attr("class", "ebpf_text")
	    .attr("x", 12)
	    .attr("y", ".31em")
	    .text(function(d) {
		if(d.pid >= 0) // Process
		    return(d.name + " [pid: "+d.pid+"]");
		else { // Host
		    return(d.name);
		}
	    });

	// Use elliptical arc path segments to doubly-encode directionality.
	function tick() {
	    path.attr("d", linkArc);
	    circle.attr("transform", transform);
	    text.attr("transform", transform);
	}

	function linkArc(d) {
	    var dx = d.target.x - d.source.x,
		dy = d.target.y - d.source.y,
		dr = Math.sqrt(dx * dx + dy * dy);
	    return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
	}

	function transform(d) {
	    return "translate(" + d.x + "," + d.y + ")";
	}
    });
}
