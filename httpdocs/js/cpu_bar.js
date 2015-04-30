
var y = d3.scale.linear()
  .domain([0, 100])
  .range([0, 100]);

function cpu_display_stacked_chart(chartId) {
	var vis = d3.select("#" + chartId)
	  .append("svg:svg")
	    .attr("width", "100%")
	    .attr("height", "100%")
	  .append("g")
	    .attr("class","barChart")
	    .attr("transform", "translate(0, " + bar_h + ")"); 
}

var cpu_propertyNames = ["system", "irq", "user", "iowait"];

function update_cpu_core(chartId, data) {
	var existingBarNode = document.querySelectorAll("#" + chartId + "_" + data.id);
	if(existingBarNode.length > 0) {
		// data already exists for this data ID, update it
		var existingBar = d3.select(existingBarNode.item());
		existingBar.transition().duration(100)
			.attr("style", "opacity:1.0");
		for(index in cpu_propertyNames) {
			existingBar.select("rect." + cpu_propertyNames[index])
				.transition().ease("linear").duration(300)
				.attr("y", cpu_bar_y(data, cpu_propertyNames[index])) 
				.attr("height", cpu_bar_height(data, cpu_propertyNames[index])); 
		}
	} else {
		// add a bar
		var barDimensions = cpu_update_bar_widths_and_placement(chartId);
		var barGroup = d3.select("#" + chartId).selectAll("g.barChart")
			.append("g")
				.attr("class", "bar y axis")
				.attr("id", chartId + "_" + data.id)
				.attr("style", "opacity:1.0");
		for(index in cpu_propertyNames) {
			barGroup.append("rect")
				.attr("class", cpu_propertyNames[index])
			    .attr("width", (barDimensions.barWidth-1)) 
			    .attr("x", function () { return (barDimensions.cpu_num_bars-1) * barDimensions.barWidth;})
			    .attr("y", cpu_bar_y(data, cpu_propertyNames[index])) 
			    .attr("height", cpu_bar_height(data, cpu_propertyNames[index])); 
		}
		barGroup.styleInterval = setInterval(function() {
				var theBar = document.getElementById(chartId + "_" + data.id);
				if(theBar == undefined) {
					clearInterval(barGroup.styleInterval);
				} else {
					if(theBar.style.opacity > 0.2) {
						theBar.style.opacity = theBar.style.opacity - 0.05;	
					}
				}
			}, 1000);
	}
}

function cpu_update_bar_widths_and_placement(chartId) {
	var barWidth = bar_w/cpu_num_bars;
	var barNodes = document.querySelectorAll(("#" + chartId + " g.barChart g.bar"));
	for(var i=0; i < barNodes.length; i++) {
		d3.select(barNodes.item(i)).selectAll("rect")
			//.transition().duration(10)
			.attr("x", i * barWidth)
			.attr("width", (barWidth-1));
	}
	return {"barWidth":barWidth, "cpu_num_bars":cpu_num_bars};
}

function cpu_bar_y(data, propertyOfDataToDisplay) {
	var baseline = 0;
	for(var j=0; j < index; j++) {
		baseline = baseline + data[cpu_propertyNames[j]];
	}
	return -y(baseline + data[propertyOfDataToDisplay]);
}

function cpu_bar_height(data, propertyOfDataToDisplay) {
	return data[propertyOfDataToDisplay];
}

cpu_display_stacked_chart("cpu-bar-chart");

function cpu_update() {
  var ratio = (bar_h / 100);
  for (i=0;i < cpu.length;i++) {
	update_cpu_core("cpu-bar-chart", {
      "id":    "core" + i, 
      "system":cpu[i]['system']*ratio, 
      "irq":   cpu[i]['irq']*ratio, 
      "iowait":cpu[i]['iowait']*ratio, 
      "user":  cpu[i]['user']*ratio
    });
  }
}


