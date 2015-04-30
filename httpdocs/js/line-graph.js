/**
 *
 * http://bl.ocks.org/benjchristensen/raw/2657838/line-graph.js
 *
 * Create and draw a new line-graph.
 * 
 * Arguments:
 *   containerId => id of container to insert SVG into [REQUIRED]
 *   marginTop => Number of pixels for top margin. [OPTIONAL => Default: 20]
 *   marginRight => Number of pixels for right margin. [OPTIONAL => Default: 20]
 *   marginBottom => Number of pixels for bottom margin. [OPTIONAL => Default: 35]
 *   marginLeft => Number of pixels for left margin. [OPTIONAL => Default: 90]
 *   data => a dictionary containing the following keys [REQUIRED]
 *     values => The data array of arrays to graph. [REQUIRED]
 *     start => The start time in milliseconds since epoch of the data. [REQUIRED]
 *     end => The end time in milliseconds since epoch of the data. [REQUIRED]
 *     step => The time in milliseconds between each data value.   [REQUIRED] 
 *     names => The metric name for each array of data. [REQUIRED]
 *     displayNames => Display name for each metric. [OPTIONAL => Default: same as 'names' argument]
 *        Example: ['MetricA', 'MetricB'] 
 *     axis => Which axis (left/right) to put each metric on. [OPTIONAL => Default: Display all values on single axis]
 *        Example: ['left', 'right', 'right'] to display first metric on left axis, next two on right axis.
 *     colors => What color to use for each metric. [OPTIONAL => Default: black]
 *        Example: ['blue', 'red'] to display first metric in blue and second in red.
 *     scale => What scale to display the graph with. [OPTIONAL => Default: linear]
 *        Possible Values: linear, pow, log
 *     rounding => How many decimal points to round each metric to. [OPTIONAL => Default: Numbers are rounded to whole numbers (0 decimals)]
 *        Example: [2, 1] to display first metric with 2 decimals and second metric with 1. 
 *     numAxisLabelsPowerScale => Hint for how many labels should be displayed for the Y-axis in Power scale. [OPTIONAL => Default: 6]
 *     numAxisLabelsLinearScale  => Hint for how many labels should be displayed for the Y-axis in Linear scale. [OPTIONAL => Default: 6]
 *
 * Events (fired from container):
 *   LineGraph:dataModification => whenever data is changed
 *   LineGraph:configModification => whenever config is changed
 */
function LineGraph(argsMap) {
  /* *************************************************************** */
  /* public methods */
  /* *************************************************************** */
  var self = this;
  
  /**
   * This allows appending new data points to the end of the lines and sliding them within the time window:
   * - x-axis will slide to new range
   * - new data will be added to the end of the lines
   * - equivalent number of data points will be removed from beginning of lines
   * - lines will be transitioned through horizontoal slide to show progression over time
   */
  this.slideData = function(newData) {
    // validate data
    var tempData = processDataMap(newData);
    //debug("Existing startTime: " + data.startTime + "  endTime: " + data.endTime);
    //debug("New startTime: " + tempData.startTime + "  endTime: " + tempData.endTime);
    
    // validate step is the same on each
    if(tempData.step != newData.step) {
      throw new Error("The step size on appended data must be the same as the existing data => " + data.step + " != " + tempData.step);
    }

    if(tempData.values[0].length == 0) {
      throw new Error("There is no data to append.");
    }
    
    var numSteps = tempData.values[0].length;
    // console.log("slide => add num new values: " + numSteps);
    // console.log(tempData.values[0])
    tempData.values.forEach(function(dataArrays, i) {
      var existingDataArrayForIndex = data.values[i];
      dataArrays.forEach(function(v) {
        // console.log("slide => add new value: " + v);
        // push each new value onto the existing data array
        existingDataArrayForIndex.push(v);
        // shift the front value off to compensate for what we just added
        existingDataArrayForIndex.shift();
      })
       /* ----------- start ntop patch ----------- */
      // console.log("MAX: "+ data.maxValues[i]);
      // console.log("MAX: "+ data.names[i]);
      // console.log("MAX: "+ d3.max(existingDataArrayForIndex));
       data.maxValues[i] = d3.max(existingDataArrayForIndex);
       /* ----------- end ntop patch ----------- */
    })
    
    // shift domain by number of data elements we just added
    // == numElements * step
    data.startTime = new Date(data.startTime.getTime() + (data.step * numSteps));
    data.endTime = tempData.endTime;
    //debug("Updated startTime: " + data.startTime + "  endTime: " + data.endTime);
        
    /*
    * The following transition implementation was learned from examples at http://bost.ocks.org/mike/path/
    * In particular, view the HTML source for the last example on the page inside the tick() function.
    */

    // redraw each of the lines
      // Transitions are turned off on this since the small steps we're taking
      // don't actually look good when animated and it uses unnecessary CPU
      // The quick-steps look cleaner, and keep the axis/line in-sync instead of jittering
    redrawAxes(false);  
    redrawLines(false);
      
      // slide the lines left
      graph.selectAll("g .lines path")
          .attr("transform", "translate(-" + x(numSteps*data.step) + ")");
     
    handleDataUpdate();
    
    // fire an event that data was updated
    $(container).trigger('LineGraph:dataModification')
  }
  
  /**
   * This does a full refresh of the data:
   * - x-axis will slide to new range
   * - lines will change in place
   */
  this.updateData = function(newData) {
    // data is being replaced, not appended so we re-assign 'data'
    data = processDataMap(newData);
    // and then we rebind data.values to the lines
      graph.selectAll("g .lines path").data(data.values)
    
    // redraw (with transition)
    redrawAxes(true);
    // transition is 'false' for lines because the transition is really weird when the data significantly changes
    // such as going from 700 points to 150 to 400
    // and because of that we rebind the data anyways which doesn't work with transitions very well at all
    redrawLines(false);
    
    handleDataUpdate();
    
    // fire an event that data was updated
    $(container).trigger('LineGraph:dataModification')
  }

  
  this.switchToPowerScale = function() {
    yScale = 'pow';
    redrawAxes(true);
    redrawLines(true);
    
    // fire an event that config was changed
    $(container).trigger('LineGraph:configModification')
  }

  this.switchToLogScale = function() {
    yScale = 'log';
    redrawAxes(true);
    redrawLines(true);
    
    // fire an event that config was changed
    $(container).trigger('LineGraph:configModification')
  }

  this.switchToLinearScale = function() {
    yScale = 'linear';
    redrawAxes(true);   
    redrawLines(true);
    
    // fire an event that config was changed
    $(container).trigger('LineGraph:configModification')
  }
  
  /**
   * Return the current scale value: pow, log or linear
   */
  this.getScale = function() {
    return yScale;
  }

  
  
  /* *************************************************************** */
  /* private variables */
  /* *************************************************************** */
  // the div we insert the graph into
  var containerId;
  var container;
  
  // functions we use to display and interact with the graphs and lines
  var graph, x, yLeft, yRight, xAxis, yAxisLeft, yAxisRight, yAxisLeftDomainStart, linesGroup, linesGroupText, lines, lineFunction, lineFunctionSeriesIndex = -1;
  var yScale = 'linear'; // can be pow, log, linear
  var scales = [['linear','Linear'], ['pow','Power'], ['log','Log']];
  var hoverContainer, hoverLine, hoverLineXOffset, hoverLineYOffset, hoverLineGroup;
  var legendFontSize = 12; // we can resize dynamically to make fit so we remember it here

  // instance storage of data to be displayed
  var data;
    
  // define dimensions of graph
  var margin = [-1, -1, -1, -1]; // margins (top, right, bottom, left)
  var w, h;  // width & height
  
  var transitionDuration = 300;
  
  // var formatNumber = d3.format(",.0f") // for formatting integers
  // var tickFormatForLogScale = function(d) { return formatNumber(d) };
  var tickFormatForLogScale = ",.0f";
  
  // used to track if the user is interacting via mouse/finger instead of trying to determine
  // by analyzing various element class names to see if they are visible or not
  var userCurrentlyInteracting = false;
  var currentUserPositionX = -1;
    
  /* *************************************************************** */
  /* initialization and validation */
  /* *************************************************************** */
  var _init = function() {
    // required variables that we'll throw an error on if we don't find
    containerId = getRequiredVar(argsMap, 'containerId');
    container = document.querySelector('#' + containerId);
    
    // margins with defaults (do this before processDataMap since it can modify the margins)
    margin[0] = getOptionalVar(argsMap, 'marginTop', 20) // marginTop allows fitting the actions, date and top of axis labels
    margin[1] = getOptionalVar(argsMap, 'marginRight', 20)
    margin[2] = getOptionalVar(argsMap, 'marginBottom', 35) // marginBottom allows fitting the legend along the bottom
    margin[3] = getOptionalVar(argsMap, 'marginLeft', 90) // marginLeft allows fitting the axis labels
    
    // assign instance vars from dataMap
    data = processDataMap(getRequiredVar(argsMap, 'data'));
    
    /* set the default scale */
    yScale = data.scale;

    // do this after processing margins and executing processDataMap above
    initDimensions();
    
    createGraph()
    //debug("Initialization successful for container: " + containerId)  
    
    // window resize listener
    // de-dupe logic from http://stackoverflow.com/questions/667426/javascript-resize-event-firing-multiple-times-while-dragging-the-resize-handle/668185#668185
    var TO = false;
    $(window).resize(function(){
      if(TO !== false)
          clearTimeout(TO);
      TO = setTimeout(handleWindowResizeEvent, 200); // time in miliseconds
    });
  }
  
  
  
  /* *************************************************************** */
  /* private methods */
  /* *************************************************************** */

  /*
   * Return a validated data map
   * 
   * Expects a map like this:
   *   {"start": 1335035400000, "end": 1335294600000, "step": 300000, "values": [[28,22,45,65,34], [45,23,23,45,65]]}
   */
  var processDataMap = function(dataMap) {
    // assign data values to plot over time
    var dataValues = getRequiredVar(dataMap, 'values', "The data object must contain a 'values' value with a data array.")
    var startTime = new Date(getRequiredVar(dataMap, 'start', "The data object must contain a 'start' value with the start time in milliseconds since epoch."))
    var endTime = new Date(getRequiredVar(dataMap, 'end', "The data object must contain an 'end' value with the end time in milliseconds since epoch."))
    var step = getRequiredVar(dataMap, 'step', "The data object must contain a 'step' value with the time in milliseconds between each data value.")    
    var names = getRequiredVar(dataMap, 'names', "The data object must contain a 'names' array with the same length as 'values' with a name for each data value array.")    
    var displayNames = getOptionalVar(dataMap, 'displayNames', names);
    var numAxisLabelsPowerScale = getOptionalVar(dataMap, 'numAxisLabelsPowerScale', 6); 
    var numAxisLabelsLinearScale = getOptionalVar(dataMap, 'numAxisLabelsLinearScale', 6); 
    
    var axis = getOptionalVar(dataMap, 'axis', []);
    // default axis values
    if(axis.length == 0) {
      displayNames.forEach(function (v, i) {
        // set the default to left axis
        axis[i] = "left";
      })
    } else {
      var hasRightAxis = false;
      axis.forEach(function(v) {
        if(v == 'right') {
          hasRightAxis = true;
        }
      })
      if(hasRightAxis) {
        // add space to right margin
        margin[1] = margin[1] + 50;
      }
    }

    
    var colors = getOptionalVar(dataMap, 'colors', []);
    // default colors values
    if(colors.length == 0) {
      displayNames.forEach(function (v, i) {
        // set the default
        colors[i] = "black";
      })
    }
    
    var maxValues = [];
    var rounding = getOptionalVar(dataMap, 'rounding', []);
    // default rounding values
    if(rounding.length == 0) {
      displayNames.forEach(function (v, i) {
        // set the default to 0 decimals
        rounding[i] = 0;
      })
    }
    
    /* copy the dataValues array, do NOT assign the reference otherwise we modify the original source when we shift/push data */
    var newDataValues = [];
    dataValues.forEach(function (v, i) {
      newDataValues[i] = v.slice(0);
      maxValues[i] = d3.max(newDataValues[i])
    })

    

    
    return {
      "values" : newDataValues,
      "startTime" : startTime,
      "endTime" : endTime,
      "step" : step,
      "names" : names,
      "displayNames": displayNames,
      "axis" : axis,
      "colors": colors,
      "scale" : getOptionalVar(dataMap, 'scale', yScale),
      "maxValues" : maxValues,
      "rounding" : rounding,
      "numAxisLabelsLinearScale": numAxisLabelsLinearScale,
      "numAxisLabelsPowerScale": numAxisLabelsPowerScale
    }
  }
  
  var redrawAxes = function(withTransition) {
    initY();
    initX();
    
    if(withTransition) {
      // slide x-axis to updated location
      graph.selectAll("g .x.axis").transition()
      .duration(transitionDuration)
      .ease("linear")
      .call(xAxis)          
    
      // slide y-axis to updated location
      graph.selectAll("g .y.axis.left").transition()
      .duration(transitionDuration)
      .ease("linear")
      .call(yAxisLeft)
      
      if(yAxisRight != undefined) {
        // slide y-axis to updated location
        graph.selectAll("g .y.axis.right").transition()
        .duration(transitionDuration)
        .ease("linear")
        .call(yAxisRight)
      }
    } else {
      // slide x-axis to updated location
      graph.selectAll("g .x.axis")
      .call(xAxis)          
    
      // slide y-axis to updated location
      graph.selectAll("g .y.axis.left")
      .call(yAxisLeft)

      if(yAxisRight != undefined) {     
        // slide y-axis to updated location
        graph.selectAll("g .y.axis.right")
        .call(yAxisRight)
      }
    }
  }
  
  var redrawLines = function(withTransition) {
    /**
    * This is a hack to deal with the left/right axis.
    *
    * See createGraph for a larger comment explaining this. 
    *
    * Yes, it's ugly. If you can suggest a better solution please do.
    */
    lineFunctionSeriesIndex  =-1;
    
    // redraw lines
    if(withTransition) {
      graph.selectAll("g .lines path")
      .transition()
        .duration(transitionDuration)
        .ease("linear")
        .attr("d", lineFunction)
        .attr("transform", null);
    } else {
      graph.selectAll("g .lines path")
        .attr("d", lineFunction)
        .attr("transform", null);
    }
  }
  
  /*
   * Allow re-initializing the y function at any time.
   *  - it will properly determine what scale is being used based on last user choice (via public switchScale methods)
   */
  var initY = function() {
    initYleft();
    initYright();
  }
  
  var initYleft = function() {
    var maxYscaleLeft = calculateMaxY(data, 'left')
    // debug("initY => maxYscale: " + maxYscaleLeft);
    var numAxisLabels = 6;
    if(yScale == 'pow') {
      yLeft = d3.scale.pow().exponent(0.3).domain([0, maxYscaleLeft]).range([h, 10]).nice(); 
      numAxisLabels = data.numAxisLabelsPowerScale;
    } else if(yScale == 'log') {
      // we can't have 0 so will represent 0 with a very small number
      // 0.1 works to represent 0, 0.01 breaks the tickFormatter
      yLeft = d3.scale.log().domain([0.1, maxYscaleLeft]).range([h, 10]).nice(); 
    } else if(yScale == 'linear') {
      yLeft = d3.scale.linear().domain([0, maxYscaleLeft]).range([h, 10]).nice();
      numAxisLabels = data.numAxisLabelsLinearScale;
    }

    yAxisLeft = d3.svg.axis().scale(yLeft).ticks(numAxisLabels, tickFormatForLogScale).orient("left");
  }
  
  var initYright = function() {
    var maxYscaleRight = calculateMaxY(data, 'right')
    // only create the right axis if it has values
    if(maxYscaleRight != undefined) {
      //debug("initY => maxYscale: " + maxYscaleRight);
      var numAxisLabels = 6;
      if(yScale == 'pow') {
        yRight = d3.scale.pow().exponent(0.3).domain([0, maxYscaleRight]).range([h, 0]).nice();   
        numAxisLabels = data.numAxisLabelsPowerScale;
      } else if(yScale == 'log') {
        // we can't have 0 so will represent 0 with a very small number
        // 0.1 works to represent 0, 0.01 breaks the tickFormatter
        yRight = d3.scale.log().domain([0.1, maxYscaleRight]).range([h, 0]).nice(); 
      } else if(yScale == 'linear') {
        yRight = d3.scale.linear().domain([0, maxYscaleRight]).range([h, 0]).nice();
        numAxisLabels = data.numAxisLabelsLinearScale;
      }
      
      yAxisRight = d3.svg.axis().scale(yRight).ticks(numAxisLabels, tickFormatForLogScale).orient("right");
    }
  }
  
  
  
  /*
   * Whenever we add/update data we want to re-calculate if the max Y scale has changed
   */
  var calculateMaxY = function(data, whichAxis) {
    // Y scale will fit values from 0-10 within pixels h-0 (Note the inverted domain for the y-scale: bigger is up!)
      // we get the max of the max of values for the given index since we expect an array of arrays

    // we can shortcut to using data.maxValues since we've already calculated the max of each series in processDataMap

    var maxValuesForAxis = [];
    data.maxValues.forEach(function(v, i) {
      if(data.axis[i] == whichAxis) {
        // debug("initY => Yscale: " + v);
        maxValuesForAxis.push(v);
      }
    })
    
    // we now have the max values for the axis we're interested in so get the max of them
    return d3.max(maxValuesForAxis);
  }
  
  /*
   * Allow re-initializing the x function at any time.
   */
  var initX = function() {
    // X scale starts at epoch time 1335035400000, ends at 1335294600000 with 300s increments
    x = d3.time.scale().domain([data.startTime, data.endTime]).range([0, w]);
    
    // create yAxis (with ticks)
    xAxis = d3.svg.axis().scale(x).tickSize(-h).tickSubdivide(1);
      // without ticks
      //xAxis = d3.svg.axis().scale(x);
  }

  /**
  * Creates the SVG elements and displays the line graph.
  *
  * Expects to be called once during instance initialization.
  */
  var createGraph = function() {
    
    // Add an SVG element with the desired dimensions and margin.
    graph = d3.select("#" + containerId).append("svg:svg")
        .attr("class", "line-graph")
        .attr("width", w + margin[1] + margin[3])
        .attr("height", h + margin[0] + margin[2])  
        .append("svg:g")
          .attr("transform", "translate(" + margin[3] + "," + margin[0] + ")");

    initX()   
    
    // Add the x-axis.
    graph.append("svg:g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + h + ")")
      .call(xAxis);
      
    
    // y is all done in initY because we need to re-assign vars quite often to change scales
    initY();
        
    // Add the y-axis to the left
    graph.append("svg:g")
      .attr("class", "y axis left")
      .attr("transform", "translate(-10,0)")
      .call(yAxisLeft);
      
    if(yAxisRight != undefined) {
      // Add the y-axis to the right if we need one
      graph.append("svg:g")
        .attr("class", "y axis right")
        .attr("transform", "translate(" + (w+10) + ",0)")
        .call(yAxisRight);
    }
        
    // create line function used to plot our data
    lineFunction = d3.svg.line()
      .interpolate("basis")
      // assign the X function to plot our line as we wish
      .x(function(d,i) { 
        /* 
         * Our x value is defined by time and since our data doesn't have per-metric timestamps
         * we calculate time as (startTime + the step between metrics * the index)
         *
         * We also reach out to the persisted 'data' object for time
         * since the 'd' passed in here is one of the children, not the parent object
         */
        var _x = x(data.startTime.getTime() + (data.step*i)); 
        
        // verbose logging to show what's actually being done
        //debug("Line X => index: " + i + " scale: " + _x)
        // return the X coordinate where we want to plot this datapoint
        return _x;
      })
      .y(function(d, i) { 
        if(yScale == 'log' && d < 0.1) {
          // log scale can't have 0s, so we set it to the smallest value we set on y
          d = 0.1;
        }
        
        /**
        * This is a hack that relies on:
        *   a) the single-threaded nature of javascript that this will not be interleaved
        *   b) that lineFunction will always be passed the data[] for all lines in the same way each time
        *
        * We then use an external variable to track each time we move from one series to the next
        * so that we can have its seriesIndex to access information in the data[] object, particularly
        * so we can determine what axis this data is supposed to be on.
        *
        * I didn't want to split the line function into left and right lineFunctions as that would really
        * complicate the data binding.
        *
        * Also ... I can't figure out nested functions to keep it scoped so I had to put lineFunctionSeriesIndex
        * as a variable in the same scope as lineFunction. Ugly. And worse ... reset it in redrawAxes. 
        *
        * Anyone reading this who knows a better solution please let me know.
        */
        if(i == 0) {
          lineFunctionSeriesIndex++;
        }
        var axis = data.axis[lineFunctionSeriesIndex];
        var _y;
        if(axis == 'right') {
          _y = yRight(d); 
        } else {
          _y = yLeft(d); 
        }

        // verbose logging to show what's actually being done
        //debug("Line Y => data: " + d + " scale: " + _y)
        // return the Y coordinate where we want to plot this datapoint
        return _y;
      })
      .defined(function(d) {
        // handle missing data gracefully
        // feature added in https://github.com/mbostock/d3/pull/594
        return d >= 0;
      });

    // append a group to contain all lines
    lines = graph.append("svg:g")
        .attr("class", "lines")
      .selectAll("path")
        .data(data.values); // bind the array of arrays

    // persist this reference so we don't do the selector every mouse event
    hoverContainer = container.querySelector('g .lines');
    
    
    $(container).mouseleave(function(event) {
      handleMouseOutGraph(event);
    })
    
    $(container).mousemove(function(event) {
      handleMouseOverGraph(event);
    })    

          
    // add a line group for each array of values (it will iterate the array of arrays bound to the data function above)
    linesGroup = lines.enter().append("g")
        .attr("class", function(d, i) {
          return "line_group series_" + i;
        });
        
    // add path (the actual line) to line group
    linesGroup.append("path")
        .attr("class", function(d, i) {
          //debug("Appending line [" + containerId + "]: " + i)
          return "line series_" + i;
        })
        .attr("fill", "none")
        .attr("stroke", function(d, i) {
          return data.colors[i];
        })
        .attr("d", lineFunction) // use the 'lineFunction' to create the data points in the correct x,y axis
        .on('mouseover', function(d, i) {
          handleMouseOverLine(d, i);
        });
        
    // add line label to line group
    linesGroupText = linesGroup.append("svg:text");
    linesGroupText.attr("class", function(d, i) {
        //debug("Appending line [" + containerId + "]: " + i)
        return "line_label series_" + i;
      })
      .text(function(d, i) {
        return "";
      });
      
    // add a 'hover' line that we'll show as a user moves their mouse (or finger)
    // so we can use it to show detailed values of each line
    hoverLineGroup = graph.append("svg:g")
              .attr("class", "hover-line");
    // add the line to the group
    hoverLine = hoverLineGroup
      .append("svg:line")
        .attr("x1", 10).attr("x2", 10) // vertical line so same value on each
        .attr("y1", 0).attr("y2", h); // top to bottom  
        
    // hide it by default
    hoverLine.classed("hide", true);
      
    createScaleButtons();
    createDateLabel();
    createLegend();   
    setValueLabelsToLatest();
  }
  
  /**
   * Create a legend that displays the name of each line with appropriate color coding
   * and allows for showing the current value when doing a mouseOver
   */
  var createLegend = function() {
    
    // append a group to contain all lines
    var legendLabelGroup = graph.append("svg:g")
        .attr("class", "legend-group")
      .selectAll("g")
        .data(data.displayNames)
      .enter().append("g")
        .attr("class", "legend-labels");
        
    legendLabelGroup.append("svg:text")
        .attr("class", "legend name")
        .text(function(d, i) {
          return d;
        })
        .attr("font-size", legendFontSize)
        .attr("fill", function(d, i) {
          // return the color for this row
          return data.colors[i];
        })
        .attr("y", function(d, i) {
          return h+28;
        })
        .on('click', function(d, i) {
          alert(i);
        });

        
    // put in placeholders with 0 width that we'll populate and resize dynamically
    legendLabelGroup.append("svg:text")
        .attr("class", "legend value")
        .attr("font-size", legendFontSize)
        .attr("fill", function(d, i) {
          return data.colors[i];
        })
        .attr("y", function(d, i) {
          return h+28;
        })
        
    // x values are not defined here since those get dynamically calculated when data is set in displayValueLabelsForPositionX()
  }
  
  var redrawLegendPosition = function(animate) {
    var legendText = graph.selectAll('g.legend-group text');
    if(animate) {
      legendText.transition()
      .duration(transitionDuration)
      .ease("linear")
      .attr("y", function(d, i) {
        return h+28;
      }); 
      
    } else {
      legendText.attr("y", function(d, i) {
        return h+28;
      }); 
    } 
  }
  
  /**
   * Create scale buttons for switching the y-axis
   */
  var createScaleButtons = function() {
    var cumulativeWidth = 0;    
    // append a group to contain all lines
    var buttonGroup = graph.append("svg:g")
        .attr("class", "scale-button-group")
      .selectAll("g")
        .data(scales)
      .enter().append("g")
        .attr("class", "scale-buttons")
      .append("svg:text")
        .attr("class", "scale-button")
        .text(function(d, i) {
          return d[1];
        })
        .attr("font-size", "12") // this must be before "x" which dynamically determines width
        .attr("fill", function(d) {
          if(d[0] == yScale) {
            return "black";
          } else {
            return "blue";
          }
        })
        .classed("selected", function(d) {
          if(d[0] == yScale) {
            return true;
          } else {
            return false;
          }
        })
        .attr("x", function(d, i) {
          // return it at the width of previous labels (where the last one ends)
          var returnX = cumulativeWidth;
          // increment cumulative to include this one
          cumulativeWidth += this.getComputedTextLength()+5;
          return returnX;
        })
        .attr("y", -4)
        .on('click', function(d, i) {
          handleMouseClickScaleButton(this, d, i);
        });
  }

  var handleMouseClickScaleButton = function(button, buttonData, index) {
    if(index == 0) {
      self.switchToLinearScale();
    } else if(index == 1) {
      self.switchToPowerScale();
    } else if(index == 2) {
      self.switchToLogScale();
    }
    
    // change text decoration
    graph.selectAll('.scale-button')
    .attr("fill", function(d) {
      if(d[0] == yScale) {
        return "black";
      } else {
        return "blue";
      }
    })
    .classed("selected", function(d) {
      if(d[0] == yScale) {
        return true;
      } else {
        return false;
      }
    })
    
  }
  
  /**
   * Create a data label
   */
  var createDateLabel = function() {
    var date = new Date(); // placeholder just so we can calculate a valid width
    // create the date label to the left of the scaleButtons group
    var buttonGroup = graph.append("svg:g")
        .attr("class", "date-label-group")
      .append("svg:text")
        .attr("class", "date-label")
        .attr("text-anchor", "end") // set at end so we can position at far right edge and add text from right to left
        .attr("font-size", "10") 
        .attr("y", -4)
        .attr("x", w)
        .text(date.toDateString() + " " + date.toLocaleTimeString())
        
  }

  
  /**
   * Called when a user mouses over a line.
   */
  var handleMouseOverLine = function(lineData, index) {
    //debug("MouseOver line [" + containerId + "] => " + index)
    
    // user is interacting
    userCurrentlyInteracting = true;
  }

  /**
   * Called when a user mouses over the graph.
   */
  var handleMouseOverGraph = function(event) {  
    var mouseX = event.pageX-hoverLineXOffset;
    var mouseY = event.pageY-hoverLineYOffset;
    
    //debug("MouseOver graph [" + containerId + "] => x: " + mouseX + " y: " + mouseY + "  height: " + h + " event.clientY: " + event.clientY + " offsetY: " + event.offsetY + " pageY: " + event.pageY + " hoverLineYOffset: " + hoverLineYOffset)
    if(mouseX >= 0 && mouseX <= w && mouseY >= 0 && mouseY <= h) {
      // show the hover line
      hoverLine.classed("hide", false);

      // set position of hoverLine
      hoverLine.attr("x1", mouseX).attr("x2", mouseX)
      
      displayValueLabelsForPositionX(mouseX)
      
      // user is interacting
      userCurrentlyInteracting = true;
      currentUserPositionX = mouseX;
    } else {
      // proactively act as if we've left the area since we're out of the bounds we want
      handleMouseOutGraph(event)
    }
  }
  
  
  var handleMouseOutGraph = function(event) { 
    // hide the hover-line
    hoverLine.classed("hide", true);
    
    setValueLabelsToLatest();
    
    //debug("MouseOut graph [" + containerId + "] => " + mouseX + ", " + mouseY)
    
    // user is no longer interacting
    userCurrentlyInteracting = false;
    currentUserPositionX = -1;
  }
  
/*  // if we need to support older browsers without pageX/pageY we can use this
  var getMousePositionFromEvent = function(e, element) {
    var posx = 0;
    var posy = 0;
    if (!e) var e = window.event;
    if (e.pageX || e.pageY)   {
      posx = e.pageX;
      posy = e.pageY;
    }
    else if (e.clientX || e.clientY)  {
      posx = e.clientX + document.body.scrollLeft
        + document.documentElement.scrollLeft;
      posy = e.clientY + document.body.scrollTop
        + document.documentElement.scrollTop;
    }
    
    return {x: posx, y: posy};
  }
*/
  
  /*
  * Handler for when data is updated.
  */
  var handleDataUpdate = function() {
    if(userCurrentlyInteracting) {
      // user is interacting, so let's update values to wherever the mouse/finger is on the updated data
      if(currentUserPositionX > -1) {
        displayValueLabelsForPositionX(currentUserPositionX)
      }
    } else {
      // the user is not interacting with the graph, so we'll update the labels to the latest
      setValueLabelsToLatest();
    }
  }
  
  /**
  * Display the data values at position X in the legend value labels.
  */
  var displayValueLabelsForPositionX = function(xPosition, withTransition) {
    var animate = false;
    if(withTransition != undefined) {
      if(withTransition) {
        animate = true;
      }
    }
    var dateToShow;
    var labelValueWidths = [];
    graph.selectAll("text.legend.value")
    .text(function(d, i) {
      var valuesForX = getValueForPositionXFromData(xPosition, i);
      dateToShow = valuesForX.date;
      return valuesForX.value;
    })
    .attr("x", function(d, i) {
      labelValueWidths[i] = this.getComputedTextLength();
    })

    // position label names
    var cumulativeWidth = 0;
    var labelNameEnd = [];
    graph.selectAll("text.legend.name")
        .attr("x", function(d, i) {
          // return it at the width of previous labels (where the last one ends)
          var returnX = cumulativeWidth;
          // increment cumulative to include this one + the value label at this index
          cumulativeWidth += this.getComputedTextLength()+4+labelValueWidths[i]+8;
          // store where this ends
          labelNameEnd[i] = returnX + this.getComputedTextLength()+5;
          return returnX;
        })

    // remove last bit of padding from cumulativeWidth
    cumulativeWidth = cumulativeWidth - 8;

    if(cumulativeWidth > w) {
      // decrease font-size to make fit
      legendFontSize = legendFontSize-1;
      //debug("making legend fit by decreasing font size to: " + legendFontSize)
      graph.selectAll("text.legend.name")
        .attr("font-size", legendFontSize);
      graph.selectAll("text.legend.value")
        .attr("font-size", legendFontSize);
      
      // recursively call until we get ourselves fitting
      displayValueLabelsForPositionX(xPosition);
      return;
    }

    // position label values
    graph.selectAll("text.legend.value")
    .attr("x", function(d, i) {
      return labelNameEnd[i];
    })
    

    // show the date
    graph.select('text.date-label').text(dateToShow.toDateString() + " " + dateToShow.toLocaleTimeString())

    // move the group of labels to the right side
    if(animate) {
      graph.selectAll("g.legend-group g")
        .transition()
        .duration(transitionDuration)
        .ease("linear")
        .attr("transform", "translate(" + (w-cumulativeWidth) +",0)")
    } else {
      graph.selectAll("g.legend-group g")
        .attr("transform", "translate(" + (w-cumulativeWidth) +",0)")
    }
  }
  
  /**
  * Set the value labels to whatever the latest data point is.
  */
  var setValueLabelsToLatest = function(withTransition) {
    displayValueLabelsForPositionX(w, withTransition);
  }
  
  /**
  * Convert back from an X position on the graph to a data value from the given array (one of the lines)
  * Return {value: value, date, date}
  */
  var getValueForPositionXFromData = function(xPosition, dataSeriesIndex) {
    var d = data.values[dataSeriesIndex]
    
    // get the date on x-axis for the current location
    var xValue = x.invert(xPosition);

    // Calculate the value from this date by determining the 'index'
    // within the data array that applies to this value
    var index = (xValue.getTime() - data.startTime) / data.step;


    if(index >= d.length) {
      index = d.length-1;
    }
    // The date we're given is interpolated so we have to round off to get the nearest
    // index in the data array for the xValue we're given.
    // Once we have the index, we then retrieve the data from the d[] array
    index = Math.round(index);

    // bucketDate is the date rounded to the correct 'step' instead of interpolated
    var bucketDate = new Date(data.startTime.getTime() + data.step * (index+1)); // index+1 as it is 0 based but we need 1-based for this math
        
    var v = d[index];

    var roundToNumDecimals = data.rounding[dataSeriesIndex];

    return {value: roundNumber(v, roundToNumDecimals), date: bucketDate};
  }

  
  /**
   * Called when the window is resized to redraw graph accordingly.
   */
  var handleWindowResizeEvent = function() {
    //debug("Window Resize Event [" + containerId + "] => resizing graph")
    initDimensions();
    initX();
    
    // reset width/height of SVG
    d3.select("#" + containerId + " svg")
        .attr("width", w + margin[1] + margin[3])
        .attr("height", h + margin[0] + margin[2]);

    // reset transform of x axis
    graph.selectAll("g .x.axis")
      .attr("transform", "translate(0," + h + ")");
      
    if(yAxisRight != undefined) {
      // Reset the y-axisRight transform if it exists
      graph.selectAll("g .y.axis.right")
        .attr("transform", "translate(" + (w+10) + ",0)");
    }

    // reset legendFontSize on window resize so it has a chance to re-calculate to a bigger size if it can now fit 
    legendFontSize = 12;
    //debug("making legend fit by decreasing font size to: " + legendFontSize)
    graph.selectAll("text.legend.name")
      .attr("font-size", legendFontSize);
    graph.selectAll("text.legend.value")
      .attr("font-size", legendFontSize);

    // move date label
    graph.select('text.date-label')
      .transition()
      .duration(transitionDuration)
      .ease("linear")
      .attr("x", w)

    // redraw the graph with new dimensions
    redrawAxes(true);
    redrawLines(true);
    
    // reposition legend if necessary
    redrawLegendPosition(true);
        
    // force legend to redraw values
    setValueLabelsToLatest(true);
  }

  /**
   * Set height/width dimensions based on container.
   */
  var initDimensions = function() {
    // automatically size to the container using JQuery to get width/height
    w = $("#" + containerId).width() - margin[1] - margin[3]; // width
    h = $("#" + containerId).height() - margin[0] - margin[2]; // height
    
    // make sure to use offset() and not position() as we want it relative to the document, not its parent
    hoverLineXOffset = margin[3]+$(container).offset().left;
    hoverLineYOffset = margin[0]+$(container).offset().top;
  }
  
  /**
  * Return the value from argsMap for key or throw error if no value found
  */    
  var getRequiredVar = function(argsMap, key, message) {
    if(!argsMap[key]) {
      if(!message) {
        throw new Error(key + " is required")
      } else {
        throw new Error(message)
      }
    } else {
      return argsMap[key]
    }
  }
  
  /**
  * Return the value from argsMap for key or defaultValue if no value found
  */
  var getOptionalVar = function(argsMap, key, defaultValue) {
    if(!argsMap[key]) {
      return defaultValue
    } else {
      return argsMap[key]
    }
  }
  
  var error = function(message) {
    console.log("ERROR: " + message)
  }

  var debug = function(message) {
    console.log("DEBUG: " + message)
  }
  
  /* round a number to X digits: num => the number to round, dec => the number of decimals */
  /* private */ function roundNumber(num, dec) {
    var result = Math.round(num*Math.pow(10,dec))/Math.pow(10,dec);
    var resultAsString = result.toString();
    if(dec > 0) {
      if(resultAsString.indexOf('.') == -1) {
        resultAsString = resultAsString + '.';
      }
      // make sure we have a decimal and pad with 0s to match the number we were asked for
      var indexOfDecimal = resultAsString.indexOf('.');
      while(resultAsString.length <= (indexOfDecimal+dec)) {
        resultAsString = resultAsString + '0';
      }
    }
    return resultAsString;
  };
  
  /* *************************************************************** */
  /* execute init now that everything is defined */
  /* *************************************************************** */
  _init();
};
