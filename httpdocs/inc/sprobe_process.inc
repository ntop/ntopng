
			  var width = 960, height = 500, arrow_size = 8;
			  var color = d3.scale.category10();

			  color["proc"] = "#aec7e2";
			  color["host"] = "#ccc";

			  var force = d3.layout.force()
			  .nodes(d3.values(nodes))
			  .links(links)
			  .size([width, height])
			  .linkDistance(120) // Arc lenght
			  .charge(-400)
			  .on("tick", tick)
			  .start();

			  var svg = d3.select("#chart").append("svg")
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
						.attr("x", 12)
						.attr("y", ".31em")
						.text(function(d) { if(d.pid > 0) 
								      return(d.name+" [pid "+d.pid+"]"); // Process
								    else {
								       if(d.name == d.num) 
       									  s = d.name;
								        else
								          s = d.name+" ["+d.num+"]"; 

									if(d.num_procs) s = s + " ("+d.num_procs+" process)";
									return(s);
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
</script>
