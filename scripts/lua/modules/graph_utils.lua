--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
require "db_utils"
require "historical_utils"
require "rrd_paths"

local dkjson = require("dkjson")
local host_pools = require "host_pools"
local top_talkers_utils = require "top_talkers_utils"
local os_utils = require "os_utils"
local graph_common = require "graph_common"
local have_nedge = ntop.isnEdge()

local ts_utils = require("ts_utils")

local iface_behavior_update_freq = 300 --Seconds

-- ########################################################

local graph_utils = {}

-- ########################################################

if(ntop.isPro()) then
   -- if the version is pro, we include nv_graph_utils as part of this module
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   graph_utils = require "nv_graph_utils"
end

-- ########################################################

graph_utils.graph_colors = {
   '#1f77b4',
   '#ff7f0e',
   '#2ca02c',
   '#d62728',
   '#9467bd',
   '#8c564b',
   '#e377c2',
   '#7f7f7f',
   '#bcbd22',
   '#17becf',
   -- https://github.com/mbostock/d3/wiki/Ordinal-Scales
   '#ff7f0e',
   '#ffbb78',
   '#1f77b4',
   '#aec7e8',
   '#2ca02c',
   '#98df8a',
   '#d62728',
   '#ff9896',
   '#9467bd',
   '#c5b0d5',
   '#8c564b',
   '#c49c94',
   '#e377c2',
   '#f7b6d2',
   '#7f7f7f',
   '#c7c7c7',
   '#bcbd22',
   '#dbdb8d',
   '#17becf',
   '#9edae5'
}

-- ########################################################

-- @brief Ensure that the provided series have the same number of points. This is a
-- requirement for the charts.
-- @param series a list of series to fix. The format of each serie is the one
-- returned by ts_utils.query
-- @note the series are modified in place
function graph_utils.normalizeSeriesPoints(series)
   -- local format_utils = require "format_utils"

   -- for idx, data in ipairs(series) do
   --    for _, s in ipairs(data.series) do
   -- 	 if not s.tags.protocol then
   -- 	    tprint({step = data.step, num = #s.data, start = format_utils.formatEpoch(data.start), count = s.count, label = s.label})
   -- 	 end
   --    end
   -- end

   local max_count = 0
   local min_step = math.huge
   local ts_common = require("ts_common")

   for _, serie in pairs(series) do
      max_count = math.max(max_count, #serie.series[1].data)
      min_step = math.min(min_step, serie.step)
   end

   if max_count > 0 then
      for _, serie in pairs(series) do
	 local count = #serie.series[1].data

	 if count ~= max_count then
	    serie.count = max_count

	    for _, serie_data in pairs(serie.series) do
	       -- The way this function perform the upsampling is partial.
	       -- Only points are upsampled, times are not adjusted.
	       -- In addition, the max_count is fixed and this causes series
	       -- with different lengths to be upsampled differently.
	       -- For example a 240-points timeseries with lenght 1-day
	       -- and a 10 points timeseris with length 1-hour would result
	       -- the the 1-hour timeseries being divided into 240 points, actually
	       -- ending up in having a much smaller step.
	       -- TODO: adjust timeseries times.
	       -- TODO: handle series with different start and end times.
	       serie_data.data = ts_common.upsampleSerie(serie_data.data, max_count)
	       -- The new step needs to be adjusted as well. The new step is smaller
	       -- than the new step. To calculate it, multiply the old step by the fraction
	       -- of old vs new points.
	       local new_step = round(serie.step * count / max_count, 0)
	       serie.step = new_step

	       serie_data.step = new_step
	       serie_data.count = max_count
	    end
	 end
      end
   end
end

-- ########################################################

function graph_utils.getProtoVolume(ifName, start_time, end_time, ts_options)
   ifId = getInterfaceId(ifName)
   local series = ts_utils.listSeries("iface:ndpi", {ifid = ifId}, start_time)

   ret = { }

   for _, tags in ipairs(series or {}) do
      -- NOTE: this could be optimized via a dedicated driver call
      local data = ts_utils.query("iface:ndpi", tags, start_time, end_time, ts_options)

      if(data ~= nil) and (data.statistics.total > 0) then
	 ret[tags.protocol] = data.statistics.total
      end
   end

   return(ret)
end

-- ########################################################

function graph_utils.breakdownBar(sent, sentLabel, rcvd, rcvdLabel, thresholdLow, thresholdHigh)
   if((sent+rcvd) > 0) then
    sent2rcvd = round((sent * 100) / (sent+rcvd), 0)
    -- io.write("****>> "..sent.."/"..rcvd.."/"..sent2rcvd.."\n")
    if((thresholdLow == nil) or (thresholdLow < 0)) then thresholdLow = 0 end
    if((thresholdHigh == nil) or (thresholdHigh > 100)) then thresholdHigh = 100 end

    if(sent2rcvd < thresholdLow) then sentLabel = '<i class="fas fa-exclamation-triangle fa-lg"></i> '..sentLabel
    elseif(sent2rcvd > thresholdHigh) then rcvdLabel = '<i class="fas fa-exclamation-triangle fa-lg""></i> '..rcvdLabel end

      print('<div class="progress"><div class="progress-bar bg-warning" aria-valuenow="'.. sent2rcvd..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. sent2rcvd.. '%;">'..sentLabel)
      print('</div><div class="progress-bar bg-success" aria-valuenow="'.. (100-sent2rcvd)..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. (100-sent2rcvd) .. '%;">' .. rcvdLabel .. '</div></div>')

   else
      print('&nbsp;')
   end
end

-- ########################################################

function graph_utils.percentageBar(total, value, valueLabel)
   -- io.write("****>> "..total.."/"..value.."\n")
   if((total ~= nil) and (total > 0)) then
      pctg = round((value * 100) / total, 0)
      print('<div class="progress"><div class="progress-bar bg-warning" aria-valuenow="'.. pctg..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. pctg.. '%;">'..valueLabel)
      print('</div></div>')
   else
      print('&nbsp;')
   end
end

-- ########################################################

function graph_utils.makeProgressBar(percentage)
   -- nan check
   if percentage ~= percentage then
      return ""
   end

   local perc_int = round(percentage)
   return '<span style="width: 70%; float:left"><div class="progress"><div class="progress-bar bg-warning" aria-valuenow="'..
      perc_int ..'" aria-valuemin="0" aria-valuemax="100" style="width: '.. perc_int ..'%;"></div></div></span><span style="width: 30%; margin-left: 15px;">'..
      round(percentage, 1) ..' %</span>'
end


-- ########################################################

--! @brief Prints stacked progress bars with a legend
--! @total the raw total value (associated to full bar width)
--! @param bars a table with elements in the following format:
--!    - title: the item legend title
--!    - value: the item raw value
--!    - class: the bootstrap color class, usually: "default", "info", "danger", "warning", "success"
--! @param other_label optional name for the "other" part of the bar. If nil, it will not be shown.
--! @param formatter an optional item value formatter
--! @param css_class an optional css class to apply to the progress div
--! @skip_zero_values don't display values containing only zero
--! @return html for the bar
function graph_utils.stackedProgressBars(total, bars, other_label, formatter, css_class, skip_zero_values)
   local res = {}
   local cumulative = 0
   local cumulative_perc = 0
   local skip_zero_values = skip_zero_values or false
   formatter = formatter or (function(x) return x end)

   -- The bars
   res[#res + 1] = [[<div class=']] .. (css_class or "ntop-progress-stacked") .. [['><div class="progress">]]

   for _, bar in ipairs(bars) do cumulative = cumulative + bar.value end
   if cumulative > total then total = cumulative end

   for _, bar in ipairs(bars) do
      local percentage = round(bar.value * 100 / total, 2)
      if cumulative_perc + percentage > 100 then percentage = 100 - cumulative_perc end
      cumulative_perc = cumulative_perc + percentage
      if bar.class == nil then bar.class = "primary" end
      if bar.style == nil then bar.style = "" end
      if bar.link ~= nil then
         res[#res + 1] = [[<a href="]] .. bar.link .. [[" style="width:]] .. percentage .. [[%;]] .. bar.style .. [[">
            <div class="progress-bar bg-]] .. (bar.class) .. [[" role="progressbar" style="width: 100%"></div></a>]]
      else
         res[#res + 1] = [[
            <div class="progress-bar bg-]] .. (bar.class) .. [[" role="progressbar" style="width:]] .. percentage .. [[%;]] .. bar.style .. [["></div></a>]]
      end
      if bar.link ~= nil then res[#res + 1] = [[</a>]] end
   end

   res[#res + 1] = [[
      </div></div>]]

   -- The legend
   res[#res + 1] = [[<div class="ntop-progress-stacked-legend">]]

   local legend_items = bars

   if other_label ~= nil then
      legend_items = bars

      legend_items[#legend_items + 1] = {
         title = other_label,
         class = "empty",
         style = "",
         value = math.max(total - cumulative, 0),
      }
   end

   num = 0
   for _, bar in ipairs(legend_items) do

      if skip_zero_values and bar.value == 0 then goto continue end

      res[#res + 1] = [[<span>]]
      if(num > 0) then res[#res + 1] = [[<br>]] end
      if bar.link ~= nil then res[#res + 1] = [[<a href="]] .. bar.link .. [[">]] end
      res[#res + 1] = [[<span class="badge bg-]].. (bar.class) ..[[" style="]] .. bar.style .. [[">&nbsp;</span>]]
      if bar.link ~= nil then res[#res + 1] = [[</a>]] end
      res[#res + 1] = [[<span> ]] .. bar.title .. " (".. formatter(bar.value) ..")</span></span>"
      num = num + 1

      ::continue::
   end

   res[#res + 1] = [[<span style="margin-left: 0"><span></span><span>&nbsp;&nbsp;-&nbsp;&nbsp;]] .. i18n("total") .. ": ".. formatter(total) .."</span></span>"

   return table.concat(res)
end

-- ########################################################

local function getMinZoomResolution(schema)
   local schema_obj = ts_utils.getSchema(schema)

   if schema_obj then
      if schema_obj.options.step >= 300 then
	 return '30m'
      elseif schema_obj.options.step >= 60 then
         return '5m'
      end
   end

   return '1m'
end

-- #################################################

local function printGraphTopFlows(ifId, host, epoch, zoomLevel, l7proto, vlan)
   -- Check if the DB is enabled
   rsp = interface.execSQLQuery("show tables")
   if(rsp == nil) then return end

   if((epoch == nil) or (epoch == "")) then epoch = os.time() end

   local d = graph_common.getZoomDuration(zoomLevel)

   epoch_end = epoch
   epoch_begin = epoch-d

   historicalFlowsTab(ifId, host, epoch_begin, epoch_end, l7proto, '', '', '', vlan)
end

-- ########################################################

function graph_utils.drawGraphs(ifid, schema, tags, zoomLevel, baseurl, selectedEpoch, options)
   local page_utils =require("page_utils") -- Do not require at the top as it could conflict with plugins_utils.getMenuEntries
   local debug_rrd = false
   local is_system_interface = page_utils.is_system_view()
   options = options or {}

   if((selectedEpoch == nil) or (selectedEpoch == "")) then
      -- Refresh the page every minute unless:
      -- ** a specific epoch has been selected or
      -- ** the user is browsing historical top talkers and protocols
      print[[
       <script>
       setInterval(function() {
            var talkers_loaded, protocols_loaded, flows_loaded;
            if($('a[href="#historical-top-talkers"]').length){
               talkers_loaded   = $('a[href="#historical-top-talkers"]').attr("loaded");
            }
            if($('a[href="#historical-top-apps"]').length){
               protocols_loaded = $('a[href="#historical-top-apps"]').attr("loaded");
            }
            if($('a[href="#historical-flows"]').length){
               flows_loaded = $('a[href="#historical-flows"]').attr("loaded");
            }
            if(typeof talkers_loaded == 'undefined'
                     && typeof protocols_loaded == 'undefined'
                     && typeof flows_loaded == 'undefined'){
         ]] if not ntop.isPro() then print[[
               window.location.reload(); /* do not reload, it's annoying */
         ]]
            end
            print[[
               }
         }, 60*1000);
         </script>]]
   end

   local min_zoom = getMinZoomResolution(schema)
   local min_zoom_k = 1
   if(zoomLevel == nil) then zoomLevel = min_zoom end

   if graph_utils.drawProGraph then
      _ifstats = interface.getStats()
      graph_utils.drawProGraph(ifid, schema, tags, zoomLevel, baseurl, options)
      return
   end

   nextZoomLevel = zoomLevel;
   epoch = tonumber(selectedEpoch);

   for k,v in ipairs(graph_common.zoom_vals) do
      if graph_common.zoom_vals[k][1] == min_zoom then
         min_zoom_k = k
      end

      if(graph_common.zoom_vals[k][1] == zoomLevel) then
	 if(k > 1) then
	    nextZoomLevel = graph_common.zoom_vals[math.max(k-1, min_zoom_k)][1]
	 end
	 if(epoch ~= nil) then
	    start_time = epoch - math.floor(graph_common.zoom_vals[k][3] / 2)
	    end_time = epoch + math.floor(graph_common.zoom_vals[k][3] / 2)
	 else
	    end_time = os.time()
	    start_time = end_time - graph_common.zoom_vals[k][3]
	 end
      end
   end

   if options.tskey then
      -- this can contain a MAC address for local broadcast domain hosts
      -- table.clone needed to modify some parameters while keeping the original unchanged
      tags = table.clone(tags)
      tags.host = options.tskey
   end

   local data = ts_utils.query(schema, tags, start_time, end_time)

   if(data) then
      print [[

      <style>
         #chart_container {
            display: inline-block;
            font-family: Arial, Helvetica, sans-serif;
         }
         #chart {
            float: left;
         }
         #legend {
            float: left;
            margin-left: 15px;
            color: black;
            background: white;
         }
         #y_axis {
            float: left;
            width: 40px;
         }
   </style>

<div>

   <div class='card'>
      <div class='card-header'>
         <ul class="nav nav-tabs card-header-tabs" role="tablist" id="historical-tabs-container">
            <li class="nav-item active"> <a class="nav-link active" href="#historical-tab-chart" role="tab" data-bs-toggle="tab"> Chart </a> </li>
]]

   local show_historical_tabs = ntop.getPrefs().is_dump_flows_to_mysql_enabled and options.show_historical

   if show_historical_tabs then
      print('<li class="nav-item"><a class="nav-link" href="#historical-flows" role="tab" data-bs-toggle="tab" id="tab-flows-summary"> Flows </a> </li>\n')
   end

   print[[
</ul>
</div>
<div class='card-body'>
  <div class="tab-content">
    <div class="tab-pane active in" id="historical-tab-chart">
<table border=0>
<tr><td valign="top">
]]

   local page_params = {
      ts_schema = schema,
      zoom = zoomLevel or '',
      epoch = selectedEpoch or '',
      tskey = options.tskey,
   }

   if(options.timeseries) then
      print [[
   <div class="dropdown d-inline">
      <button class="btn btn-light btn-sm dropdown-toggle" data-bs-toggle="dropdown">Timeseries <span class="caret"></span></button>
      <div class="dropdown-menu scrollable-dropdown">
      ]]

      graph_common.printSeries(options, tags, start_time, end_time, baseurl, page_params)
      graph_common.printGraphMenuEntries(graph_common.printEntry, nil, start_time, end_time)

      print [[
      </div>
   </div><!-- /btn-group -->
      ]]
   end -- options.timeseries

   print('<span class="mx-1">Timeframe:</span><div class="btn-group" role="group" id="graph_zoom">\n')

   for k,v in ipairs(graph_common.zoom_vals) do
      -- display 1 minute button only for networks and interface stats
      -- but exclude applications. Application statistics are gathered
      -- every 5 minutes
      if graph_common.zoom_vals[k][1] == '1m' and min_zoom ~= '1m' then
         goto continue
      elseif graph_common.zoom_vals[k][1] == '5m' and min_zoom ~= '1m' and min_zoom ~= '5m' then
         goto continue
      end
      
      local params = table.merge(page_params, {zoom=graph_common.zoom_vals[k][1]})

      -- Additional parameters
      if tags.protocol ~= nil then
         params["protocol"] = tags.protocol
      end
      if tags.category ~= nil then
         params["category"] = tags.category
      end

      local url = getPageUrl(baseurl, params)
      print('<input type="radio" class="btn-check" name="options" id="zoom_level_'..k..'" value="'..url..'">')

      if(graph_common.zoom_vals[k][1] == zoomLevel) then
         print([[<label class="btn bg-primary text-white" for='zoom_level_]].. k ..[['>]]..  graph_common.zoom_vals[k][1] ..[[</label>]])
      else
         print([[<label class="btn btn-outline-secondary" for='zoom_level_]].. k ..[['>]]..  graph_common.zoom_vals[k][1] ..[[</label>]])
      end


      ::continue::
   end

   print [[
</div>
</div>

<script>
   $('input:radio[id^=zoom_level_]').change( function() {
   window.open(this.value,'_self',false);
});
</script>

<div id="legend"></div>
<div id="chart_legend"></div>
<div id="chart" style="margin-right: 50px; margin-left: 10px; display: table-cell"></div>
<p style='color: lightgray'><small>NOTE: Click on the graph to zoom.</small>

</td>


<td rowspan=2>
<div id="y_axis"></div>

<div style="margin-left: 10px; display: table">
<div id="chart_container" style="display: table-row">

   ]]

   local format_as_bps = true
   local format_as_bytes = false
   local formatter_fctn

   local label = data.series[1].label

   -- Attempt at reading the formatter from the options using the schema
   local formatter
   if options and options.timeseries then
      for _, cur_ts in pairs(options.timeseries or {}) do
	 if cur_ts.schema == schema and cur_ts.value_formatter then
	    formatter = cur_ts.value_formatter[1] or cur_ts.value_formatter
	    break
	 end
      end
   end
   
   if label == "load_percentage" then
      formatter_fctn = "NtopUtils.ffloat"
      format_as_bps = false
   elseif label == "resident_bytes" then
      formatter_fctn = "NtopUtils.bytesToSize"
      format_as_bytes = true
   elseif string.contains(label, "pct") then
      formatter_fctn = "NtopUtils.fpercent"
      format_as_bps = false
      format_as_bytes = false
   elseif schema == "process:num_alerts" then
      formatter_fctn = "NtopUtils.falerts"
      format_as_bps = false
      format_as_bytes = false
   elseif label:contains("millis") or label:contains("_ms") then
      formatter_fctn = "NtopUtils.fmillis"
      format_as_bytes = false
      format_as_bps = false
   elseif string.contains(label, "packets") or string.contains(label, "flows") or label:starts("num_") or label:contains("alerts") then
      formatter_fctn = "NtopUtils.fint"
      format_as_bytes = false
      format_as_bps = false
   elseif formatter then
      -- The formatter specified in the options
      formatter_fctn = formatter
      format_as_bytes = false
      format_as_bps = false
   else
      formatter_fctn = (is_system_interface and "NtopUtils.fnone" or "NtopUtils.fbits")
   end

   print [[
   <table class="table table-bordered table-striped" style="border: 0; margin-right: 10px; display: table-cell">
   ]]

   print('   <tr><th>&nbsp;</th><th>Time</th><th>Value</th></tr>\n')

   local stats = data.statistics

   if(stats ~= nil) then
      local minval_time = stats.min_val_idx and (data.start + data.step * stats.min_val_idx) or 0
      local maxval_time = stats.max_val_idx and (data.start + data.step * stats.max_val_idx) or 0
      local lastval_time = data.start + data.step * (data.count-1)
      local lastval = 0

      for _, serie in pairs(data.series) do
         lastval = lastval + (serie.data[data.count] or 0)
      end

      if format_as_bytes then
         if(minval_time > 0) then print('   <tr><th>Min</th><td>' .. os.date("%x %X", minval_time) .. '</td><td>' .. bytesToSize((stats.min_val*8) or "") .. '</td></tr>\n') end
         if(maxval_time > 0) then print('   <tr><th>Max</th><td>' .. os.date("%x %X", maxval_time) .. '</td><td>' .. bytesToSize((stats.max_val*8) or "") .. '</td></tr>\n') end
         print('   <tr><th>Last</th><td>' .. os.date("%x %X", lastval_time) .. '</td><td>' .. bytesToSize(lastval*8)  .. '</td></tr>\n')
         print('   <tr><th>Average</th><td colspan=2>' .. bytesToSize(stats.average*8) .. '</td></tr>\n')
         print('   <tr><th>95th <A HREF=https://en.wikipedia.org/wiki/Percentile>Percentile</A></th><td colspan=2>' .. bytesToSize(stats["95th_percentile"]*8) .. '</td></tr>\n')
      elseif(not format_as_bps) then
         if(minval_time > 0) then print('   <tr><th>Min</th><td>' .. os.date("%x %X", minval_time) .. '</td><td>' .. formatValue(stats.min_val or "") .. '</td></tr>\n') end
         if(maxval_time > 0) then print('   <tr><th>Max</th><td>' .. os.date("%x %X", maxval_time) .. '</td><td>' .. formatValue(stats.max_val or "") .. '</td></tr>\n') end
         print('   <tr><th>Last</th><td>' .. os.date("%x %X", lastval_time) .. '</td><td>' .. formatValue(round(lastval), 1) .. '</td></tr>\n')
         print('   <tr><th>Average</th><td colspan=2>' .. formatValue(round(stats.average, 2)) .. '</td></tr>\n')
         print('   <tr><th>95th <A HREF=https://en.wikipedia.org/wiki/Percentile>Percentile</A></th><td colspan=2>' .. formatValue(round(stats["95th_percentile"], 2)) .. '</td></tr>\n')
      elseif is_system_interface then
         if(minval_time > 0) then print('   <tr><th>Min</th><td>' .. os.date("%x %X", minval_time) .. '</td><td>' .. (formatValue(round(stats["min_val"], 2)) or "") .. '</td></tr>\n') end
         if(maxval_time > 0) then print('   <tr><th>Max</th><td>' .. os.date("%x %X", maxval_time) .. '</td><td>' .. (formatValue(round(stats["max_val"], 2)) or "") .. '</td></tr>\n') end
         print('   <tr><th>Last</th><td>' .. os.date("%x %X", lastval_time) .. '</td><td>' .. formatValue(round(lastval, 2)) .. '</td></tr>\n')
         print('   <tr><th>Average</th><td colspan=2>' ..formatValue(round(stats["average"], 2)).. '</td></tr>\n')
         print('   <tr><th>95th <A HREF=https://en.wikipedia.org/wiki/Percentile>Percentile</A></th><td colspan=2>' ..(formatValue(round(stats["95th_percentile"], 2)) or '') .. '</td></tr>\n')
         print('   <tr><th>Total Traffic</th><td colspan=2>' .. (stats.total or '') .. '</td></tr>\n')
      else
         if(minval_time > 0) then print('   <tr><th>Min</th><td>' .. os.date("%x %X", minval_time) .. '</td><td>' .. bitsToSize((stats.min_val*8) or "") .. '</td></tr>\n') end
         if(maxval_time > 0) then print('   <tr><th>Max</th><td>' .. os.date("%x %X", maxval_time) .. '</td><td>' .. bitsToSize((stats.max_val*8) or "") .. '</td></tr>\n') end
         print('   <tr><th>Last</th><td>' .. os.date("%x %X", lastval_time) .. '</td><td>' .. bitsToSize(lastval*8)  .. '</td></tr>\n')
         print('   <tr><th>Average</th><td colspan=2>' .. bitsToSize(stats.average*8) .. '</td></tr>\n')
         print('   <tr><th>95th <A HREF=https://en.wikipedia.org/wiki/Percentile>Percentile</A></th><td colspan=2>' .. bitsToSize(stats["95th_percentile"]*8) .. '</td></tr>\n')
         print('   <tr><th>Total Traffic</th><td colspan=2>' .. bytesToSize(stats.total) .. '</td></tr>\n')
      end
   end

   print('   <tr><th>Time</th><td colspan=2><div id=when></div></td></tr>\n')

   -- hide Minute Interface Top Talker if we are in system interface
   if top_talkers_utils.areTopEnabled(ifid) and not is_system_interface then
      print('   <tr><th>Minute<br>Interface<br>Top Talkers</th><td colspan=2><div id=talkers></div></td></tr>\n')
   end


   print [[
   </table>
   ]]

   print[[</div></td></tr></table>

    </div> <!-- closes div id "historical-tab-chart "-->
   ]]

   if show_historical_tabs then
      local host = tags.host -- can be nil
      local l7proto = tags.protocol or ""
      local k2info = hostkey2hostinfo(host)

      print('<div class="tab-pane" id="historical-flows">')
      if tonumber(start_time) ~= nil and tonumber(end_time) ~= nil then
         -- if both start_time and end_time are vaid epoch we can print finer-grained top flows
         historicalFlowsTab(ifid, k2info["host"] or '', start_time, end_time, l7proto, '', '', '', k2info["vlan"])
      else
         printGraphTopFlows(ifid, k2info["host"] or '', _GET["epoch"], zoomLevel, l7proto, k2info["vlan"])
      end
      print('</div>')
   end

   print[[
  </div> <!-- closes div class "tab-content" -->
  </div>
</div> <!-- closes div class "card" -->]]

   local ui_utils = require("ui_utils")
   print(ui_utils.render_notes(options.notes))

   print[[
<script>

var palette = new Rickshaw.Color.Palette();

var graph = new Rickshaw.Graph( {
				   element: document.getElementById("chart"),
				   width: 600,
				   height: 300,
				   renderer: 'area',
				   series: [
				]]

   for serie_idx, serie in ipairs(data.series) do
      print("{name: \"" .. serie.label .. "\"")
      print("\n, color: '".. graph_utils.graph_colors[serie_idx] .."', data: [")

      local t = data.start

      for i, val in ipairs(serie.data) do
         print("{x: " .. t)
         if (format_as_bps) then
            print(",y: " .. (val*8) .. "},\n")
         else
            print(",y: " .. val .. "},\n")
         end
         t = t + data.step
      end

      print("]},")
   end

   print [[
				]} );

graph.render();

var chart_legend = document.querySelector('#chart_legend');

var Hover = Rickshaw.Class.create(Rickshaw.Graph.HoverDetail, {
    graph: graph,
    xFormatter: function(x) { return new Date( x * 1000 ); },
    yFormatter: function(bits) { return(]] print(formatter_fctn) print [[(bits)); },
    render: function(args) {
		var graph = this.graph;
		var points = args.points;
		var point = points.filter( function(p) { return p.active } ).shift();

		if(point.value.y === null) return;

		var formattedXValue = NtopUtils.fdate(point.value.x); // point.formattedXValue;
		var formattedYValue = ]]
   print(formatter_fctn)
   print [[(point.value.y); // point.formattedYValue;
		var infoHTML = "";
]]

   print[[

infoHTML += "<ul>";
$.ajax({
	  type: 'GET',
	  url: ']]
   print(ntop.getHttpPrefix().."/lua/get_top_talkers.lua?epoch='+point.value.x+'&addvlan=true")
   print [[',
		  data: { epoch: point.value.x },
		  async: false,
		  success: function(content) {
		   var info = jQuery.parseJSON(content);
		   $.each(info, function(i, n) {
		     if (n.length > 0)
		       infoHTML += "<li>"+NtopUtils.capitaliseFirstLetter(i)+" [Avg Traffic/sec]<ol>";
		     var items = 0;
		     var other_traffic = 0;
		     $.each(n, function(j, m) {
		       if((items < 3) && (m.address != "Other")) {
			 infoHTML += "<li><a href='host_details.lua?host="+m.address+"'>"+NtopUtils.abbreviateString(m.label ? m.label : m.address,24);
		       infoHTML += "</a>";
		       if (m.vlan != "0") infoHTML += " ("+m.vlanm+")";
		       infoHTML += " ("+NtopUtils.fbits((m.value*8)/60)+")</li>";
			 items++;
		       } else
			 other_traffic += m.value;
		     });
		     if (other_traffic > 0)
			 infoHTML += "<li>Other ("+NtopUtils.fbits((other_traffic*8)/60)+")</li>";
		     if (n.length > 0)
		       infoHTML += "</ol></li>";
		   });
		   infoHTML += "</ul></li></li>";
	   }
   });
infoHTML += "</ul>";]]

   print [[
		this.element.innerHTML = '';
		this.element.style.left = graph.x(point.value.x) + 'px';

		/*var xLabel = document.createElement('div');
		xLabel.setAttribute("style", "opacity: 0.5; background-color: #EEEEEE; filter: alpha(opacity=0.5)");
		xLabel.className = 'x_label';
		xLabel.innerHTML = formattedXValue + infoHTML;
		this.element.appendChild(xLabel);
		*/
		$('#when').html(formattedXValue);
		$('#talkers').html(infoHTML);


		var item = document.createElement('div');

		item.className = 'item';
		item.innerHTML = this.formatter(point.series, point.value.x, point.value.y, formattedXValue, formattedYValue, point);
		item.style.top = this.graph.y(point.value.y0 + point.value.y) + 'px';
		this.element.appendChild(item);

		var dot = document.createElement('div');
		dot.className = 'dot';
		dot.style.top = item.style.top;
		dot.style.borderColor = point.series.color;
		this.element.appendChild(dot);

		if(point.active) {
			item.className = 'item active';
			dot.className = 'dot active';
		}

		this.show();

		if(typeof this.onRender == 'function') {
			this.onRender(args);
		}

		// Put the selected graph epoch into the legend
		//chart_legend.innerHTML = point.value.x; // Epoch

		this.selected_epoch = point.value.x;

		//event
	}
} );

var hover = new Hover( { graph: graph } );

var legend = new Rickshaw.Graph.Legend( {
					   graph: graph,
					   element: document.getElementById('legend')
					} );

//var axes = new Rickshaw.Graph.Axis.Time( { graph: graph } ); axes.render();

var yAxis = new Rickshaw.Graph.Axis.Y({
    graph: graph,
    tickFormat: ]] print(formatter_fctn) print [[
});

yAxis.render();

]]

   if zoomLevel ~= nextZoomLevel then
      print[[
$("#chart").click(function() {
  if(hover.selected_epoch)
    window.location.href = ']]
      print(baseurl .. '&ts_schema=' .. schema .. '&zoom=' .. nextZoomLevel)

      if tags.protocol ~= nil then
         print("&protocol=" .. tags.protocol)
      elseif tags.category ~= nil then
         print("&category=" .. tags.category)
      end

      print('&epoch=')
      print[['+hover.selected_epoch;
});]]
   end

   print[[
</script>

]]
   else
      print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> No data found</div>")
   end -- if(data)
end

-- #################################################

--
-- proto table should contain the following information:
--    string   traffic_quota
--    string   time_quota
--    string   protoName
--
-- ndpi_stats or category_stats can be nil if they are not relevant for the proto
--
-- quotas_to_show can contain:
--    bool  traffic
--    bool  time
--
function graph_utils.printProtocolQuota(proto, ndpi_stats, category_stats, quotas_to_show, show_td, hide_limit)
    local total_bytes = 0
    local total_duration = 0
    local output = {}

    if ndpi_stats ~= nil then
      -- This is a single protocol
      local proto_stats = ndpi_stats[proto.protoName]
      if proto_stats ~= nil then
        total_bytes = proto_stats["bytes.sent"] + proto_stats["bytes.rcvd"]
        total_duration = proto_stats["duration"]
      end
    else
      -- This is a category
      local cat_stats = category_stats[proto.protoName]
      if cat_stats ~= nil then
        total_bytes = cat_stats["bytes"]
        total_duration = cat_stats["duration"]
      end
    end

    if quotas_to_show.traffic then
      local bytes_exceeded = ((proto.traffic_quota ~= "0") and (total_bytes >= tonumber(proto.traffic_quota)))
      local lb_bytes = bytesToSize(total_bytes)
      local lb_bytes_quota = ternary(proto.traffic_quota ~= "0", bytesToSize(tonumber(proto.traffic_quota)), i18n("unlimited"))
      local traffic_taken = ternary(proto.traffic_quota ~= "0", math.min(total_bytes, tonumber(proto.traffic_quota)), 0)
      local traffic_remaining = math.max(tonumber(proto.traffic_quota) - traffic_taken, 0)
      local traffic_quota_ratio = round(traffic_taken * 100 / (traffic_taken + traffic_remaining), 0) or 0
      if not traffic_quota_ratio then traffic_quota_ratio = 0 end

      if show_td then
        output[#output + 1] = [[<td class='text-end']]..ternary(bytes_exceeded, ' style=\'color:red;\'', '').."><span>"..lb_bytes..ternary(hide_limit, "", " / "..lb_bytes_quota).."</span>"
      end

      output[#output + 1] = [[
          <div class='progress' style=']]..(quotas_to_show.traffic_style or "")..[['>
            <div class='progress-bar bg-warning' aria-valuenow=']]..traffic_quota_ratio..'\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: '..traffic_quota_ratio..'%;\'>'..
              ternary(traffic_quota_ratio == traffic_quota_ratio --[[nan check]], traffic_quota_ratio, 0)..[[%
            </div>
          </div>]]
      if show_td then output[#output + 1] = ("</td>") end
    end

    if quotas_to_show.time then
      local time_exceeded = ((proto.time_quota ~= "0") and (total_duration >= tonumber(proto.time_quota)))
      local lb_duration = secondsToTime(total_duration)
      local lb_duration_quota = ternary(proto.time_quota ~= "0", secondsToTime(tonumber(proto.time_quota)), i18n("unlimited"))

      local duration_taken = ternary(proto.time_quota ~= "0", math.min(total_duration, tonumber(proto.time_quota)), 0)
      local duration_remaining = math.max(proto.time_quota - duration_taken, 0)
      local duration_quota_ratio = round(duration_taken * 100 / (duration_taken+duration_remaining), 0) or 0

      if show_td then
        output[#output + 1] = [[<td class='text-end']]..ternary(time_exceeded, ' style=\'color:red;\'', '').."><span>"..lb_duration..ternary(hide_limit, "", " / "..lb_duration_quota).."</span>"
      end

      output[#output + 1] = ([[
          <div class='progress' style=']]..(quotas_to_show.time_style or "")..[['>
            <div class='progress-bar bg-warning' aria-valuenow=']]..duration_quota_ratio..'\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: '..duration_quota_ratio..'%;\'>'..
              ternary(duration_quota_ratio == duration_quota_ratio --[[nan check]], duration_quota_ratio, 0)..[[%
            </div>
          </div>]])
      if show_td then output[#output + 1] = ("</td>") end
    end

    return table.concat(output, '')
end

-- #################################################

function graph_utils.poolDropdown(ifId, pool_id, exclude)
   local host_pools_instance = host_pools:create()
   pool_id = tostring(pool_id)

   local output = {}
   exclude = exclude or {}

   for _,pool in ipairs(host_pools_instance:get_all_pools()) do
      pool.pool_id = tostring(pool.pool_id)

      if (not exclude[pool.pool_id]) or (pool.pool_id == pool_id) then
	 output[#output + 1] = '<option value="' .. pool.pool_id .. '"'

	 if pool.pool_id == pool_id then
	    output[#output + 1] = ' selected'
	 end

	 local limit_reached = false

	 if not ntop.isEnterpriseM() then
	    local n_members = table.len(pool["members"])

	    if n_members >= host_pools.LIMITED_NUMBER_POOL_MEMBERS then
	       limit_reached = true
	    end
	 end

	 if exclude[pool.pool_id] or limit_reached then
	    output[#output + 1] = ' disabled'
	 end

	 output[#output + 1] = '>' .. pool.name .. ternary(limit_reached, " ("..i18n("host_pools.members_limit_reached")..")", "") .. '</option>'
      end
   end

   return table.concat(output, '')
end

-- #################################################

function graph_utils.printPoolChangeDropdown(ifId, pool_id, have_nedge)
   local output = {}

   output[#output + 1] = [[<tr>
      <th>]] .. i18n(ternary(have_nedge, "nedge.user", "host_config.host_pool")) .. [[</th>
      <td>
            <select name="pool" class="form-select" style="width:20em; display:inline;">]]

   output[#output + 1] = graph_utils.poolDropdown(ifId, pool_id)

   local edit_pools_link = ternary(have_nedge, "/lua/pro/nedge/admin/nf_list_users.lua", "/lua/admin/manage_pools.lua?page=host")

   output[#output + 1] = [[
            </select>
        <a class='ms-1' href="]] .. ntop.getHttpPrefix() .. edit_pools_link .. [["><i class="fas fa-edit" aria-hidden="true" title="]]
      ..(have_nedge and i18n("edit") or '')
      .. [["></i></a>
   </tr>]]

   print(table.concat(output, ''))
end

-- #################################################

function graph_utils.printCategoryDropdownButton(by_id, cat_id_or_name, base_url, page_params, count_callback, skip_unknown)
   local function count_all(cat_id, cat_name)
      local cat_protos = interface.getnDPIProtocols(tonumber(cat_id))
      return table.len(cat_protos)
   end

   cat_id_or_name = cat_id_or_name or ""
   count_callback = count_callback or count_all

   -- 'Category' button
   print('\'<div class="btn-group float-right"><div class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">'..
         i18n("category") .. ternary(not isEmptyString(cat_id_or_name), '<span class="fas fa-filter"></span>', '') ..
         '<span class="caret"></span></div> <ul class="dropdown-menu scrollable-dropdown" role="menu" style="min-width: 90px;">')

   -- 'Category' dropdown menu
   local entries = { {text=i18n("all"), id="", cat_id=""} }
   entries[#entries + 1] = ""
   for cat_name, cat_id in pairsByKeys(interface.getnDPICategories()) do
      local cat_count = count_callback(cat_id, cat_name)

      if(skip_unknown and (cat_id == "0") and (cat_count > 0)) then
         -- Do not count the Unknown protocol in the Unspecified category
         cat_count = cat_count - 1
      end

      if cat_count > 0 then
         entries[#entries + 1] = {text=cat_name.." ("..cat_count..")", id=cat_name, cat_id=cat_id}
      end
   end

   for _, entry in pairs(entries) do
      if entry ~= "" then
         page_params["category"] = ternary(by_id, ternary(entry.cat_id ~= "", "cat_" .. entry.cat_id, ""), entry.id)

         print('<li><a class="dropdown-item '.. ternary(cat_id_or_name == ternary(by_id, entry.cat_id, entry.id), 'active', '') ..'" href="' .. getPageUrl(base_url, page_params) .. '">' .. (entry.icon or "") ..
            entry.text .. '</a></li>')
      end
   end

   print('</ul></div>\', ')
   page_params["category"] = cat_id_or_name
end

-- #################################################

function graph_utils.getDeviceCommonTimeseries()
   return {
      {schema="mac:arp_rqst_sent_rcvd_rpls", label=i18n("graphs.arp_rqst_sent_rcvd_rpls")},
   }
end

-- #################################################

local default_timeseries = {
   {schema="iface:flows",                 label=i18n("graphs.active_flows")},
   {schema="iface:new_flows",             label=i18n("graphs.new_flows"), value_formatter = {"NtopUtils.fflows", "NtopUtils.formatFlows"}},
   {schema="iface:alerted_flows",         label=i18n("graphs.total_alerted_flows")},
   {schema="iface:hosts",                 label=i18n("graphs.active_hosts")},
   {schema="iface:alerts_stats",          label=i18n("show_alerts.iface_engaged_dropped_alerts"), skip=hasAllowedNetworksSet()},
   {schema="custom:flows_vs_local_hosts", label=i18n("graphs.flows_vs_local_hosts"), check={"iface:flows", "iface:local_hosts"}, step=60},
   {schema="custom:flows_vs_traffic",     label=i18n("graphs.flows_vs_traffic"), check={"iface:flows", "iface:traffic"}, step=60},
   {schema="custom:memory_vs_flows_hosts", label=i18n("graphs.memory_vs_hosts_flows"), check={"process:resident_memory", "iface:flows", "iface:hosts"}},
   {schema="iface:devices",               label=i18n("graphs.active_devices")},
   {schema="iface:http_hosts",            label=i18n("graphs.active_http_servers"), nedge_exclude=1},
   {schema="iface:traffic",               label=i18n("traffic")},
   {schema="iface:score",                 label=i18n("score"), metrics_labels = { i18n("graphs.cli_score"), i18n("graphs.srv_score")}},
   {schema="iface:traffic_rxtx",          label=i18n("graphs.traffic_rxtx"), split_directions = true, layout={ ["bytes_sent"] = "area", ["bytes_rcvd"] = "line" }, value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"} },
   {schema="iface:packets_vs_drops",      label=i18n("graphs.packets_vs_drops")},
   {schema="iface:nfq_pct",               label=i18n("graphs.num_nfq_pct"), nedge_only=1},
   {schema="iface:hosts_anomalies",       label=i18n("graphs.hosts_anomalies"), layout={ ["num_local_hosts_anomalies"] = "area", ["num_remote_hosts_anomalies"] = "area" }, metrics_labels = { i18n("graphs.loc_host_anomalies"), i18n("graphs.rem_host_anomalies")}  },
      
   {schema="iface:disc_prob_bytes",       label=i18n("graphs.discarded_probing_bytes"), nedge_exclude=1},
   {schema="iface:disc_prob_pkts",        label=i18n("graphs.discarded_probing_packets"), nedge_exclude=1},

   {schema="iface:dumped_flows",          label=i18n("graphs.dumped_flows"), metrics_labels = {i18n("graphs.dumped_flows"), i18n("graphs.dropped_flows")} },
   {schema="iface:zmq_recv_flows",        label=i18n("graphs.zmq_received_flows"), nedge_exclude=1},
   {schema="custom:zmq_msg_rcvd_vs_drops",label=i18n("graphs.zmq_msg_rcvd_vs_drops"), check={"iface:zmq_rcvd_msgs", "iface:zmq_msg_drops"}, metrics_labels = {i18n("if_stats_overview.zmq_message_rcvd"), i18n("if_stats_overview.zmq_message_drops")}, value_formatter = {"NtopUtils.fmsgs", "NtopUtils.formatMessages"}},
   {schema="iface:zmq_flow_coll_drops",   label=i18n("graphs.zmq_flow_coll_drops"), nedge_exclude=1, value_formatter = {"NtopUtils.fflows", "NtopUtils.formatFlows"}},
   {schema="iface:zmq_flow_coll_udp_drops", label=i18n("graphs.zmq_flow_coll_udp_drops"), nedge_exclude=1, value_formatter = {"NtopUtils.fpackets", "NtopUtils.formatPackets"}},
   {separator=1, nedge_exclude=1, label=i18n("tcp_stats")},
   {schema="iface:tcp_lost",              label=i18n("graphs.tcp_packets_lost"), nedge_exclude=1},
   {schema="iface:tcp_out_of_order",      label=i18n("graphs.tcp_packets_ooo"), nedge_exclude=1},
   --{schema="tcp_retr_ooo_lost",   label=i18n("graphs.tcp_retr_ooo_lost"), nedge_exclude=1},
   {schema="iface:tcp_retransmissions",   label=i18n("graphs.tcp_packets_retr"), nedge_exclude=1},
   {schema="iface:tcp_keep_alive",        label=i18n("graphs.tcp_packets_keep_alive"), nedge_exclude=1},
   {separator=1, label=i18n("tcp_flags")},
   {schema="iface:tcp_syn",               label=i18n("graphs.tcp_syn_packets"), nedge_exclude=1, pro_skip=1},
   {schema="iface:tcp_synack",            label=i18n("graphs.tcp_synack_packets"), nedge_exclude=1, pro_skip=1},
   {schema="custom:iface_tcp_syn_vs_tcp_synack", label=i18n("graphs.tcp_syn_vs_tcp_synack"), nedge_exclude=1, metrics_labels = {"SYN", "SYN+ACK"}},
   {schema="iface:tcp_finack",            label=i18n("graphs.tcp_finack_packets"), nedge_exclude=1},
   {schema="iface:tcp_rst",               label=i18n("graphs.tcp_rst_packets"), nedge_exclude=1},
}

if ntop.isPro() then
   local pro_timeseries = {
      {schema="iface:score_anomalies",       label=i18n("graphs.iface_score_anomalies")},
      {schema="iface:score_behavior",        label=i18n("graphs.iface_score_behavior"), split_directions = true --[[ split RX and TX directions ]], first_timeseries_only = true, metrics_labels = {i18n("graphs.score"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
      {schema="iface:traffic_anomalies",     label=i18n("graphs.iface_traffic_anomalies")},
      {schema="iface:traffic_rx_behavior_v2",   label=i18n("graphs.iface_traffic_rx_behavior"), split_directions = true --[[ split RX and TX directions ]], first_timeseries_only = true, time_elapsed = iface_behavior_update_freq, value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"}, metrics_labels = {i18n("graphs.traffic_rcvd"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
      {schema="iface:traffic_tx_behavior_v2",   label=i18n("graphs.iface_traffic_tx_behavior"), split_directions = true --[[ split RX and TX directions ]], first_timeseries_only = true, time_elapsed = iface_behavior_update_freq, value_formatter = {"NtopUtils.fbits_from_bytes", "NtopUtils.bytesToSize"}, metrics_labels = {i18n("graphs.traffic_sent"), i18n("graphs.lower_bound"), i18n("graphs.upper_bound")}},
   }

   default_timeseries = table.merge(pro_timeseries, default_timeseries)
end

-- #################################################

function graph_utils.get_default_timeseries()
   return(default_timeseries)
end

-- #################################################

function graph_utils.get_timeseries_layout(schema)

   local ret = {"area"} -- default

   for k,v in pairs(default_timeseries) do
      if (v.schema == schema) then
         if (v.layout) then
            ret = v.layout
         end
         break
      end
   end
   return (ret)
end

-- #################################################

return graph_utils
