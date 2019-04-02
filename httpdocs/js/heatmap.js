var map = (function () {

        
    // base dimensions and margins of the graph
    var margin = {top: 80, right: 20, bottom: 120, left: 150},
    width = 1100 - margin.left - margin.right,
    height = 900 - margin.top - margin.bottom;

    var build = function() {        

        var svg = d3.select("#my_dataviz")
        .append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform",
                "translate(" + margin.left + "," + margin.top + ")");

        d3.json("/lua/get_arp_matrix_data.lua", function (data) {

            //( group = X axis, variable = Y axis )
            // Labels of row and columns -> unique identifier of the column called 'group' and 'variable'
            var myGroups = d3.map(data, function(d){return d.group;}).keys()
            var myVars = d3.map(data, function(d){return d.variable;}).keys()

            //TODO: test with a lot/few elem
            //change graph dimension based on #senders/receivers 
            var sq_h = 25;
            var sq_w = 25;

            width = (myGroups.length * sq_w);
            height = (myVars.length * sq_h) ;

            if (height > 900 ) height = 900  - margin.top - margin.bottom;
            if (height < 350 ) height = 350  - margin.top - margin.bottom;
            if ( width > 1100) width = 1100 - margin.left - margin.right;
            if ( width < 666 )  width = 666  - margin.left - margin.right;//tmp for not clip the legend, see TODO in text section
            

            // color scale
            var myColor = d3.scaleSequential()
                .interpolator(d3.interpolateInferno) //TODO: choose a chromatic scale [ https://github.com/d3/d3-scale-chromatic ]
                .domain([1,200])

            var sendersTotPkts = {};

            d3.map(data).values().forEach(e => {
                if ( sendersTotPkts.hasOwnProperty(e.variable) )
                sendersTotPkts[e.variable] += e.value;
                else
                sendersTotPkts[e.variable] = e.value;
            });

            // X scales and axis:
            var x = d3.scaleBand()
                .range([ 0, width ])
                .domain(myGroups)
                .padding(0.05);
            svg.append("g")
                .style("font-size", 10)
                .attr("transform", "translate(0," + height + ")")
                .call(d3.axisBottom(x).tickSize(0))
                //.select(".domain").remove()
                .selectAll("text")	
                    .style("text-anchor", "end")
                    .attr("dx", "-.8em")
                    .attr("dy", ".15em")
                    .attr("transform", "rotate(-65)")



            // Y scales and axis:
            var y = d3.scaleBand()
                .range([ height, 0 ])
                .domain(myVars)
                .padding(0.05);
            var gY = svg.append("g")
                .style("font-size", 10)
                .call(d3.axisLeft(y).tickSize(0))
                .selectAll("text")
                .attr("dx", "-2.5em");
                //.style("fill", function(e) {
                //    return myColor( sendersTotPkts[e] );
                //});

                //.select(".domain").remove()


            //Yaxis sender rect
            svg.selectAll()
                .data(data, function(d) {return d.variable;})
                .enter()
                .append("rect")
                .attr("x", function(d) { return -16 })
                .attr("y", function(d) { return y(d.variable) })
                .attr("rx", 4)
                .attr("ry", 4)
                .attr("width", 8 )
                .attr("height", y.bandwidth() )
                .style("fill", 
                    function(d) {
                    if (d.value == 0)
                        return "whitesmoke";
                    else 
                        return myColor( sendersTotPkts[d.variable] );
                    }  
                )
                .style("stroke-width", 0)
                .style("stroke", "black");



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

            // squares
            svg.selectAll()
                .data(data, function(d) {return d.group+':'+d.variable;})
                .enter()
                .append("rect")
                .attr("x", function(d) { return x(d.group) })
                .attr("y", function(d) { return y(d.variable) })
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


            //X axis description
            svg.append('text')
                .attr('x', width - 50  )
                .attr('y', height + 110  )
                .attr('text-anchor', 'middle')
                .text('Receivers')

            
            //Y axis description
            svg.append('text')
                    .attr('x', -40 )
                    .attr('y', -margin.left/2 - 55)
                    .attr('transform', 'rotate(-90)')
                    .attr('text-anchor', 'middle')
                    .text('Senders')   

            //apply svg resize
            d3.select("#my_dataviz")
                .select("svg")
                    .attr("width", width + margin.left + margin.right)
                    .attr("height", height + margin.top + margin.bottom);

            function clickMe(d){
                var newnumber = 175;
                var url = window.location.href;
                var segements = url.split("/");
                segements[segements.length - 1] = "mac_details.lua?host="+d;
                var newurl = segements.join("/");
                window.location.href = newurl;   
            }
            d3.selectAll('.tick text')
                    .on('click',clickMe);

            
                    //window.location.href = "https://www.example.com"
            console.log(window.location.href)
        });




        //__________________________________________________//
        //____________________TEXTnPICS_____________________//
        //TODO: maybe is better add the text/img in the html file and not svg

        // Add title to graph
        svg.append("text")
                .attr("x", 0)
                .attr("y", -50)
                .attr("text-anchor", "left")
                .style("font-size", "22px")
                .text("ARP Map");

        // Add subtitle to graph
        svg.append("text")
                .attr("x", 0)
                .attr("y", -20)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .style("fill", "grey")
                .style("max-width", 400)
                .text("Senders on Y axis, Receivers on X axis ");

        // heatmap range info (1)
        svg.append("text")
                .attr("x", 292)
                .attr("y", -20)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .text("1 pkt");
                
        // heatmap range info (100)
        svg.append("text")
                .attr("x", 292 + 170)
                .attr("y", -20)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .text("200 pkt");

        //the heatmap image near the title
        svg.append("image")
                .attr("x", 80)
                .attr("y", -70)
                .attr("height", 20)
                .attr("width", 600)
                .attr("xlink:href", "../img/inferno.png")
                .style("stroke","black")
                .style("stroke-width", "2px");

        //border of heatmap image
        svg.append("rect")
                .attr("x", 295)
                .attr("y", -71)
                .attr("height", 22)
                .attr("width", 170)
                .style("fill", "transparent")
                .style("stroke","black")
                .style("stroke-width", "2px");

        //___________________________________________________________//        
    }
    
    return {
        build:build
    }
})();