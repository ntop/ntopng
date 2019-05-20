--
-- (C) 2013-18 - ntop.org
--
require "lua_utils"
require "db_utils"
require "historical_utils"
require "rrd_paths"
local dkjson = require("dkjson")
local host_pools_utils = require "host_pools_utils"
local os_utils = require "os_utils"
local have_nedge = ntop.isnEdge()

local ts_utils = require("ts_utils")

-- ########################################################

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "nv_graph_utils"
end

-- ########################################################

local graph_colors = {
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

function queryEpochData(schema, tags, selectedEpoch, zoomLevel, options)
   if(zoomLevel == nil) then zoomLevel = "1h" end
   local d = getZoomDuration(zoomLevel)
   local end_time
   local start_time

   if((selectedEpoch == nil) or (selectedEpoch == "")) then 
      selectedEpoch = os.time() 
      end_time = tonumber(selectedEpoch)   
      start_time = end_time - d
   else
      end_time = tonumber(selectedEpoch) + math.floor(d / 2)
      start_time = tonumber(selectedEpoch) - math.floor(d / 2)
   end

   return ts_utils.query(schema, tags, start_time, end_time, options)
end

-- ########################################################

function getProtoVolume(ifName, start_time, end_time)
   ifId = getInterfaceId(ifName)
   local series = ts_utils.listSeries("iface:ndpi", {ifid=ifId}, start_time)

   ret = { }
   for _, tags in ipairs(series or {}) do
      -- NOTE: this could be optimized via a dedicated driver call
      local data = ts_utils.query("iface:ndpi", tags, start_time, end_time)

      if(data ~= nil) and (data.statistics.total > 0) then
	 ret[tags.protocol] = data.statistics.total
      end
   end

   return(ret)
end

-- ########################################################

function breakdownBar(sent, sentLabel, rcvd, rcvdLabel, thresholdLow, thresholdHigh)
   if((sent+rcvd) > 0) then
    sent2rcvd = round((sent * 100) / (sent+rcvd), 0)
    -- io.write("****>> "..sent.."/"..rcvd.."/"..sent2rcvd.."\n")
    if((thresholdLow == nil) or (thresholdLow < 0)) then thresholdLow = 0 end
    if((thresholdHigh == nil) or (thresholdHigh > 100)) then thresholdHigh = 100 end

    if(sent2rcvd < thresholdLow) then sentLabel = '<i class="fa fa-warning fa-lg"></i> '..sentLabel
    elseif(sent2rcvd > thresholdHigh) then rcvdLabel = '<i class="fa fa-warning fa-lg""></i> '..rcvdLabel end

      print('<div class="progress"><div class="progress-bar progress-bar-warning" aria-valuenow="'.. sent2rcvd..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. sent2rcvd.. '%;">'..sentLabel)
      print('</div><div class="progress-bar progress-bar-info" aria-valuenow="'.. (100-sent2rcvd)..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. (100-sent2rcvd) .. '%;">' .. rcvdLabel .. '</div></div>')

   else
      print('&nbsp;')
   end
end

-- ########################################################

function percentageBar(total, value, valueLabel)
   -- io.write("****>> "..total.."/"..value.."\n")
   if((total ~= nil) and (total > 0)) then
      pctg = round((value * 100) / total, 0)
      print('<div class="progress"><div class="progress-bar progress-bar-warning" aria-valuenow="'.. pctg..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. pctg.. '%;">'..valueLabel)
      print('</div></div>')
   else
      print('&nbsp;')
   end
end

-- ########################################################

function makeProgressBar(percentage)
   -- nan check
   if percentage ~= percentage then
      return ""
   end

   local perc_int = round(percentage)
   return '<span style="width: 70%; float:left"><div class="progress"><div class="progress-bar progress-bar-warning" aria-valuenow="'..
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
--! @return html for the bar
function stackedProgressBars(total, bars, other_label, formatter, css_class)
   local res = {}
   local cumulative = 0
   local cumulative_perc = 0
   formatter = formatter or (function(x) return x end)

   -- The bars
   res[#res + 1] = [[<div class=' ]] .. (css_class or "ntop-progress-stacked") .. [['><div class="progress">]]

   for _, bar in ipairs(bars) do cumulative = cumulative + bar.value end
   if cumulative > total then total = cumulative end

   for _, bar in ipairs(bars) do
      local percentage = round(bar.value * 100 / total, 2)
      if cumulative_perc + percentage > 100 then percentage = 100 - cumulative_perc end
      cumulative_perc = cumulative_perc + percentage
      if bar.class == nil then bar.class = "primary" end
      if bar.style == nil then bar.style = "" end
      if bar.link ~= nil then res[#res + 1] = [[<a href="]] .. bar.link .. [[">]] end
      res[#res + 1] = [[
         <div class="progress-bar progress-bar-]] .. (bar.class) .. [[" role="progressbar" style="width:]] .. percentage .. [[%;]] .. bar.style .. [["></div></a>]]
      if bar.link ~= nil then res[#res + 1] = [[</a>]] end
   end

   res[#res + 1] = [[
      </div></div>]]

   -- The legend
   res[#res + 1] = [[<div class="stacked-progress-legend">]]

   local legend_items = bars

   if other_label ~= nil then
      legend_items = table.clone(bars)

      legend_items[#legend_items + 1] = {
         title = other_label,
         class = "empty",
         style = "",
         value = math.max(total - cumulative, 0),
      }
   end

   for _, bar in ipairs(legend_items) do
      res[#res + 1] = [[<span>]]
      if bar.link ~= nil then res[#res + 1] = [[<a href="]] .. bar.link .. [[">]] end
      res[#res + 1] = [[<span class="label label-]].. (bar.class) ..[[" style="]] .. bar.style .. [[">&nbsp;</span>]]
      if bar.link ~= nil then res[#res + 1] = [[</a>]] end
      res[#res + 1] = [[<span>]] .. bar.title .. " (".. formatter(bar.value) ..")</span></span>"
   end

   res[#res + 1] = [[<span style="margin-left: 0"><span></span><span>&nbsp;&nbsp;-&nbsp;&nbsp;]] .. i18n("total") .. ": ".. formatter(total) .."</span></span>"

   return table.concat(res)
end

-- ########################################################

-- label, relative_difference, seconds
zoom_vals = {
   { "1m",  "now-60s",  60},
   { "5m",  "now-300s", 60*5},
   { "30m", "now-1800s", 60*30},
   { "1h",  "now-1h",   60*60*1},
   --{ "3h",  "now-3h",   60*60*3},
   --{ "6h",  "now-6h",   60*60*6},
   --{ "12h", "now-12h",  60*60*12},
   { "1d",  "now-1d",   60*60*24},
   { "1w",  "now-1w",   60*60*24*7},
   --{ "2w",  "now-2w",   60*60*24*14},
   { "1M",  "now-1mon", 60*60*24*31},
   --{ "6M",  "now-6mon", 60*60*24*31*6},
   { "1Y",  "now-1y",   60*60*24*366}
}

function getZoomAtPos(cur_zoom, pos_offset)
  local pos = 1
  local new_zoom_level = cur_zoom
  for k,v in pairs(zoom_vals) do
    if(zoom_vals[k][1] == cur_zoom) then
      if (pos+pos_offset >= 1 and pos+pos_offset < table.len(zoom_vals)) then
	new_zoom_level = zoom_vals[pos+pos_offset][1]
	break
      end
    end
    pos = pos + 1
  end
  return new_zoom_level
end

-- ########################################################

function getZoomDuration(cur_zoom)
   for k,v in pairs(zoom_vals) do
      if(zoom_vals[k][1] == cur_zoom) then
	 return(zoom_vals[k][3])
      end
   end

   return(180)
end

-- ########################################################

local graph_menu_entries = {}

function populateGraphMenuEntry(label, base_url, params, tab_id, needs_separator, separator_label, pending, disabled)
   local url = getPageUrl(base_url, params)

   local entry_params = table.clone(params)
   for k, v in pairs(splitUrl(base_url).params) do
      entry_params[k] = v
   end

   local entry = {
      label = label,
      schema = params.ts_schema,
      params = entry_params, -- for graphMenuGetActive
      url = url,
      tab_id = tab_id,
      needs_separator = needs_separator,
      separator_label = separator_label,
      pending = pending, -- true for batched operations
      disabled = disabled,
   }

   graph_menu_entries[#graph_menu_entries + 1] = entry
   return entry
end

function makeMenuDivider()
   return '<li role="separator" class="divider"></li>'
end

function makeMenuHeader(label)
   return '<li class="dropdown-header">'.. label ..'</li>'
end

function graphMenuDivider()
   graph_menu_entries[#graph_menu_entries + 1] = {html=makeMenuDivider()}
end

function graphMenuHeader(label)
   graph_menu_entries[#graph_menu_entries + 1] = {html=makeMenuHeader(label)}
end

function graphMenuGetActive(schema, params)
   -- These tags are used to determine the active timeseries entry
   local match_tags = {ts_schema=1, ts_query=1, protocol=1, category=1, snmp_port_idx=1, exporter_ifname=1, l4proto=1}

   for _, entry in pairs(graph_menu_entries) do
      if entry.schema == schema and entry.params then
	 for k, v in pairs(params) do
	    if match_tags[k] and tostring(entry.params[k]) ~= tostring(v) then
	       goto continue
	    end
	 end

	 return entry
      end

      ::continue::
   end

   return nil
end

local function printEntry(idx, entry)
   local parts = {}

   parts[#parts + 1] = [[<li><a href="]] .. entry.url .. [[" ]]

   if not isEmptyString(entry.tab_id) then
      parts[#parts + 1] = [[id="]] .. entry.tab_id .. [[" ]]
   end

   parts[#parts + 1] = [[> ]] .. entry.label .. [[</a></li>]]

   print(table.concat(parts, ""))
end

-- Prints the menu from the populated graph_menu_entries.
-- The entry_print_callback is called to print the actual entries.
function printGraphMenuEntries(entry_print_callback)
   local active_entries = {}
   local active_idx = 1 -- index in active_entries

   for _, entry in ipairs(graph_menu_entries) do
      if(entry.pending and (entry.pending > 0)) then
         -- not verified, act like it does not exist
         goto continue
      end

      if(entry.needs_separator) then
         print(makeMenuDivider())
      end
      if(entry.separator_label) then
         print(makeMenuHeader(entry.separator_label))
      end

      if entry.html then
         print(entry.html)
      else
         entry_print_callback(active_idx, entry)
         active_entries[#active_entries + 1] = entry
         active_idx = active_idx + 1
      end

      ::continue::
   end

   -- NOTE: only return the graph_menu_entries which are non-pending
   return active_entries
end

-- ########################################################

function printSeries(options, tags, start_time, base_url, params)
   local series = options.timeseries
   local needs_separator = false
   local separator_label = nil
   local batch_id_to_entry = {}
   local device_timeseries_mac = options.device_timeseries_mac
   local mac_tags = nil
   local mac_params = nil
   local mac_baseurl = ntop.getHttpPrefix() .. "/lua/mac_details.lua?page=historical"

   if params.tskey then
      -- this can contain a MAC address for local broadcast domain hosts
      tags = table.clone(tags)
      tags.host = params.tskey
   end

   if(device_timeseries_mac ~= nil) then
      mac_tags = table.clone(tags)
      mac_tags.host = nil
      mac_tags.mac = device_timeseries_mac
      mac_params = table.clone(params)
      mac_params.host = device_timeseries_mac
   end

   for _, serie in ipairs(series) do
      if (have_nedge and serie.nedge_exclude) or (not have_nedge and serie.nedge_only) then
         goto continue
      end

      if serie.separator then
         needs_separator = true
         separator_label = serie.label
      else
         local k = serie.schema
         local v = serie.label
         local exists = false
         local entry_tags = tags
         local entry_params = params
         local entry_baseurl = base_url
         local override_link = nil

         -- Contains the list of batch_ids to be associated to this menu entry.
         -- The entry can only be shown when all the batch_ids have been confirmed
         -- in getBatchedListSeriesResult
         local batch_ids = {}

         if starts(k, "custom:") then
            if not ntop.isPro() then
               goto continue
            end

            -- exists by default, otherwise specify a serie.check below
            exists = true
         end

         if serie.check ~= nil then
            exists = true

            -- In the case of custom series, the serie can only be shown if all
            -- the component series exists
            for _, serie in pairs(serie.check) do
               local batch_id = ts_utils.batchListSeries(serie, tags, start_time)

               if batch_id == nil then
                  exists = false
                  break
               end

               batch_ids[#batch_ids +1] = batch_id
            end
         elseif not exists then
            if(mac_tags ~= nil) and (starts(k, "mac:")) then
               -- This is a mac timeseries shown under the host
               entry_tags = mac_tags
               entry_params = mac_params
               entry_baseurl = mac_baseurl
            end

            -- only show if there has been an update within the specified time frame
            local batch_id = ts_utils.batchListSeries(k, entry_tags, start_time)

            if batch_id ~= nil then
               -- assume it exists for now, will verify in getBatchedListSeriesResult
               exists = true
               batch_ids[#batch_ids +1] = batch_id
            end
         end

         if exists then
            local entry = populateGraphMenuEntry(v, entry_baseurl, table.merge(entry_params, {ts_schema=k}), nil,
               needs_separator, separator_label, #batch_ids --[[ pending ]], nil)

            if entry then
               for _, batch_id in pairs(batch_ids) do
                  batch_id_to_entry[batch_id] = entry
               end
            end

            needs_separator = false
            separator_label = nil
         end
      end

      ::continue::
   end

   -- nDPI applications
   if options.top_protocols then
      local schema = split(options.top_protocols, "top:")[2]
      local proto_tags = table.clone(tags)
      proto_tags.protocol = nil

      local series = ts_utils.listSeries(schema, proto_tags, start_time)

      if not table.empty(series) then
         graphMenuDivider()
         graphMenuHeader(i18n("applications"))

         local by_protocol = {}

         for _, serie in pairs(series) do
            by_protocol[serie.protocol] = 1
         end

         for protocol in pairsByKeys(by_protocol, asc) do
            local proto_id = protocol
            populateGraphMenuEntry(protocol, base_url, table.merge(params, {ts_schema=schema, protocol=proto_id}))
         end
      end
   end

   -- L4 protocols
   if options.l4_protocols then
      local schema = options.l4_protocols
      local l4_tags = table.clone(tags)
      l4_tags.l4proto = nil

      local series = ts_utils.listSeries(schema, l4_tags, start_time)

      if not table.empty(series) then
         graphMenuDivider()
         graphMenuHeader(i18n("protocols"))

         local by_protocol = {}

         for _, serie in pairs(series) do
            local sortkey = serie.l4proto

            if sortkey == "other_ip" then
               -- place at the end
               sortkey = "z" .. sortkey
            end

            by_protocol[sortkey] = serie.l4proto
         end

         for _, protocol in pairsByKeys(by_protocol, asc) do
            local proto_id = protocol
            local label

            if proto_id == "other_ip" then
               label = i18n("other")
            else
               label = string.upper(protocol)
            end

            populateGraphMenuEntry(label, base_url, table.merge(params, {ts_schema=schema, l4proto=proto_id}))
         end
      end
   end

   -- nDPI application categories
   if options.top_categories then
      local schema = split(options.top_categories, "top:")[2]
      local cat_tags = table.clone(tags)
      cat_tags.category = nil
      local series = ts_utils.listSeries(schema, cat_tags, start_time)

      if not table.empty(series) then
         graphMenuDivider()
         graphMenuHeader(i18n("categories"))

         local by_category = {}

         for _, serie in pairs(series) do
            by_category[serie.category] = 1
         end

         for category in pairsByKeys(by_category, asc) do
            populateGraphMenuEntry(category, base_url, table.merge(params, {ts_schema=schema, category=category}))
         end
      end
   end

   -- Perform the batched operations
   local result = ts_utils.getBatchedListSeriesResult()

   for batch_id, res in pairs(result) do
      local entry = batch_id_to_entry[batch_id]

      if entry and not table.empty(res) and entry.pending then
         -- entry exists, decrement the number of pending requests
         entry.pending = entry.pending - 1
      end
   end
end

-- ########################################################

function getMinZoomResolution(schema)
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

-- ########################################################

function printNotes(notes_items)
   print("<b>" .. i18n("notes").. "</b><ul>")

   for _, note in ipairs(notes_items) do
      print("<li>" ..note .. "</li>")
   end

   print("</ul>")
end

-- ########################################################

function drawGraphs(ifid, schema, tags, zoomLevel, baseurl, selectedEpoch, options)
   local debug_rrd = false
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

   if ntop.isPro() then
      _ifstats = interface.getStats()
      drawProGraph(ifid, schema, tags, zoomLevel, baseurl, options)
      return
   end

   nextZoomLevel = zoomLevel;
   epoch = tonumber(selectedEpoch);

   for k,v in ipairs(zoom_vals) do
      if zoom_vals[k][1] == min_zoom then
         min_zoom_k = k
      end

      if(zoom_vals[k][1] == zoomLevel) then
	 if(k > 1) then
	    nextZoomLevel = zoom_vals[math.max(k-1, min_zoom_k)][1]
	 end
	 if(epoch ~= nil) then
	    start_time = epoch - math.floor(zoom_vals[k][3] / 2)
	    end_time = epoch + math.floor(zoom_vals[k][3] / 2)
	 else
	    end_time = os.time()
	    start_time = end_time - zoom_vals[k][3]
	 end
      end
   end

   if options.tskey then
      -- this can contain a MAC address for local broadcast domain hosts
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

<div class="container-fluid">
  <ul class="nav nav-tabs" role="tablist" id="historical-tabs-container">
    <li class="active"> <a href="#historical-tab-chart" role="tab" data-toggle="tab"> Chart </a> </li>
]]

local show_historical_tabs = ntop.getPrefs().is_dump_flows_to_mysql_enabled and options.show_historical

if show_historical_tabs then
   print('<li><a href="#historical-flows" role="tab" data-toggle="tab" id="tab-flows-summary"> Flows </a> </li>\n')
end

print[[
</ul>


  <div class="tab-content">
    <div class="tab-pane fade active in" id="historical-tab-chart">

<br>
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
<div class="btn-group">
  <button class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">Timeseries <span class="caret"></span></button>
  <ul class="dropdown-menu">
]]

   printSeries(options, tags, start_time, baseurl, page_params)
   printGraphMenuEntries(printEntry)

   print [[
  </ul>
</div><!-- /btn-group -->
]]
end -- options.timeseries

print('&nbsp;Timeframe:  <div class="btn-group" data-toggle="buttons" id="graph_zoom">\n')

for k,v in ipairs(zoom_vals) do
   -- display 1 minute button only for networks and interface stats
   -- but exclude applications. Application statistics are gathered
   -- every 5 minutes
   if zoom_vals[k][1] == '1m' and min_zoom ~= '1m' then
      goto continue
   elseif zoom_vals[k][1] == '5m' and min_zoom ~= '1m' and min_zoom ~= '5m' then
      goto continue
   end
   print('<label class="btn btn-link ')

   if(zoom_vals[k][1] == zoomLevel) then
      print("active")
   end
   print('">')

   local params = table.merge(page_params, {zoom=zoom_vals[k][1]})

   -- Additional parameters
   if tags.protocol ~= nil then
      params["protocol"] = tags.protocol
   end
   if tags.category ~= nil then
      params["category"] = tags.category
   end

   local url = getPageUrl(baseurl, params)
   
   print('<input type="radio" name="options" id="zoom_level_'..k..'" value="'..url..'">'.. zoom_vals[k][1] ..'</input></label>\n')
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

<br />
<p>


<div id="legend"></div>
<div id="chart_legend"></div>
<div id="chart" style="margin-right: 50px; margin-left: 10px; display: table-cell"></div>
<p><font color=lightgray><small>NOTE: Click on the graph to zoom.</small></font>

</td>


<td rowspan=2>
<div id="y_axis"></div>

<div style="margin-left: 10px; display: table">
<div id="chart_container" style="display: table-row">

]]

local format_as_bps = true
local formatter_fctn
local label = data.series[1].label

if string.contains(label, "packets") or string.contains(label, "flows") or label:starts("num_") then
   format_as_bps = false
   formatter_fctn = "fint"
else
   formatter_fctn = "fbits"
end

print [[
   <table class="table table-bordered table-striped" style="border: 0; margin-right: 10px; display: table-cell">
   ]]

print('   <tr><th>&nbsp;</th><th>Time</th><th>Value</th></tr>\n')

local stats = data.statistics
local minval_time = stats.min_val_idx and (data.start + data.step * stats.min_val_idx) or ""
local maxval_time = stats.max_val_idx and (data.start + data.step * stats.max_val_idx) or ""
local lastval_time = data.start + data.step * (data.count-1)
local lastval = 0

for _, serie in pairs(data.series) do
   lastval = lastval + serie.data[data.count]
end
if(not format_as_bps) then
   print('   <tr><th>Min</th><td>' .. os.date("%x %X", minval_time) .. '</td><td>' .. formatValue(stats.min_val or "") .. '</td></tr>\n')
   print('   <tr><th>Max</th><td>' .. os.date("%x %X", maxval_time) .. '</td><td>' .. formatValue(stats.max_val or "") .. '</td></tr>\n')
   print('   <tr><th>Last</th><td>' .. os.date("%x %X", lastval_time) .. '</td><td>' .. formatValue(round(lastval), 1) .. '</td></tr>\n')
   print('   <tr><th>Average</th><td colspan=2>' .. formatValue(round(stats.average, 2)) .. '</td></tr>\n')
   print('   <tr><th>95th <A HREF=https://en.wikipedia.org/wiki/Percentile>Percentile</A></th><td colspan=2>' .. formatValue(round(stats["95th_percentile"], 2)) .. '</td></tr>\n')
   print('   <tr><th>Total Number</th><td colspan=2>' ..  formatValue(round(stats.total)) .. '</td></tr>\n')
else
   print('   <tr><th>Min</th><td>' .. os.date("%x %X", minval_time) .. '</td><td>' .. bitsToSize((stats.min_val*8) or "") .. '</td></tr>\n')
   print('   <tr><th>Max</th><td>' .. os.date("%x %X", maxval_time) .. '</td><td>' .. bitsToSize((stats.max_val*8) or "") .. '</td></tr>\n')
   print('   <tr><th>Last</th><td>' .. os.date("%x %X", lastval_time) .. '</td><td>' .. bitsToSize(lastval*8)  .. '</td></tr>\n')
   print('   <tr><th>Average</th><td colspan=2>' .. bitsToSize(stats.average*8) .. '</td></tr>\n')
   print('   <tr><th>95th <A HREF=https://en.wikipedia.org/wiki/Percentile>Percentile</A></th><td colspan=2>' .. bitsToSize(stats["95th_percentile"]*8) .. '</td></tr>\n')
   print('   <tr><th>Total Traffic</th><td colspan=2>' .. bytesToSize(stats.total) .. '</td></tr>\n')
end

print('   <tr><th>Selection Time</th><td colspan=2><div id=when></div></td></tr>\n')
print('   <tr><th>Minute<br>Interface<br>Top Talkers</th><td colspan=2><div id=talkers></div></td></tr>\n')


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

   print('<div class="tab-pane fade" id="historical-flows">')
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
</div> <!-- closes div class "container-fluid" -->

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
   print("\n, color: '".. graph_colors[serie_idx] .."', data: [")

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


function fdate(when) {
      var epoch = when*1000;
      var d = new Date(epoch);

      return(d);
}

var Hover = Rickshaw.Class.create(Rickshaw.Graph.HoverDetail, {
    graph: graph,
    xFormatter: function(x) { return new Date( x * 1000 ); },
    yFormatter: function(bits) { return(]] print(formatter_fctn) print [[(bits)); },
    render: function(args) {
		var graph = this.graph;
		var points = args.points;
		var point = points.filter( function(p) { return p.active } ).shift();

		if(point.value.y === null) return;

		var formattedXValue = fdate(point.value.x); // point.formattedXValue;
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
		       infoHTML += "<li>"+capitaliseFirstLetter(i)+" [Avg Traffic/sec]<ol>";
		     var items = 0;
		     var other_traffic = 0;
		     $.each(n, function(j, m) {
		       if((items < 3) && (m.address != "Other")) {
			 infoHTML += "<li><a href='host_details.lua?host="+m.address+"'>"+abbreviateString(m.label ? m.label : m.address,24);
		       infoHTML += "</a>";
		       if (m.vlan != "0") infoHTML += " ("+m.vlanm+")";
		       infoHTML += " ("+fbits((m.value*8)/60)+")</li>";
			 items++;
		       } else
			 other_traffic += m.value;
		     });
		     if (other_traffic > 0)
			 infoHTML += "<li>Other ("+fbits((other_traffic*8)/60)+")</li>";
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
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No data found</div>")
end -- if(data)
end

function printGraphTopFlows(ifId, host, epoch, zoomLevel, l7proto, vlan)
   -- Check if the DB is enabled
   rsp = interface.execSQLQuery("show tables")
   if(rsp == nil) then return end

   if((epoch == nil) or (epoch == "")) then epoch = os.time() end

   local d = getZoomDuration(zoomLevel)

   epoch_end = epoch
   epoch_begin = epoch-d

   historicalFlowsTab(ifId, host, epoch_begin, epoch_end, l7proto, '', '', '', vlan)
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
function printProtocolQuota(proto, ndpi_stats, category_stats, quotas_to_show, show_td, hide_limit)
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
        output[#output + 1] = [[<td class='text-right']]..ternary(bytes_exceeded, ' style=\'color:red;\'', '').."><span>"..lb_bytes..ternary(hide_limit, "", " / "..lb_bytes_quota).."</span>"
      end

      output[#output + 1] = [[
          <div class='progress' style=']]..(quotas_to_show.traffic_style or "")..[['>
            <div class='progress-bar progress-bar-warning' aria-valuenow=']]..traffic_quota_ratio..'\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: '..traffic_quota_ratio..'%;\'>'..
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
        output[#output + 1] = [[<td class='text-right']]..ternary(time_exceeded, ' style=\'color:red;\'', '').."><span>"..lb_duration..ternary(hide_limit, "", " / "..lb_duration_quota).."</span>"
      end

      output[#output + 1] = ([[
          <div class='progress' style=']]..(quotas_to_show.time_style or "")..[['>
            <div class='progress-bar progress-bar-warning' aria-valuenow=']]..duration_quota_ratio..'\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: '..duration_quota_ratio..'%;\'>'..
              ternary(duration_quota_ratio == duration_quota_ratio --[[nan check]], duration_quota_ratio, 0)..[[%
            </div>
          </div>]])
      if show_td then output[#output + 1] = ("</td>") end
    end

    return table.concat(output, '')
end

-- #################################################

function poolDropdown(ifId, pool_id, exclude)
   local output = {}
   exclude = exclude or {}

   for _,pool in ipairs(host_pools_utils.getPoolsList(ifId)) do
      if (not exclude[pool.id]) or (pool.id == pool_id) then
         output[#output + 1] = '<option value="' .. pool.id .. '"'

         if pool.id == pool_id then
            output[#output + 1] = ' selected'
         end

         local limit_reached = false

         if not ntop.isEnterprise() then
            local n_members = table.len(host_pools_utils.getPoolMembers(ifId, pool.id) or {})

            if n_members >= host_pools_utils.LIMITED_NUMBER_POOL_MEMBERS then
               limit_reached = true
            end
         end

         if exclude[pool.id] or limit_reached then
            output[#output + 1] = ' disabled'
         end

         output[#output + 1] = '>' .. pool.name .. ternary(limit_reached, " ("..i18n("host_pools.members_limit_reached")..")", "") .. '</option>'
      end
   end

   return table.concat(output, '')
end

-- #################################################

function printPoolChangeDropdown(ifId, pool_id, have_nedge)
   local output = {}

   output[#output + 1] = [[<tr>
      <th>]] .. i18n(ternary(have_nedge, "nedge.user", "host_config.host_pool")) .. [[</th>
      <td>
            <select name="pool" class="form-control" style="width:20em; display:inline;">]]

   output[#output + 1] = poolDropdown(ifId, pool_id)

   local edit_pools_link = ternary(have_nedge, "/lua/pro/nedge/admin/nf_list_users.lua", "/lua/if_stats.lua?page=pools#create")

   output[#output + 1] = [[
            </select>&nbsp;
        <A HREF="]] .. ntop.getHttpPrefix() .. edit_pools_link .. [["><i class="fa fa-sm fa-cog" aria-hidden="true" title="]]
      ..i18n(ternary(have_nedge, "nedge.edit_users", "host_pools.edit_host_pools"))
      .. [["></i> ]]
      .. i18n(ternary(have_nedge, "nedge.edit_users", "host_pools.edit_host_pools"))
      .. [[</A>
   </tr>]]

   print(table.concat(output, ''))
end

-- #################################################

function printCategoryDropdownButton(by_id, cat_id_or_name, base_url, page_params, count_callback, skip_unknown)
   local function count_all(cat_id, cat_name)
      local cat_protos = interface.getnDPIProtocols(tonumber(cat_id))
      return table.len(cat_protos)
   end

   cat_id_or_name = cat_id_or_name or ""
   count_callback = count_callback or count_all

   -- 'Category' button
   print('\'<div class="btn-group pull-right"><div class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..
         i18n("category") .. ternary(not isEmptyString(cat_id_or_name), '<span class="glyphicon glyphicon-filter"></span>', '') ..
         '<span class="caret"></span></div> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

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

         print('<li' .. ternary(cat_id_or_name == ternary(by_id, entry.cat_id, entry.id), ' class="active"', '') ..
            '><a href="' .. getPageUrl(base_url, page_params) .. '">' .. (entry.icon or "") ..
            entry.text .. '</a></li>')
      else
         print(makeMenuDivider())
      end
   end

   print('</ul></div>\', ')
   page_params["category"] = cat_id_or_name
end

-- #################################################

function getDeviceCommonTimeseries()
   return {
      {schema="mac:arp_rqst_sent_rcvd_rpls", label=i18n("graphs.arp_rqst_sent_rcvd_rpls")},
   }
end

-- #################################################
