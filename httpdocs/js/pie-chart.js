// http://jsfiddle.net/stephenboak/hYuPb/

// Wrapper function
function do_pie(name, update_url, url_params, units, refresh) {
  var pie = new PieChart(name, update_url, url_params, units, refresh);
  if (refresh)
    pie.setInterval(setInterval(function(){pie.update();}, refresh));

  // Return new class instance, with
  return pie;
}




function PieChart(name, update_url, url_params, units, refresh) {

  // Add object properties like this
  this.name = name;
  this.update_url = update_url;
  this.url_params = url_params;
  this.units = units;
  this.refresh = refresh;
  this.pieInterval;

    var pieData = [];    
    var oldPieData = [];
    var filteredPieData = [];
    var rsp = create_pie_chart(name, units);
    var arc_group = rsp[0];
    var donut = rsp[1];
    var totalValue = rsp[2];
    var totalUnits = rsp[3];
    var color = rsp[4];
    var tweenDuration = rsp[5];
    var arc = rsp[6];
    var label_group = rsp[7];
    var center_group = rsp[8];
    var r = rsp[9];
    var textOffset = rsp[10];

    
    // to run each time data is generated

    this.update = function() {
      // console.log(this.name);
      // console.log(this.url_params);
	$.ajax({
		type: 'GET',
		    url: this.update_url,
		    data: this.url_params,
		    success: function(content) {
 		      update_pie_chart(jQuery.parseJSON(content));
		}
	    });
    }

    ///////////////////////////////////////////////////////////
    // STREAKER CONNECTION ////////////////////////////////////
    ///////////////////////////////////////////////////////////

    // Needed to draw the pie immediately
    this.update();
    this.update();

    // var updateInterval = window.setInterval(update, refresh);
   

    function update_pie_chart(data) {
	streakerDataAdded = data;

	oldPieData = filteredPieData;
	pieData = donut(streakerDataAdded);

	var totalOctets = 0;
	filteredPieData = pieData.filter(filterData);
	function filterData(element, index, array) {
	    element.name = streakerDataAdded[index].label;
	    element.value = streakerDataAdded[index].value;
	    element.url = streakerDataAdded[index].url;
	    totalOctets += element.value;
	    return (element.value > 0);
	}
  
	if((filteredPieData.length > 0) && (oldPieData.length > 0)) {
	    //REMOVE PLACEHOLDER CIRCLE
	    arc_group.selectAll("circle").remove();

	    if(totalValue) {
		totalValue.text(function() {
		    var kb = totalOctets/1024;
		    return kb.toFixed(1);
		    //return bchart.label.abbreviated(totalOctets*8);
		});
	    }

	    //DRAW ARC PATHS
	    paths = arc_group.selectAll("path").data(filteredPieData);
	    paths.enter().append("svg:path")
		.attr("stroke", "white")
		.attr("stroke-width", 0.5)
		.attr("fill", function(d, i) { return color(i); })
		.transition()
		.duration(tweenDuration)
		.attrTween("d", pieTween);
	    paths
		.transition()
		.duration(tweenDuration)
		.attrTween("d", pieTween);
	    paths.exit()
		.transition()
		.duration(tweenDuration)
		.attrTween("d", removePieTween)
		.remove();

	    //DRAW TICK MARK LINES FOR LABELS
	    lines = label_group.selectAll("line").data(filteredPieData);
	    lines.enter().append("svg:line")
		.attr("x1", 0)
		.attr("x2", 0)
		.attr("y1", -r-3)
		.attr("y2", -r-8)
		.attr("stroke", "gray")
		.attr("transform", function(d) {
			return "rotate(" + (d.startAngle+d.endAngle)/2 * (180/Math.PI) + ")";
		    });
	    lines.transition()
		.duration(tweenDuration)
		.attr("transform", function(d) {
			return "rotate(" + (d.startAngle+d.endAngle)/2 * (180/Math.PI) + ")";
		    });
	    lines.exit().remove();

	    //DRAW LABELS WITH PERCENTAGE VALUES
	    valueLabels = label_group.selectAll("text.value").data(filteredPieData)
		.attr("dy", function(d){
			if ((d.startAngle+d.endAngle)/2 > Math.PI/2 && (d.startAngle+d.endAngle)/2 < Math.PI*1.5 ) {
			    return 5;
			} else {
			    return -7;
			}
		    })
		.attr("text-anchor", function(d){
			if ( (d.startAngle+d.endAngle)/2 < Math.PI ){
			    return "beginning";
			} else {
			    return "end";
			}
		    })
		.text(function(d){
			var percentage = (d.value/totalOctets)*100;
			return percentage.toFixed(1) + "%";
		    });

	    valueLabels.enter().append("svg:text")
		.attr("class", "value")
		.attr("transform", function(d) {
			return "translate(" + Math.cos(((d.startAngle+d.endAngle - Math.PI)/2)) * (r+textOffset) + "," + Math.sin((d.startAngle+d.endAngle - Math.PI)/2) * (r+textOffset) + ")";
		    })
		.attr("dy", function(d){
			if ((d.startAngle+d.endAngle)/2 > Math.PI/2 && (d.startAngle+d.endAngle)/2 < Math.PI*1.5 ) {
			    return 5;
			} else {
			    return -7;
			}
		    })
		.attr("text-anchor", function(d){
			if ( (d.startAngle+d.endAngle)/2 < Math.PI ){
			    return "beginning";
			} else {
			    return "end";
			}
		    }).text(function(d){
			    var percentage = (d.value/totalOctets)*100;
			    return percentage.toFixed(1) + "%";
			});

	    valueLabels.transition().duration(tweenDuration).attrTween("transform", textTween);
	    valueLabels.exit().remove();

	    //DRAW LABELS WITH ENTITY NAMES
	    nameLabels = label_group.selectAll("text.units").data(filteredPieData)
		.attr("dy", function(d){
			if ((d.startAngle+d.endAngle)/2 > Math.PI/2 && (d.startAngle+d.endAngle)/2 < Math.PI*1.5 ) {
			    return 17;
			} else {
			    return 5;
			}
		    })
		.attr("text-anchor", function(d){
			if ((d.startAngle+d.endAngle)/2 < Math.PI ) {
			    return "beginning";
			} else {
			    return "end";
			}
		    }).text(function(d){
			    return d.name;
			})
      .on("click", function(d) { if (d.url) window.location.href = d.url;  });

	    nameLabels.enter().append("svg:text")
		.attr("class", "units")
		.attr("transform", function(d) {
			return "translate(" + Math.cos(((d.startAngle+d.endAngle - Math.PI)/2)) * (r+textOffset) + "," + Math.sin((d.startAngle+d.endAngle - Math.PI)/2) * (r+textOffset) + ")";
		    })
		.attr("dy", function(d){
			if ((d.startAngle+d.endAngle)/2 > Math.PI/2 && (d.startAngle+d.endAngle)/2 < Math.PI*1.5 ) {
			    return 17;
			} else {
			    return 5;
			}
		    })
		.attr("text-anchor", function(d){
			if ((d.startAngle+d.endAngle)/2 < Math.PI ) {
			    return "beginning";
			} else {
			    return "end";
			}
		    }).text(function(d){
			    return d.name;
			})
                .on("click", function(d) { if (d.url) window.location.href = d.url;  });

	    nameLabels.transition().duration(tweenDuration).attrTween("transform", textTween);

	    nameLabels.exit().remove();
	}  
    }

    ///////////////////////////////////////////////////////////
    // FUNCTIONS //////////////////////////////////////////////
    ///////////////////////////////////////////////////////////

    // Interpolate the arcs in data space.
    function pieTween(d, i) {
	var s0;
	var e0;
	if(oldPieData[i]){
	    s0 = oldPieData[i].startAngle;
	    e0 = oldPieData[i].endAngle;
	} else if (!(oldPieData[i]) && oldPieData[i-1]) {
	    s0 = oldPieData[i-1].endAngle;
	    e0 = oldPieData[i-1].endAngle;
	} else if(!(oldPieData[i-1]) && oldPieData.length > 0){
	    s0 = oldPieData[oldPieData.length-1].endAngle;
	    e0 = oldPieData[oldPieData.length-1].endAngle;
	} else {
	    s0 = 0;
	    e0 = 0;
	}
	var i = d3.interpolate({startAngle: s0, endAngle: e0}, {startAngle: d.startAngle, endAngle: d.endAngle});
	return function(t) {
	    var b = i(t);
	    return arc(b);
	};
    }

    function removePieTween(d, i) {
	s0 = 2 * Math.PI;
	e0 = 2 * Math.PI;
	var i = d3.interpolate({startAngle: d.startAngle, endAngle: d.endAngle}, {startAngle: s0, endAngle: e0});
	return function(t) {
	    var b = i(t);
	    return arc(b);
	};
    }

    function textTween(d, i) {
	var a;
	if(oldPieData[i]){
	    a = (oldPieData[i].startAngle + oldPieData[i].endAngle - Math.PI)/2;
	} else if (!(oldPieData[i]) && oldPieData[i-1]) {
	    a = (oldPieData[i-1].startAngle + oldPieData[i-1].endAngle - Math.PI)/2;
	} else if(!(oldPieData[i-1]) && oldPieData.length > 0) {
	    a = (oldPieData[oldPieData.length-1].startAngle + oldPieData[oldPieData.length-1].endAngle - Math.PI)/2;
	} else {
	    a = 0;
	}
	var b = (d.startAngle + d.endAngle - Math.PI)/2;

	var fn = d3.interpolateNumber(a, b);
	return function(t) {
	    var val = fn(t);
	    return "translate(" + Math.cos(val) * (r+textOffset) + "," + Math.sin(val) * (r+textOffset) + ")";
	};
    }

}

///////////////////////////////////////////////////////////
// PUBLIC FUNCIONTS ////////////////////////////////////
///////////////////////////////////////////////////////////


PieChart.prototype.setUrlParams = function(url_params) {
  this.url_params = url_params;
  this.forceUpdate();
}

PieChart.prototype.forceUpdate = function(url_params) {
  this.stopInterval();
  this.update();
  this.startInterval();
}

PieChart.prototype.setInterval = function(p_pieInterval) {
  this.pieInterval = p_pieInterval;
}

PieChart.prototype.stopInterval = function() {
    //disabled graph interval
    clearInterval(this.pieInterval);
}

PieChart.prototype.startInterval = function() {
  this.pieInterval = setInterval(this.update(), this.refresh)
}
///////////////////////////////////////////////////////////
// INIT FUNCIONTS ////////////////////////////////////
///////////////////////////////////////////////////////////

function create_pie_chart(name, units) {
    var w = 500; //380 - Please keep in sync with pie-chart.css
    var h = 325; //280
    var ir = 52; //45
    var textOffset = 14;
    var tweenDuration = 250;
    var r = 116; //100;
    var lines, valueLabels, nameLabels;

    //D3 helper function to populate pie slice parameters from array data
    var donut = d3.layout.pie().value(function(d){
      if (d.value == 0) {d.value = 1;} // Force to 1, in order to update the graph
	    return d.value;
	});

    //D3 helper function to create colors from an ordinal scale
    var color = d3.scale.category20();

    //D3 helper function to draw arcs, populates parameter "d" in path object
    var arc = d3.svg.arc()
	.startAngle(function(d){ return d.startAngle; })
	.endAngle(function(d){ return d.endAngle; })
	.innerRadius(ir)
	.outerRadius(r);

    ///////////////////////////////////////////////////////////
    // CREATE VIS & GROUPS ////////////////////////////////////
    ///////////////////////////////////////////////////////////

    var vis = d3.select(name).append("svg:svg")
	.attr("width", w)
	.attr("height", h)
	.attr("viewBox","0 0 500 325") 
	.attr("preserveAspectRatio","xMidYMid");

    //GROUP FOR ARCS/PATHS
    var arc_group = vis.append("svg:g")
	.attr("class", "arc")
	.attr("transform", "translate(" + (w/2) + "," + (h/2) + ")");

    //GROUP FOR LABELS
    var label_group = vis.append("svg:g")
	.attr("class", "label_group")
	.attr("transform", "translate(" + (w/2) + "," + (h/2) + ")");

    //GROUP FOR CENTER TEXT  
    var center_group = vis.append("svg:g")
	.attr("class", "center_group")
	.attr("transform", "translate(" + (w/2) + "," + (h/2) + ")");

    //PLACEHOLDER GRAY CIRCLE
    var paths = arc_group.append("svg:circle")
	.attr("fill", "#EFEFEF")
	.attr("r", r);

    ///////////////////////////////////////////////////////////
    // CENTER TEXT ////////////////////////////////////////////
    ///////////////////////////////////////////////////////////

    //WHITE CIRCLE BEHIND LABELS
    var whiteCircle = center_group.append("svg:circle")
	.attr("fill", "white")
	.attr("r", ir);

    var totalUnits = null;
    var totalLabel = null;
    var totalValue = null;

    if(units) {
	// "TOTAL" LABEL
	totalLabel = center_group.append("svg:text")
	    .attr("class", "label")
	    .attr("dy", -15)
	    .attr("text-anchor", "middle") // text-align: right
	    .text("TOTAL");

	//TOTAL TRAFFIC VALUE
	totalValue = center_group.append("svg:text")
	    .attr("class", "total")
	    .attr("dy", 7)
	    .attr("text-anchor", "middle") // text-align: right
	    .text("Waiting...");

	//UNITS LABEL
	totalUnits = center_group.append("svg:text")
	    .attr("class", "units")
	    .attr("dy", 21)
	    .attr("text-anchor", "middle") // text-align: right
	    .text(units);
    }

    return([arc_group, donut, totalValue, totalUnits, color, tweenDuration, arc, label_group, center_group, r, textOffset]);
}
