var map = (function () {

    var interval = 5000;
    var intervalID;
    var stopInterval = false;

    var host_ip;
    var original_pkt_num = 0;

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

    var sendersNum = 0;
    var receiversNum = 0;
    var excludedSendersNum = 0;
    var excludedReceiversNum = 0;

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
        tooltip.style("opacity", 0.9)
        tooltip.html("sent: " + sendersTotPkts[d])
        .style("left", (d3.event.pageX ) + "px")
        .style("top", (d3.event.pageY - 35) + "px")

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
        tooltip.style("opacity", 0)
        d3.selectAll(".x_label, .y_label")
        .style("fill", "black" )
        .style("font-size", 11)

        d3.selectAll(" .squares")
        .style("stroke", "none")

    };
    var mouseoverXLabel = function(d){
        tooltip.style("opacity", 0.9)
        tooltip.html("rcvd: " + receiversTotPkts[d])
        .style("left", (d3.event.pageX ) + "px")
        .style("top", (d3.event.pageY - 35) + "px")
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
        tooltip.style("opacity", 0)
        d3.selectAll(".x_label, .y_label")
        .style("fill", "black" )
        .style("font-size", 11)

        d3.selectAll(" .squares")
        .style("stroke", "none")
    };
    //---------END-MOUSE-EVENT------------

    //TODO: put all css stylesheet in heatmap.css
    var setSvgDim = function(){
        width = ( Object.keys(X_elements).length * sq_w) + margin.left+margin.right;
        height = ( Object.keys(Y_elements).length * sq_h);

        //min size for not clip the text 
        if (height + margin.top + margin.bottom < 250 ) height = 250  - margin.top - margin.bottom;
        if ( width + margin.left + margin.right < 680 )  width = 680  - margin.left - margin.right;

        //apply svg resize
        d3.select( getCurrentContainerID() )
        .select("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom);
    };
 
    var setXaxis = function(){
        var w = Object.keys(X_elements).length * sq_w ;
        if (w > width - margin.left - margin.right) w = width - margin.left - margin.right;

        x = d3.scaleBand()
            .range([ 0, w ]) 
            .domain(X_elements)
            .padding(0.07);
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
        .attr("class", "tooltip-heatmap")
        .style("opacity", 0);
    };

    var createSvg = function(){
        svg = d3.select(getCurrentContainerID())
            .insert("svg")
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
                .text("Top Talkers ARP-Map");

        // Add subtitle to graph
        svg.append("text")
                .attr("x", 0)
                .attr("y", -20)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .style("fill", "grey")
                .style("max-width", 400)
                .text("Senders on Y axis, Receivers on X axis ");

        // heatmap range info 
        svg.append("text")
                .attr("x", 292)
                .attr("y", -20)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .text("1 pkt");
                
        // heatmap range info 
        svg.append("text")
                .attr("x", 292 + 170)
                .attr("y", -20)
                .attr("text-anchor", "left")
                .style("font-size", "14px")
                .text(maxTotPkt+" pkt");

        //color scale image near the title
        svg.append("image")
                .attr("x", 80)
                .attr("y", -70)
                .attr("height", 20)
                .attr("width", 600)
                .attr("xlink:href", "../img/inferno.png")
                .style("stroke","black")
                .style("stroke-width", "2px");

        //border of color scale image
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
            .attr('x', margin.left - 120  )
            .attr('y', height + 110  )
            .attr('text-anchor', 'middle')
            .text('Receivers ( '+ (receiversNum - excludedReceiversNum)+" / "+receiversNum+" )");

        //Y axis description
        svg.append('text')
            .attr('x', -40 )
            .attr('y', -margin.left/2 - 55)
            .attr('transform', 'rotate(-90)')
            .attr('text-anchor', 'middle')
            .text('Senders ( ' + (sendersNum-excludedSendersNum)+" / "+sendersNum+" )" );
    };

    var getCurrentContainerID = function(){  
        return svgFlag ? "#container" : "#container2";
    };

    var startInterval = function(_interval) {
        intervalID = setInterval(function() {
            build(interval, host_ip);
        }, _interval);
    }

    var stopUpdate = function (){
        stopInterval = true;
    };

    var startUpdate = function (){
        stopInterval = false;
    };

    var printVoidGraph = function(){
        var div = document.getElementById("container");
        div.innerHTML = "Nothing to show. Make sure the ArpMatrix is activated, check the Preference -> Misc ";
        div.style.textAlign = "center";
        $(".control-group").remove();
    };

    //########################################################################################  

    //the calling order of the functions is important (most variable are global)
    var buildMap = function(data) {


        //NOTE: temporary solution
        //disable scroll
        $('html, body').css({
            'overflow': 'hidden',
            'height': '100%'
        })

        w_h = window.innerHeight - margin.top - margin.bottom - 80; 
        w_w = window.innerWidth - margin.left - margin.right - 30;
        max_X_elem = Math.floor(w_w / sq_w);
        max_Y_elem = Math.floor(w_h / sq_h);

        createSvg();

        X_elements = d3.map(data, function(d){return d.x_label;}).keys()
        Y_elements = d3.map(data, function(d){return d.y_label;}).keys()        

        if ( Object.keys(Y_elements).length == 0 || w_w < sq_w){
            printVoidGraph();
            return;
        }

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

        //if host is selected put it first
        if (host_ip){ 
            original_pkt_num = sendersTotPkts[host_ip];
            sendersTotPkts[host_ip] = Number.MAX_SAFE_INTEGER;
        }

        Y_elements.sort(function(a,b){ return sendersTotPkts[b] - sendersTotPkts[a] });
        X_elements.sort(function(a,b){ return receiversTotPkts[b] - receiversTotPkts[a] });

        sendersNum = Object.keys(Y_elements).length;
        receiversNum = Object.keys(X_elements).length;
        excludedSendersNum = 0;
        excludedReceiversNum = 0;

        //NOTE: slice(start, end) NOT include the "start" and "end" indexes
        var sliced = false;
        if (sendersNum > max_Y_elem ){

            excludedSendersNum = sendersNum - max_Y_elem ;
            Y_elements = Y_elements.slice(0, max_Y_elem+1 );
            sliced = true;
        }
        if (receiversNum > max_X_elem ){

            excludedReceiversNum = receiversNum - max_X_elem;
            X_elements = X_elements.slice(0, max_X_elem+1 );
            sliced = true;
        }

        //NOTE: forEach() iterate in ascending order
        if (sliced){
            data = data.filter( function(d){
                return ( Y_elements.includes( d.y_label) && X_elements.includes(d.x_label) )
            });

            X_elements = X_elements.filter( e => {
                var f = false;
                data.forEach(d => {
                    if (d.x_label == e){ f = true; return;}
                })
                if(!f) excludedReceiversNum ++;
                return f;
            });
        }

        // list of chromatic scale [ https://github.com/d3/d3-scale-chromatic ]
        myColor = d3.scaleSequential().interpolator(d3.interpolateInferno).domain([1,maxTotPkt]);

        Y_elements.reverse();
        setSvgDim();

        //if host is selected highlights it
        if (host_ip){ 
            sendersTotPkts[host_ip] = original_pkt_num;
    
            svg.append("line")
                .attr("x1", -margin.left+40)
                .attr("y1", 6)
                .attr("x2", width - margin.left )
                .attr("y2", 6)
                .attr("stroke-width", 11)
                .attr("stroke", "yellow")
                .style("opacity",0.4);
        }

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
        
        //NOTE: temporary solution
        //enable scroll
        $('html, body').css({
            'overflow': 'auto',
            'height': 'auto'
        })
    };

    //########################################################################################

    //NOTE: NOT CURRENTLY USED
    var buildMiniMap = function(data){

        createSvg();
        var svg_x = document.getElementById("container").getBoundingClientRect().left;
        w_w = window.innerWidth - margin.left - margin.right - svg_x;

        //max_X_elem = Math.floor(w_w / sq_w);
        max_X_elem = 5;
        if (max_X_elem < 0 ) max_X_elem = 0;

        X_elements = d3.map(data, function(d){return d.x_label;}).keys()
        Y_elements = d3.map(data, function(d){return d.y_label;}).keys()

        if ( Object.keys(X_elements).length == 0 || w_w < sq_w){
            height = 20;
            d3.select( getCurrentContainerID() )
            .select("svg")
                .attr("height", height);
            //printNoHost();
            changeContainerID();
            d3.select( getCurrentContainerID() ).selectAll("*").remove();
            return;
        }

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

        X_elements.sort(function(a,b){ return receiversTotPkts[b] - receiversTotPkts[a] });

        receiversNum = Object.keys(X_elements).length;
        excludedReceiversNum = 0;

        if (receiversNum > max_X_elem ){

            excludedReceiversNum = receiversNum - max_X_elem;
            X_elements = X_elements.slice(0, max_X_elem+1 );
        }

        sq_w = 20;

        width = ( Object.keys(X_elements).length * sq_w + margin.left + margin.right);
        height = 100  - margin.top - margin.bottom;
        if ( width > 800) width = 800 - margin.left - margin.right;

        //apply svg resize
        d3.select( getCurrentContainerID() )
        .select("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom);

        myColor = d3.scaleSequential().interpolator(d3.interpolateInferno).domain([1,maxTotPkt]);

        setXaxis();
        //setYaxis();
        y = d3.scaleBand()
            .range([ height, 0 ])
            .domain(Y_elements)
            .padding(0.05);
 

        d3.selectAll('.tick text').on('click',labelClick);

        createTooltip();
        createSquares(data);

        //TODO: set hint text

        changeContainerID();
        d3.select( getCurrentContainerID() ).selectAll("*").remove();
    };

    //########################################################################################

    var build = function(refresh,host) {

        console.log("refresh: "+refresh+" host: "+ host);
        host ? host_ip = host : host_ip = null;
        clearInterval(intervalID);
        if ( !stopInterval ){

            if(refresh){
                interval = refresh;
                //host ? host_ip = host : host_ip = null;

                startInterval(interval);
                d3.json("/lua/get_arp_matrix_data.lua", buildMap);

            }else{ /* case: refresh frequency -> never */
                d3.json("/lua/get_arp_matrix_data.lua", buildMap);
            }

        }
    };

    return {
        build:build,
        stopUpdate:stopUpdate,
        startUpdate:startUpdate
    }

})();