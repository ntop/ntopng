var map = (function () {

    var isDetail = false;
    var address;
    var interval = 5000;
    var intervalID;
    var stopInterval = false;

    // base dimensions and margins of the graph
    var margin = {top: 80, right: 20, bottom: 120, left: 150},
    width = 1100 - margin.left - margin.right,
    height = 800 - margin.top - margin.bottom;

    //window height and width
    var w_h, w_w;

    var max_X_elem, max_Y_elem;

    //flag used to alternate the svg containers (for updates)
    var svgFlag = true;
    var svg;

    //axis
    var x,y;

    //square dim
    var sq_h = 12;
    var sq_w = 12;

    var tooltip;

    //axis elements (label)
    var X_elements;
    var Y_elements;

    //color scale
    var myColor;

    var sendersTotPkts = {};
    var receiversTotPkts = {};
    var maxTotPkt = 0;

    //----------MOUSE EVENT---------------
    var mouseoverSquare = function(d) {
        tooltip.style("opacity", 0.9)
        d3.select(this)
        .style("stroke", "black")

        tooltip.html("Pkt num: " + d.value)
        .style("left", (d3.event.pageX ) + "px")
        .style("top", (d3.event.pageY - 35) + "px")

        d3.selectAll(".x_label")
        .filter(function(e){
            return e == d.x_label;
        })
        .style("fill", "red" )
        .style("font-size", 11)

        d3.selectAll(".y_label")
        .filter(function(e){
            return e == d.y_label;
        })
        .style("fill", "red" )
        .style("font-size", 11)
    }
    var mouseleaveSquare = function(d) {
        tooltip.style("opacity", 0)
        d3.select(this)
        .style("stroke", "none")

        d3.selectAll(".x_label, .y_label")
        .style("fill", "black" )
        .style("font-size", 11)
    }
    var labelClick = function(d){
        var url = window.location.href;
        var segements = url.split("/");
        segements[segements.length - 1] = "host_details.lua?host="+d;
        window.location.href = segements.join("/"); 
    }
    var mouseoverYAxisSquare = function(d){
        d3.selectAll(".y_label")
        .filter(function(e){
            return e == d.y_label;
        })
        .style("fill", "red" )
        .style("font-size", 11)

        var match = new Array();

        d3.selectAll(".squares").filter(function(e){
            if (e.y_label == d.y_label)
                match.push(e.x_label);
        })

        d3.selectAll(".x_label")
        .filter(function(e){
            return match.includes(e);
        })
        .style("fill", "red" )
        .style("font-size", 11)

        d3.selectAll(" .squares")
        .filter(function(e){
            return d.y_label == e.y_label;
        })
        .style("stroke", "black")

    };
    var mouseleaveYAxisSquare = function(d){
        d3.selectAll(".x_label, .y_label")
        .style("fill", "black" )
        .style("font-size", 11)

        d3.selectAll(" .squares")
        .style("stroke", "none")
    };
    var mouseoverYLabel = function(d){
        d3.select(this)
        .style("fill", "red" )
        .style("font-size", 11);

        var match = new Array();

        d3.selectAll(".squares").filter(function(e){
            if (e.y_label == d)
                match.push(e.x_label);
        })

        d3.selectAll(".x_label")
        .filter(function(e){
            return match.includes(e);
        })
        .style("fill", "red" )
        .style("font-size", 11);

        d3.selectAll(" .squares")
        .filter(function(e){
            return d == e.y_label;
        })
        .style("stroke", "black");
    };
    var mouseleaveYlabel = function(d){
        d3.selectAll(".x_label, .y_label")
        .style("fill", "black" )
        .style("font-size", 11)

        d3.selectAll(" .squares")
        .style("stroke", "none")

    };
    var mouseoverXLabel = function(d){
        d3.select(this)
        .style("fill", "red" )
        .style("font-size", 11);

        var match = new Array();

        d3.selectAll(".squares").filter(function(e){
            if (e.y_label == d)
                match.push(e.y_label);
        })

        d3.selectAll(".y_label")
        .filter(function(e){
            return match.includes(e);
        })
        .style("fill", "red" )
        .style("font-size", 11);

        d3.selectAll(" .squares")
        .filter(function(e){
            return d == e.x_label;
        })
        .style("stroke", "black");
    };
    var mouseleaveXlabel = function(d){
        d3.selectAll(".x_label, .y_label")
        .style("fill", "black" )
        .style("font-size", 11)

        d3.selectAll(" .squares")
        .style("stroke", "none")
    };
    //---------END-MOUSE-EVENT------------

    //TODO: put all css stylesheet in heatmap.css

    //TODO: dim based on window size (width part)
    var setSvgDim = function(){
        width = (X_elements.length * sq_w);
        height = (Y_elements.length * sq_h);

     //   if (height > 800 ) height = 800  - margin.top - margin.bottom;
        if (height + margin.top + margin.bottom < 250 ) height = 250  - margin.top - margin.bottom;
     //   if ( width > 1100) width = 1100 - margin.left - margin.right;
        if ( width + margin.left + margin.right < 666 )  width = 666  - margin.left - margin.right;//tmp for not clip the legend

        //apply svg resize
        d3.select( getCurrentContainerID() )
        .select("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom);

        //console.log("w: "+width+" h: "+height);
    };
 
    var setXaxis = function(){
        console.log("win_w = "+ window.innerWidth + " w = " + width )
        var w = Object.keys(X_elements).length * sq_w;
        //if (w > width) width = w;

        x = d3.scaleBand()
            .range([ 0, w ]) 
            .domain(X_elements)
            .padding(0.05);
        svg.append("g")
            .style("font-size", 11)
            .attr("transform", "translate(0," + height + ")")
            .call(d3.axisBottom(x).tickSize(5))
            .selectAll("text")	
                .attr("class", "x_label")
                .style("text-anchor", "end")
                .attr("dx", "-.8em")
                .attr("dy", ".15em")
                .attr("transform", "rotate(-65)")
                .on("mouseover", mouseoverXLabel )
                .on("mouseleave", mouseleaveXlabel );
    };

    var setYaxis = function(){
        y = d3.scaleBand()
            .range([ height, 0 ])
            .domain(Y_elements)
            .padding(0.05);
        svg.append("g")
            .style("font-size", 11)
            .call(d3.axisLeft(y).tickSize(3))
            .selectAll("text")
            .attr("class", "y_label")
            .attr("dx", "-2.5em")
            .on("mouseover", mouseoverYLabel )
            .on("mouseleave", mouseleaveYlabel );
    };

    var setYaxisSquare = function(data){
        svg.selectAll()
        .data(data, function(d) {return d.y_label;})
        .enter()
        .append("rect")
        .attr("x", function(d) { return -16 })
        .attr("y", function(d) { return y(d.y_label) })
        .attr("rx", 4)
        .attr("ry", 4)
        .attr("width", 8 )
        .attr("height", y.bandwidth() )
        .style("fill", 
            function(d) {
            if (d.value == 0)
                return "whitesmoke";
            else 
                return myColor( sendersTotPkts[d.y_label] );
            }  
        )
        .on("mouseover", mouseoverYAxisSquare)
        .on("mouseleave", mouseleaveYAxisSquare);
    };

    var createSquares = function(data){
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
        .attr("class","squares")
        .style("fill", 
            function(d) {
            if (d.value == 0)
                return "white";
            else 
                return myColor(d.value);
            }  
        )
        .style("stroke-width", 3)
        .style("stroke", "none")
        .style("opacity", 1)
        .on("mouseover", mouseoverSquare)
        .on("mouseleave", mouseleaveSquare);
    };

    var createTooltip = function(){
        tooltip = d3.select( getCurrentContainerID() )
        .append("div")
        .attr("class", "tooltip")
        .style("opacity", 0);
    };

    var createSvg = function(){
        svg = d3.select(getCurrentContainerID())
            .insert("svg")
        //    .attr("width", width + margin.left + margin.right)
        //    .attr("height", height + margin.top + margin.bottom)
            .insert("g")
            .attr("transform",
                    "translate(" + margin.left + "," + margin.top + ")");
    };

    var changeContainerID = function (){
        svgFlag = !svgFlag;
    };

    var printNoHost = function(){
        svg.append("text")
                .attr("x",  - margin.left)
                .attr("y", 12)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .text("No Requests");
    };

    var printText = function(){
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
                .text(maxTotPkt+" pkt");

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
    };

    var getCurrentContainerID = function(){  
        return svgFlag ? "#container" : "#container2";
    };

    var startInterval = function(_interval) {
        intervalID = setInterval(function() {
            //console.log(_interval);
            build(interval);
        }, _interval);
    }

    var stopUpdate = function (){
        //console.log("stop= "+stopInterval)
        stopInterval = true;
    };
    var startUpdate = function (){
        stopInterval = false;
        //console.log("stop= "+stopInterval)
    };

    //########################################################################################  

    //the calling order of the functions is important (most variable are global)
    var buildMap = function(data) {

        w_h = window.innerHeight - 330;
        w_w = window.innerWidth - margin.left - margin.right - 30;

        max_X_elem = Math.floor(w_w / sq_w);
        max_Y_elem = Math.floor(w_h / sq_h);

        console.log("maxY: " + max_X_elem)

        createSvg();

        X_elements = d3.map(data, function(d){return d.x_label;}).keys()
        Y_elements = d3.map(data, function(d){return d.y_label;}).keys()        

        //compute #tot pkt for each mac
        sendersTotPkts = {};
        receiversTotPkts = {};
        maxTotPkt = 0;
        d3.map(data).values().forEach(e => {
            if ( sendersTotPkts.hasOwnProperty(e.y_label) )
                sendersTotPkts[e.y_label] += e.value;
            else
                sendersTotPkts[e.y_label] = e.value;

            if (receiversTotPkts.hasOwnProperty(e.x_label) )
                receiversTotPkts[e.x_label] += e.value;
            else
                receiversTotPkts[e.x_label] = e.value;

            if (sendersTotPkts[e.y_label] > maxTotPkt)
                maxTotPkt = sendersTotPkts[e.y_label];
        });

        

        console.log("pre reduce: " +Object.keys(X_elements).length)
        
        var Yelem_to_display = new Array();
        var Xelem_to_display = new Array();

        //reduce Y elem
        Y_elements.forEach( e => {
            Yelem_to_display.push( {label:e, pkts:sendersTotPkts[e]} ) 
        });
        
        Yelem_to_display = Yelem_to_display.slice(0, max_Y_elem);
        var new_data = data.filter( e => { 
            return Yelem_to_display.some( d => {return d.label == e.y_label} ) 
        });
        data = new_data;
        new_data = null;

        
        //reduce X_elem
        X_elements.forEach( e => {
            Xelem_to_display.push( {label:e, pkts:sendersTotPkts[e]} ) 
        });
        Xelem_to_display = Xelem_to_display.slice(0, max_X_elem);
        new_data = data.filter( e => { 
            return Xelem_to_display.some( d => {return d.label == e.x_label} ) 
        });
        data = new_data;

        X_elements = d3.map(data, function(d){return d.x_label;}).keys()
        Y_elements = d3.map(data, function(d){return d.y_label;}).keys()
        
        X_elements.sort(function(a,b){ return receiversTotPkts[b] - receiversTotPkts[a] });
        Y_elements.sort(function(a,b){ return sendersTotPkts[a] - sendersTotPkts[b] });
        
        //console.log(receiversTotPkts);

        console.log("post reduce: " + Object.keys(X_elements).length);
        
        setSvgDim();

        //choose a chromatic scale [ https://github.com/d3/d3-scale-chromatic ]
        myColor = d3.scaleSequential().interpolator(d3.interpolateInferno).domain([1,maxTotPkt]);

        setXaxis();
        setYaxis();

        d3.selectAll('.tick text').on('click',labelClick);

        setYaxisSquare(data);
        createTooltip();
        createSquares(data);

        printText();

        //only now (new svg drawn) i can remove (and replace) the old svg
        changeContainerID();
        d3.select( getCurrentContainerID() ).selectAll("*").remove();
    };

    //########################################################################################

    //TODO: width limit
    var buildMiniMap = function(data){

        createSvg();

        X_elements = d3.map(data, function(d){return d.x_label;}).keys()
        Y_elements = d3.map(data, function(d){return d.y_label;}).keys()
        X_elements.sort();//Y_elements has only 1 elem

        if (X_elements.length == 0){
            height = 20;
            d3.select( getCurrentContainerID() )
            .select("svg")
                .attr("height", height);
            printNoHost();
            changeContainerID();
            d3.select( getCurrentContainerID() ).selectAll("*").remove();
            return;
        }

        //setSvgDim();
        width = (X_elements.length * 17);
        //size are tmp
        height = 100  - margin.top - margin.bottom;
        if ( width > 800) width = 800 - margin.left - margin.right;
        if ( width + margin.left + margin.right < 150 )  width = 150  - margin.left - margin.right;

        //apply svg resize
        d3.select( getCurrentContainerID() )
        .select("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom);

        //console.log("w: "+width+" h: "+height);

        //compute #tot pkt for each mac
        sendersTotPkts = {};
        maxTotPkt = 0;
        d3.map(data).values().forEach(e => {
            if (e.value > maxTotPkt)
                maxTotPkt = e.value;
        });

        //choose a chromatic scale [ https://github.com/d3/d3-scale-chromatic ]
        myColor = d3.scaleSequential().interpolator(d3.interpolateInferno).domain([1,maxTotPkt]);

        setXaxis();
        setYaxis();

        d3.selectAll('.tick text').on('click',labelClick);

        //setYaxisSquare(data);
        createTooltip();
        createSquares(data);

        // printText();

        //only now (new svg drawn) i can remove (and replace) the old svg
        changeContainerID();
        d3.select( getCurrentContainerID() ).selectAll("*").remove();
        
        
    };

    //########################################################################################

    var build = function(param) {
        if (param && typeof(param) == "string"  ){
            isDetail = true;
            address = param;
            margin = {top: 5, right: 10, bottom: 70, left: 100};
            d3.json("/lua/get_arp_matrix_data.lua?host="+param, buildMiniMap);

        }else if (param && typeof(param) == "number" ){
            clearInterval(intervalID);

            if ( !stopInterval ){
                interval = param;
                startInterval(interval);
                d3.json("/lua/get_arp_matrix_data.lua", buildMap);
            }
            
        }else
            d3.json("/lua/get_arp_matrix_data.lua",buildMap);
    };


  
    return {
        build:build,
        stopUpdate:stopUpdate,
        startUpdate:startUpdate
    }

})();