--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

local ifstats = interface.getStats()

sendHTTPContentTypeHeader('text/html')


page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.hosts)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
  <br>
  <br>
  
    <ul class="nav nav-tabs">
      <li class="nav-item active"><a class="nav-link active" href="#Overview" data-bs-toggle="tab">]] print(i18n("overview")) print[[</a></li>
      <li class="nav-item"><a class="nav-link" href="#Timeline" data-bs-toggle="tab">]] print(i18n("processes_stats.timeline")) print[[</a></li>
    </ul>

    <!-- Tab content-->
    <div class="tab-content">
]]

print [[
      <div class="tab-pane active" id="Overview">

      <div id="table-processes"></div>
   <script> ]]
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/processes_stats_id.inc") 

if(ifstats.vlan) then print ('processes_rows_option["source_id"] = true;\n') end

print [[
   $("#table-processes").datatable({
          title: "]] print(i18n("processes_stats.active_processes_title")) print[[",
          url: "]]
print (ntop.getHttpPrefix())
print [[/lua/get_processes_data.lua",
          ]]
print ('rowCallback: function ( row ) { return processes_table_setID(row); },')
print [[
	       showPagination: true,
	        columns: [
	        {
         title: "Key",
         field: "key",
         hidden: true,
         css: { 
              textAlign: 'center'
           }
         },
			     {
			     title: "]] print(i18n("name")) print[[",
				 field: "column_name",
				 sortable: true,
	 	             css: { 
			        textAlign: 'left'
			     }
				 },
]]

if(ifstats.vlan) then
print [[
           {
           title: "]] print(i18n("flows_page.source_id")) print[[",
         field: "column_vlan",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }
         },
]]
end

print [[
        {
           title: "]] print(i18n("processes_stats.flows_count")) print[[",
         field: "column_count",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }

         },          
           {
           title: "]] print(i18n("processes_stats.active_since")) print[[",
         field: "column_duration",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }

         },          
           {
           title: "]] print(i18n("processes_stats.traffic_sent")) print[[",
         field: "column_bytes_sent",
         sortable: true,
                 css: { 
              textAlign: 'right'
           }
         },
           {
           title: "]] print(i18n("processes_stats.traffic_rcvd")) print[[",
         field: "column_bytes_rcvd",
         sortable: true,
                 css: { 
              textAlign: 'right'
           }
         }
           ]
         });
       </script>

]]

print [[
  <script>
  $( window ).load(function() {
    processes_table_update();
  });
    
  </script>
]]
print 
[[     </div> <!-- Tab Overview-->
]]


print [[  
<link type="text/css" rel="stylesheet" href="/css/timeline.css">
<script type="text/javascript">
// Wrapper function
  function do_timeline(p_update_url, p_url_params, p_url_id_name, p_timeInterval, p_init_period) {
    
    var tml = new Timeline(p_update_url, p_url_params, p_url_id_name, p_timeInterval, p_init_period);
    var refresh = (p_timeInterval*1000);
    tml.setInterval(setInterval(function(){tml.update();},refresh ));
  
    // Return new class instance, with
    return tml;
  }
  
  // Timeline class
  // "/lua/get_processes_data.lua",{ procstats_mode: "timeline"},"pid_name",2,300);
  function Timeline(p_update_url, p_url_params, p_url_id_name, p_timeInterval, p_init_period) {
  
    // Window update interval name
    var interval;
  
    var update_url = p_update_url;
    var url_params = p_url_params;
    var url_id_name = p_url_id_name;
    var timeInterval = p_timeInterval;
    var init_period = p_init_period;
  
    var seriesGraphData = []; //Structure for timeline graph, index by i-position
    var seriesHistoryData = []; //Structure for timeline values, used to populate tooltip and how historical values, index by i-position
  
   
    // Initial graph structure
    var graph_info = {
      element: document.getElementById("chart"),
      width: 800,
      height: 400,
      renderer: 'area',
      stroke: true,
      preserve: true,
      series: []
    } 
  
    var graph,preview,hoverDetail,annotator,legend,shelving,order,highlighter,ticksTreatment,xAxis,yAxis,previewXAxis,offsetForm;
  
    var timeline_control = new TimelineValue(update_url, url_params, url_id_name, timeInterval, init_period, null, 0);
  
  
    timeline_control.initJsonData(seriesGraphData,seriesHistoryData,graph_info);
  
    for (var i = 0; i < init_period; i++) {
      timeline_control.addDataEmpty(seriesGraphData);
    }
  
    init();
    timeline_control.setAnnotator(annotator);
  
  
    // add some data every so often
    this.update = function () {
      timeline_control.removeData(seriesGraphData);
      timeline_control.addJsonData(seriesGraphData,seriesHistoryData);
      graph.update();
    }
  
    this.setInterval = function(p_interval) {
      interval = p_interval;
    }
  
    this.stopInterval = function() {
        //disabled graph interval
        clearInterval(interval);
    }
  
    this.startInterval = function() {
      interval = setInterval(this.update(),(timeInterval*1000))
    }
  
  
    function init() {
      // instantiate our graph!
      graph = new Rickshaw.Graph(graph_info);
      graph.render();
  
      preview = new Rickshaw.Graph.RangeSlider.Preview( {
        graph: graph,
        element: document.getElementById('preview')
      } );
  
      hoverDetail = new Rickshaw.Graph.HoverDetail( {
        graph: graph,
        xFormatter: function(x) {
          return new Date(x * 1000).toString();
        },
        yFormatter: function(bits) { return(NtopUtils.bytesToVolume(bits)); },
        formatter: function(series, x, y, formattedX, formattedY, d) {
          var l_index = name2id(series.name);
          
          str = 'Process:&nbsp;' + series.name + '<br/>Traffic:&nbsp;' + NtopUtils.bytesToVolume(y);
          
          if (l_index != -1) {
             var l_data = seriesHistoryData[l_index];
             str += '<br>Actual memory:&nbsp;'+ NtopUtils.bytesToVolume(l_data.actual_memory);
            
             if ((l_data.average_cpu_load == 0) || (l_data.average_cpu_load < 1)) {
              str += '<br>Average CPU Load:&nbsp;< 1 %';
            } else
             str += '<br>Average CPU Load:&nbsp;'+ Number((l_data.average_cpu_load).toFixed(2)) + '%';
          
          }
         
          return str;
        }
      
      });
  
  
      annotator = new Rickshaw.Graph.Annotate( {
        graph: graph,
        element: document.getElementById('line')
      } );
  
      legend = new Rickshaw.Graph.Legend( {
        graph: graph,
        element: document.getElementById('legend')
  
      } );
  
      shelving = new Rickshaw.Graph.Behavior.Series.Toggle( {
        graph: graph,
        legend: legend
      } );
  
      order = new Rickshaw.Graph.Behavior.Series.Order( {
        graph: graph,
        legend: legend
      } );
  
      highlighter = new Rickshaw.Graph.Behavior.Series.Highlight( {
        graph: graph,
        legend: legend
      } );
  
  
      ticksTreatment = 'glow';
  
      xAxis = new Rickshaw.Graph.Axis.Time( {
        graph: graph,
        // ticksTreatment: ticksTreatment,
        timeFixture: new Rickshaw.Fixtures.Time.Local()
      } );
  
      xAxis.render();
  
      yAxis = new Rickshaw.Graph.Axis.Y( {
        graph: graph,
        tickFormat: Rickshaw.Fixtures.Number.formatKMBT,
        ticksTreatment: ticksTreatment
      } );
  
      yAxis.render();
  
      previewXAxis = new Rickshaw.Graph.Axis.Time({
        graph: preview.previews[0],
        timeFixture: new Rickshaw.Fixtures.Time.Local(),
        ticksTreatment: ticksTreatment
      });
  
      previewXAxis.render();
  
      offsetForm = document.getElementById('offset_form');
  
      offsetForm.addEventListener('change', function(e) {
        var offsetMode = e.target.value;
  
        if (offsetMode == 'lines') {
          graph.setRenderer('line');
          graph.offset = 'zero';
          
        } else {
          graph.setRenderer('stack');
          graph.offset = offsetMode;
        } 
        graph.render();
       
      }, false);
  
    } // End init update
  
  
  
    function name2id (p_name) {
      var l_index = -1;
      seriesHistoryData.forEach(function (data,i) {
        if (data.name == p_name) {l_index = i; return;};
      });
      return l_index;
    }
  
  }
  
  
  ///////////////////////////////////////////////////////////
  // UPDATE CLASS ////////////////////////////////////
  ///////////////////////////////////////////////////////////
  
  function TimelineValue (p_update_url, p_url_params, p_url_id_name, p_timeInterval, p_init_period, p_annotator, p_use_old_value) {
  
    var update_url = p_update_url
    var url_params = p_url_params
    var url_id_name = p_url_id_name
    var timeInterval = p_timeInterval || 1;
    var annotator = p_annotator || null;
  
    var use_old_value = 0;
  
    var palette = new Rickshaw.Color.Palette( { scheme: 'cool' } );
    var timeBase = Math.floor(new Date().getTime() / 1000) - (p_init_period*timeInterval);
  
  
    function getData (p_url_params,p_error_message) {
      
      var jsonData = null;
      
      $.ajax({
         type: 'GET',
         url: update_url,
         data: p_url_params,
         async: false,
         success: function(content) {
            jsonData = jQuery.parseJSON(content);
         },
         error: function(content) {
           console.log(p_error_message);
         }
       });
  
      return jsonData;
    }
  
    this.initJsonData = function(p_g_data,p_h_data,p_graph_info) {
  
      var index = 0;
      
      var jsonData = getData(url_params,"initData JSON error");
  
      jsonData.forEach( function (flow,i) {
        // Initialize graph and historical data
        p_g_data[i] = [];
        p_g_data[i].push( { x: (index * timeInterval) + timeBase, y: flow.value } );
        p_graph_info.series.push(
        {
         color: palette.color(),
         data: p_g_data[i],
         name: flow.label
        });
        
        p_h_data[i] = {
          name : flow.name,
          label : flow.label,
          value : flow.value,
          memory : flow.actual_memory,
          cpu: flow.average_cpu_load
         }; 
  
      });
    
    }; //End initJsonData
  
  
    this.addJsonData = function(p_g_data,p_h_data) {
  
      var index = p_g_data[0].length;
      
      // Using historical structure in order to use the process name to get the new values
      p_h_data.forEach( function (current_data,i) {
        var value = -1;
        var l_url_param = {};
        l_url_param.mode = url_params.mode;
        l_url_param.name = current_data.name;
        // console.log(current_data.name);
        // console.log(l_url_param);
        
        var jsonData = getData(l_url_param,"updateData JSON error");
  
        if (jsonData[0] != null) {
          value = jsonData[0].value;
          // console.log(value);
          // Update historical value
          // console.log(p_h_data[i].name);
          // console.log(p_h_data[i].value);
          p_h_data[i].value = value;
          p_h_data[i].actual_memory = jsonData[0].actual_memory;
          p_h_data[i].average_cpu_load = jsonData[0].average_cpu_load;
          
          // console.log("Name:"+p_h_data[i].name+",Diff value:"+value+"\n");
        }
        
        if (value == -1) {
          
          if (use_old_value == 1) {
            value = current_data.value;
            console.log("getNewValue JSON empty => Process ID:"+current_data.name+", Old Value: "+p_h_data[i].value);
          } else {
            value = 0;
          }
  
          if (annotator != null) 
          {
            annotator.add(p_g_data[i][p_g_data[i].length-1].x, "The " + current_data.name + " process is inactive.");
            annotator.update();
          }
          
        }
  
        // Real update graph value
        p_g_data[i].push( { x: (index * timeInterval) + timeBase, y: value } );
      });
  
    }; //End addJsonData
  
  
    this.addDataEmpty = function(p_g_data) {
      var index = p_g_data[0].length;
      // alert(index);
      p_g_data.forEach( function(series) {
        series.push( { x: (index * timeInterval) + timeBase, y: 0 } );
      } );
  
    };
  
  
    this.removeData = function(p_g_data) {
      p_g_data.forEach( function(series) {
        series.shift();
      } );
      timeBase += timeInterval;
    };
  
    this.setAnnotator = function (p_annotator) {annotator = p_annotator; };
  };
  
</script>

<div class="tab-pane" id="Timeline">
  <h2>]] print(i18n("processes_stats.processes_timeline_title")) print[[</h2><br/> 
  <table class="table table-bordered">
    <tr>
      
      <th class="text-start span3">
        <legend>]] print(i18n("processes_stats.legend")) print[[</legend>
        <div id="legend"></div>
        <br/><br/>
        <legend>]] print(i18n("processes_stats.type")) print[[</legend>
        <form id="offset_form" class="toggler">
          <fieldset>
            <label class="radio inline">
              <input type="radio" name="offset" id="stack" value="zero" checked>
              ]] print(i18n("processes_stats.stack")) print[[
            </label>
            <label class="radio inline">
              <input type="radio" name="offset" id="lines" value="lines">
              ]] print(i18n("processes_stats.lines")) print[[
            </label>
          </fieldset>
        </form>
       
      </th>

      <td class="span3">
        <div id="chart_container">
          <div id="chart"></div>
          <div id="line"></div>
          <div id="preview"></div>
        </div>
      </td>
    
    </tr>
  </table>


<script>
  do_timeline("]]
print (ntop.getHttpPrefix())
print [[/lua/get_processes_data.lua",{ procstats_mode: "timeline" }, "name" ,2,300,2000);
</script>

</div>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

