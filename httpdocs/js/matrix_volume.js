  	var matrix = [],
    nodes = dati.data.nodes,
    n = nodes.length;

  // Compute index per node.
  nodes.forEach(function(node, i) {
    node.index = i;
    //node.count = 0;
    matrix[i] = d3.range(n).map(function(j) { 
    	return {x: j, y: i, z: 0}; 
    });
  });

  // Convert links to matrix; count link
  dati.data.links.forEach(function(link) {
    matrix[link.source][link.target].z += link.value + 1;
   // matrix[link.target][link.source].z += 1;
    matrix[link.source][link.source].z += 1;
    matrix[link.target][link.target].z += 1;
   // nodes[link.source].count += link.value;
   // nodes[link.target].count += link.value;
  });

  // Precompute the orders.
  var orders = {
    name: d3.range(n).sort(function(a, b) { 
    	return d3.ascending(nodes[a].name, nodes[b].name); }),
    count: d3.range(n).sort(function(a, b) { 
    	return nodes[b].count - nodes[a].count; }),
    group: d3.range(n).sort(function(a, b) { 
    	return nodes[b].group - nodes[a].group; }),
	flow_sent: d3.range(n).sort(function(a, b) { 
    	return nodes[b].sent - nodes[a].sent; }),
	flow_rcvd: d3.range(n).sort(function(a, b) { 
    	return nodes[b].rcvd - nodes[a].rcvd; }),
    flow_tot: d3.range(n).sort(function(a, b) { 
    	return nodes[b].tot - nodes[a].tot; })
  };

  // The default sort order.
  h.domain(orders.name);

  svg.append("rect")
      .attr("class", "background")
      .attr("width", width)
      .attr("height", height);

  var row = svg.selectAll(".row")
      .data(matrix)
      .enter().append("g")
      .attr("class", "row")
      .attr("transform", function(d, i) { return "translate(0," + h(i) + ")"; })
      .each(row);

  row.append("line")
      .attr("x2", width);

  // Y labels
  row.append("text")
      .attr("x", -6)
      .attr("y", h.rangeBand() / 2)
      .attr("dy", ".32em")
      .attr("text-anchor", "end")
    .text(function(d, i) { return nodes[i].label; })
    .on("click", function(d) { location.href="/lua/host_details.lua?host="+this.textContent; });

  var column = svg.selectAll(".column")
      .data(matrix)
      .enter().append("g")
      .attr("class", "column")
      .attr("transform", function(d, i) { 
      return "translate(" + h(i) + ")rotate(-90)"; });

  column.append("line")
      .attr("x1", -width);

  // X labels
  column.append("text")
      .attr("x", 6)
      .attr("y", h.rangeBand() / 2)
      .attr("dy", ".32em")
      .attr("text-anchor", "start")
      .text(function(d, i) { return nodes[i].label; })
      .on("click", function(d) { location.href="/lua/host_details.lua?host="+this.textContent; });

  function row(row) {
    var cell = d3.select(this).selectAll(".cell")
        .data(row.filter(function(d) { return d.z; }))
        .enter().append("rect")
        .attr("class", "cell")
        .attr("x", function(d) { return h(d.x); })
        .attr("width", h.rangeBand())
        .attr("height", h.rangeBand())
        .style("fill-opacity", function(d) { return z(d.z); })
        .style("fill", function(d) { return nodes[d.x].group == nodes[d.y].group ? c(nodes[d.x].group) : null; })
        .on("mouseover", mouseover)
        .on("mouseout", mouseout);
  }


  function mouseover(p) {
  	$("#tooltip table tbody").empty();
  	var flag = false;
    d3.selectAll(".row text").classed("active", function(d, i) { 
    	if (i == p.y) { 
    		flag = true;
	        $("#tooltip table tbody")
	        .append($("<tr>").append($("<td>").text(nodes[i].name))
	        	.append($("<td>").text(bytesToVolume(nodes[i].sent)))
	        	.append($("<td>").text(bytesToVolume(nodes[i].sent))));
    	}
    	return i == p.y;
    	});
    d3.selectAll(".column text").classed("active", function(d, i) { 
	    if (i == p.x) { 
	    	flag = true;
	        $("#tooltip table tbody")
	        	.append($("<tr>").append($("<td>").text(nodes[i].name))
	        		.append($("<td>").text(bytesToVolume(nodes[i].sent)))
	        			.append($("<td>").text(bytesToVolume(nodes[i].sent))));
    	}
    	return i == p.x; 
    });
    if (flag) {
		$("#tooltip").css("left", event.pageX + 5 + "px");
		$("#tooltip").css("top", event.pageY + 5 + "px");
		$("#tooltip").show();
    }
    
  }

  function mouseout() {
  	$("#tooltip").hide();
  	$("#tooltip table tbody").empty();
    d3.selectAll("text").classed("active", false);
  }

  d3.select("#order").on("change", function() {
    clearTimeout(timeout);
    order(this.value);
  });

  function order(value) {
    h.domain(orders[value]);

    var t = svg.transition().duration(2500);

    t.selectAll(".row")
        .delay(function(d, i) { return h(i) * 4; })
        .attr("transform", function(d, i) { return "translate(0," + h(i) + ")"; })
      	.selectAll(".cell")
        .delay(function(d) { return h(d.x) * 4; })
        .attr("x", function(d) { return h(d.x); });

    t.selectAll(".column")
        .delay(function(d, i) { return h(i) * 4; })
        .attr("transform", function(d, i) { return "translate(" + h(i) + ")rotate(-90)"; });
  }

  var timeout = setTimeout(function() {
    order("group");
    d3.select("#order").property("selectedIndex", 2).node().focus();
  }, 5000);
});

