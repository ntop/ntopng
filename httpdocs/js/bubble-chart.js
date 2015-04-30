// Wrapper function
function do_bubble_chart(contanerId,update_url,url_params,refresh) {
  var bubble = new BubbleChart(contanerId,update_url,url_params);
  if (refresh)
    bubble.setInterval(setInterval(function(){bubble.update();}, refresh));
  
  // Return new class instance, with
  return bubble;
}


function BubbleChart(contanerId,update_url,url_params) {

   // Add object properties like this
  this.contanerId = contanerId;
  this.update_url = update_url;
  this.url_params = url_params;
  this.bubbleInterval;
  
  var rsp = create_bubble_chart(contanerId);
  var margin = rsp[0];
  var width = rsp[1];
  var height = rsp[2];
  var svg_bubble = rsp[3];
  var bubble = rsp[4];
  var color = rsp[5];
  
  var node;
  
  // to run each time data is generated
  this.update = function () {

    $.ajax({
      type: 'GET',
      url: this.update_url,
      data: this.url_params,
      success: function(content) {
        update_bubble_chart(jQuery.parseJSON(content));
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
  // UPDATE FUNCIONTS ///////////////////////////////////////
  ///////////////////////////////////////////////////////////
  this.falshUpdate = function (start,end) {
    svg_bubble.selectAll(".node").style("opacity", start)
    .transition().duration(200).style("opacity", end);
  }

  function update_bubble_chart(data) {
    // alert("update");
   d3.select("#"+contanerId).selectAll(".node").remove();

    var node = svg_bubble.selectAll(".node")
        .data(bubble.nodes(classes(data))
        .filter(function(d) { return !d.children; }))
        .enter().append("g")
        .attr("class", "node")
        .attr("transform", function(d) { return "translate(" + ((height/2) + d.x - 70) + "," + ((width/2)- d.y + 50) + ")"; });
        

    node.append("title")
        .text(function(d) { return d.className + ": " + bytesToVolume(d.value) + "\n Double click to show more information about this flows."; });

    node.append("circle")
        .attr("r", function(d) { return (d.r); })
        .style("fill", function(d) { return color(d.r+d.className); })
        .on("dblclick",function(d) {if(d.url) window.location.href = d.url; });

    node.append("text")
        .attr("dy", ".3em")
        .style("text-anchor", "middle")
        .text(function(d) { return d.className.substring(0, d.r / 3); })
        .on("dblclick",function(d) {if(d.url) window.location.href = d.url; });
  }
  ///////////////////////////////////////////////////////////
  // UTILS FUNCTIONS ////////////////////////////////////////
  ///////////////////////////////////////////////////////////
  // Returns a flattened hierarchy containing all leaf nodes under the root.
  function classes(root) {
    var classes = [];

    function recurse(name, node) {
      if (node.children) node.children.forEach(function(child) { recurse(node.name, child); });
      else classes.push({packageName: name, className: node.name, value: node.size, aggregation: node.aggregation, key: node.key, url: node.url});
    }

    recurse(null, root);
    return {children: classes};
  }


}
///////////////////////////////////////////////////////////
// PUBLIC FUNCIONTS ////////////////////////////////////
///////////////////////////////////////////////////////////


BubbleChart.prototype.setUrlParams = function(url_params) {  
  this.url_params = url_params;
}

BubbleChart.prototype.forceUpdate = function(url_params) {  
  this.stopInterval();
  this.falshUpdate(0,1);
  this.update();
  this.startInterval();
}

BubbleChart.prototype.setInterval = function(p_bubbleInterval) {
  this.bubbleInterval = p_bubbleInterval;
}

BubbleChart.prototype.stopInterval = function() {
    //disabled graph interval
    clearInterval(this.bubbleInterval);
  }

BubbleChart.prototype.startInterval = function() {
  this.bubbleInterval = setInterval(this.update(), this.refresh)
}

///////////////////////////////////////////////////////////
// INIT FUNCIONTS ////////////////////////////////////
///////////////////////////////////////////////////////////

function create_bubble_chart(contanerId) {
  
  var margin = {top: 1, right: 1, bottom: 6, left: 1},
      width = 600 - margin.left - margin.right,
      height = 400 - margin.top - margin.bottom;

  var diameter = 320,
      format = d3.format(",d"),
      color = d3.scale.category20c();

  
  var svg_bubble = d3.select("#"+contanerId).append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("class", "bubble");

  var bubble = d3.layout.pack()
      .sort(null)
      .size([diameter, diameter])
      .padding(1.5);

  
  d3.select(self.frameElement).style("height", diameter + "px");


  return([margin, width, height, svg_bubble, bubble,color]);

}

