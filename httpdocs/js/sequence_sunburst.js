// Wrapper function
function do_sequence_sunburst(circle_name,sequence_name,refresh,update_url,url_params,title,units) {
  var graph = new SequenceSunburst(circle_name,sequence_name,refresh,update_url,url_params,title,units);
  graph.setInterval(window.setInterval(function(){graph.update();}, refresh));
  // Return new class instance, with
  return [graph];
}


function SequenceSunburst(circle_name,sequence_name,refresh,update_url,url_params,title,units) {

  // Add object properties like this
  this.circle_name = circle_name;
  this.sequence_name = sequence_name;
  this.update_url = update_url;
  this.url_params = url_params;
  this.units = units;
  this.refresh = refresh;
  this.sunburstInterval;

  var oldPieData = [];
  var filteredPieData = [];

  var rsp = create_sequence_sunburst(circle_name,sequence_name,title,units);
  var color = rsp[0];
  var partition = rsp[1];
  var totalSize = rsp[2];
  var arc = rsp[3];
  var arc_group = rsp[4];
  var trail = rsp[5];
  var whiteCircle = rsp[6];
  var totalLabel = rsp[7];
  var totalValue = rsp[8];
  var totalUnits = rsp[9];
  var radius = rsp[10];
  var width = rsp[11];
  var height = rsp[12];
  var b = rsp[13];

  var last_process = "";
  var last_byte = 0;
  var substring_limit = 8;


  // to run each time data is generated
  this.update = function () {
    $.ajax({
      type: 'GET',
      url: this.update_url,
      data: this.url_params,
      success: function(content) {
        update_sequence_sunburst(jQuery.parseJSON(content));
      },
      error: function(content) {
        console.log("error");
      }
    });
  }

  ///////////////////////////////////////////////////////////
  // STREAKER CONNECTION ////////////////////////////////////
  ///////////////////////////////////////////////////////////

  // Needed to draw the pie immediately
  this.update();

  // var updateInterval = window.setInterval(update, refresh);

  ///////////////////////////////////////////////////////////
  // UPDATE FUNCIONTS ////////////////////////////////////
  ///////////////////////////////////////////////////////////
  this.falshUpdate = function (start,end) {
    arc_group.selectAll("path").style("opacity", start)
    .transition().duration(200).style("opacity", end);
  }


  function update_sequence_sunburst(data) {
    streakerDataAdded = data;
    // console.log(data);
    oldPieData = filteredPieData;
    pieData = partition.nodes(streakerDataAdded);
    
    filteredPieData = pieData.filter(function(d) {
      return (d.dx > 0.005); // 0.005 radians = 0.29 degrees
    });

    if((filteredPieData.length > 0) && (oldPieData.length > 0)) {
      //REMOVE PLACEHOLDER CIRCLE
      arc_group.selectAll("circle").remove();
      arc_group.selectAll("path").remove();
      // alert("Update");
    }

    paths = arc_group.selectAll("path").data(filteredPieData);

    paths.enter().append("svg:path")
    .attr("display", function(d) { return d.depth ? null : "none"; })
    .attr("d", arc)
    .attr("fill-rule", "evenodd")
    .style("fill", function(d) { return color(d.name+d.id); })
    .style("opacity", 1)
    .on("mouseover", mouseover)
    .on("dblclick",function(d) {if(d.url) window.location.href = d.url; });

    // Add the mouseleave handler to the bounding circle.
    d3.select("#container"+circle_name).on("mouseleave", mouseleave);

    // Get total size of the tree = value of root node from partition.
    totalSize = paths.node().__data__.value;

   filteredPieData.forEach(function(d) {
     
    if ((last_process.localeCompare(d.name) == 0) && (d.name != "")){
      
      var data = bytesToVolumeAndLabel(d.value);
      var value = data[0]
      if (last_byte < d.value) {
        value = data[0]+ ' \uf062';
      }else if (last_byte > d.value) {
        value = data[0]+ ' \uf063';
      } else {
        value = data[0]+ ' \uf068';
      }
      
      var name = d.name.substring(0,substring_limit);
      if (d.name.length > substring_limit) {name = name + "..";}

      totalValue.text(value);
      totalLabel.text(name);
      totalUnits.text(data[1]);
    };


   });
   
  }

///////////////////////////////////////////////////////////
// UTILS FUNCTIONS ////////////////////////////////////
///////////////////////////////////////////////////////////

  function mouseover(d) {

    var percentage = (100 * d.value / totalSize).toPrecision(3);
    var percentageString = percentage + "%";
    if (percentage < 0.1) {
      percentageString = "< 0.1%";
    }
    var data = bytesToVolumeAndLabel(d.value);

    totalValue.text(data[0]);
    totalLabel.text(d.name);
    totalUnits.text(data[1]);
    last_process = d.name;
    last_byte = d.value;
    
    var sequenceArray = getAncestors(d);
    updateBreadcrumbs(sequenceArray, percentageString);

    // Fade all the segments.
    arc_group.selectAll("path")
    .style("opacity", 0.3);

    // Then highlight only those that are an ancestor of the current segment.
    arc_group.selectAll("path")
    .filter(function(node) 
      {
        return (sequenceArray.indexOf(node) >= 0);
      })
      .style("opacity", 1);
  };

  // Restore everything to full opacity when moving off the visualization.
  function mouseleave(d) {

    // Hide the breadcrumb trail
    trail.style("visibility", "hidden");

    // Deactivate all segments during transition.
    arc_group.selectAll("path").on("mouseover", null);

    // Transition each segment to full opacity and then reactivate it.
    arc_group.selectAll("path")
    .transition()
    .duration(500)
    .style("opacity", 1)
    .each("end", function() {
      d3.select(this).on("mouseover", mouseover);
    });
    
   

  };

  // Given a node in a partition layout, return an array of all of its ancestor
  // nodes, highest first, but excluding the root.
  function getAncestors(node) {
    var path = [];
    var current = node;
    while (current.parent) {
      path.unshift(current);
      current = current.parent;
    }
    return path;
  }

  // Initialize the Breadcrumb as default
  function initializeBreadcrumbTrail(circle_name,sequence_name) {
    // Add the svg area.
    var trail = d3.select("#"+sequence_name).append("svg:svg")
    .attr("width", width)
    .attr("height", 50)
    .attr("id", "trail");
    // Add the label at the end, for the percentage.
    trail.append("svg:text")
    .attr("id", "endlabel")
    .style("fill", "#000");

    return trail;
  }

  // Generate a string that describes the points of a breadcrumb polygon.
  function breadcrumbPoints(d, i) {
    var points = [];
    points.push("0,0");
    points.push(b.w + ",0");
    points.push(b.w + b.t + "," + (b.h / 2));
    points.push(b.w + "," + b.h);
    points.push("0," + b.h);
    if (i > 0) { // Leftmost breadcrumb; don't include 6th vertex.
    points.push(b.t + "," + (b.h / 2));
  }
  return points.join(" ");
  }

  // Update the breadcrumb trail to show the current sequence and percentage.
  function updateBreadcrumbs(nodeArray, percentageString) {

    // Data join; key function combines name and depth (= position in sequence).
    var g = trail.selectAll("g")
    .data(nodeArray, function(d) { return d.name + d.depth; });

    // Add breadcrumb and label for entering nodes.
    var entering = g.enter().append("svg:g");

    entering.append("svg:polygon")
      .attr("points", breadcrumbPoints)
      .style("fill", function(d) { return color(d.name+d.id); });

    entering.append("svg:text")
      .attr("x", (b.w + b.t) / 2)
      .attr("y", b.h / 2)
      .attr("dy", "0.35em")
      .attr("text-anchor", "middle")
      .text(function(d) 
        { 
          var name = d.name.substring(0,substring_limit);
          if (d.name.length > substring_limit) {name = name + "..";}
          return (name); 
        });

    // Set position for entering and updating nodes.
    g.attr("transform", function(d, i) {
      return "translate(" + i * (b.w + b.s) + ", 0)";
    });

    // Remove exiting nodes.
    g.exit().remove();

    // Now move and update the percentage at the end.
    trail.select("#endlabel")
    .attr("x", (nodeArray.length + 0.5) * (b.w + b.s))
    .attr("y", b.h / 2)
    .attr("dy", "0.35em")
    .attr("text-anchor", "middle")
    .text(percentageString);

    // Make the breadcrumb trail visible, if it's hidden.
    trail.style("visibility", "");

  }

///////////////////////////////////////////////////////////
// INIT FUNCIONTS ////////////////////////////////////
///////////////////////////////////////////////////////////

  function create_sequence_sunburst(circle_name, sequence_name,title,units) {
    // Dimensions of sunburst.
    var width = 600;
    var height = 280;
    var radius = 120;
    // Total size of all segments; we set this later, after loading the data.
    var totalSize = 0; 

    // Breadcrumb dimensions: width, height, spacing, width of tip/tail.
    var b = {
      w: 60, h: 25, s: 3, t: 10
    };

    //D3 helper function to create colors from an ordinal scale
    var color = d3.scale.category20c();

    var partition = d3.layout.partition()
      .size([2 * Math.PI, radius * radius])
      .value(function(d) { return d.size; });

    var totalSize = 0; 

    //D3 helper function to draw arcs, populates parameter "d" in path object
    var arc = d3.svg.arc()
      .startAngle(function(d) { return d.x; })
      .endAngle(function(d) { return d.x + d.dx; })
      .innerRadius(function(d) { return Math.sqrt(d.y); })
      .outerRadius(function(d) { return Math.sqrt(d.y + d.dy); });


    var vis = d3.select("#"+circle_name).append("svg:svg")
      .attr("width", width)
      .attr("height", height);

    var arc_group = vis.append("svg:g")
      .attr("id", "container"+circle_name)
      .attr("transform", "translate(" + (width / 2) + "," + (height / 2) + ")");

    // Basic setup of page elements.
    var trail = initializeBreadcrumbTrail(circle_name,sequence_name,width);

    var whiteCircle = arc_group.append("svg:circle")
      .attr("fill", "white")
      .attr("r", radius);

    // LABEL
    totalLabel = arc_group.append("svg:text")
      .attr("class", "label_sunburst")
      .attr("dy", -25)
      .attr("text-anchor", "middle")
      .attr('font-family', 'FontAwesome')
      .text("");

    //PERCENT
    totalValue = arc_group.append("svg:text")
      .attr("class", "total")
      .attr("dy", 7)
      .attr("text-anchor", "middle")
      .attr('font-family', 'FontAwesome')
      .text("");

    //UNITS LABEL
    totalUnits = arc_group.append("svg:text")
      .attr("class", "units")
      .attr("dy",30)
      .attr("text-anchor", "middle")
      .text("");

    return([color, partition, totalSize, arc, arc_group, trail, whiteCircle, totalLabel, totalValue, totalUnits, radius,width,height,b]);

  } //End function create_sequence_sunburst
  
  this.resetCentralCirleText = function (){
    totalValue.text(" ");
    totalLabel.text(" ");
    totalUnits.text("");
  }


}

///////////////////////////////////////////////////////////
// PUBLIC FUNCIONTS ////////////////////////////////////
///////////////////////////////////////////////////////////

SequenceSunburst.prototype.setUrlParams = function(url_params) {
  this.url_params = url_params;
  this.resetCentralCirleText();
  this.forceUpdate();
}

SequenceSunburst.prototype.forceUpdate = function(url_params) {  
  // this.stopInterval();
  this.falshUpdate(0,1);
  this.update();
  // this.startInterval();
}

SequenceSunburst.prototype.setInterval = function(p_sunburstInterval) {
  this.sunburstInterval = p_sunburstInterval;
}

SequenceSunburst.prototype.stopInterval = function() {
  //disabled graph interval
    window.clearInterval(this.sunburstInterval);
}

SequenceSunburst.prototype.startInterval = function() {
  this.sunburstInterval = window.setInterval(this.update(), this.refresh)
}
