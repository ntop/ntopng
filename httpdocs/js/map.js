var map = (function (addr) {

    // dimensions and margins of the graph
    var margin = {top: 5, right: 10, bottom: 110, left: 100},
    width = 300 - margin.left - margin.right,
    height = 140 - margin.top - margin.bottom;

    var build = function(addr) {

        var svg = d3.select("#my_dataviz")
        .append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform",
                "translate(" + margin.left + "," + margin.top + ")");

        
        d3.json("/lua/get_mac_arp_data.lua?host="+addr, function (data) {

        var Xelements = d3.map(data, function(d){return d.x_label;}).keys()
        var Yelements = d3.map(data, function(d){return d.y_label;}).keys()

        console.log(data);

        // color scale
        var myColor = d3.scaleSequential()
            .interpolator(d3.interpolateInferno) //TODO: choose a chromatic scale [ https://github.com/d3/d3-scale-chromatic ]
            .domain([1,200])

        //width relative to receivers
        width = (Xelements.length * 20);
        

        if ( width > 800) width = 800 - margin.left - margin.right;
        if ( width < 150 )  width = 150  - margin.left - margin.right;

        console.log("myGroup dim:"+Xelements.length+" , width: "+width)

        // X scales and axis:
        var x = d3.scaleBand()
            .range([ 0, width ])
            .domain(Xelements)
            .padding(0.05);
        svg.append("g")
            .style("font-size", 10)
            .attr("transform", "translate(0," + height + ")")
            .call(d3.axisBottom(x).tickSize(0))
            .selectAll("text")	
                .style("text-anchor", "end")
                .attr("dx", "-.8em")
                .attr("dy", ".15em")
                .attr("transform", "rotate(-60)")
                .select(".domain").remove();


        // Y scales and axis:
        var y = d3.scaleBand()
            .range([ height, 0 ])
            .domain(Yelements)
            .padding(0.05);
        svg.append("g")
            .style("font-size", 10)
            .call(d3.axisLeft(y).tickSize(0))
            .selectAll("text")
            .attr("dx", "-0.5em")
            .select(".domain").remove();
            

        // Tooltip and related events
        var tooltip = d3.select("#my_dataviz")
            .append("div")
            .attr("class", "tooltip")
            .style("opacity", 0);
            
        var mouseover = function(d) {
            tooltip
            .style("opacity", 0.9)
            d3.select(this)
            .style("stroke", "black")
        }
        var mousemove = function(d) {
            tooltip
            .html("Requests Sent: " + d.value)
            .style("left", (d3.event.pageX + 5) + "px")
            .style("top", (d3.event.pageY - 35) + "px")
        }
        var mouseleave = function(d) {
            tooltip.style("opacity", 0)
            d3.select(this)
            .style("stroke", "none")
        }

        //label click
        function labelClick(d){
          var url = window.location.href;
          var segements = url.split("/");
          segements[segements.length - 1] = "host_details.lua?host="+d;
          window.location.href = segements.join("/");
            
        }
        d3.selectAll('.tick text')
                .on('click',labelClick);

        // squares
        svg.selectAll()
            .data(data, function(d) {return d.x_label+':'+d.y_label;})
            .enter()
            .append("rect")
            .attr("x", function(d) { return x(d.x_label) })
            .attr("y", function(d) { return y(d.y_label) })
            .attr("rx", 4)
            .attr("ry", 4)
            .attr("width", x.bandwidth() )
            .attr("height", y.bandwidth() )
            .style("fill", 
                function(d) {
                if (d.value == 0)
                    return "whitesmoke";
                else 
                    return myColor(d.value);
                }  
            )
            .style("stroke-width", 4)
            .style("stroke", "none")
            .style("opacity", 1)
            .on("mouseover", mouseover)
            .on("mousemove", mousemove)
            .on("mouseleave", mouseleave);

                    //apply svg resize
        d3.select("#my_dataviz")
        .select("svg")
            .attr("width", width + margin.left + margin.right);
            console.log("before exit build: "+width)
        });//END BUILD

        //X axis description
        svg.append('text')
                .attr('x', width / 2  )
                .attr('y', height + margin.bottom - margin.top/2)
                .attr('text-anchor', 'middle')
                .text('Receivers');



    }
    
    return {
        build:build
    }
  })();





//################################################################
/*one way to create (encapsulated) module

  var myGradesCalculate = (function () {
    
    // Keep this y_label private inside this closure scope
    var myGrades = [93, 95, 88, 0, 55, 91];
    
    var average = function() {
      var total = myGrades.reduce(function(accumulator, item) {
        return accumulator + item;
        }, 0);
        
      return'Your average grade is ' + total / myGrades.length + '.';
    };
  
    var failing = function() {
      var failingGrades = myGrades.filter(function(item) {
          return item < 70;
        });
  
      return 'You failed ' + failingGrades.length + ' times.';
    };
  
    // Explicitly reveal public pointers to the private functions 
    // that we want to reveal publicly
  
    return {
      average: average,
      failing: failing
    }
  })();

  */
  //################################################################