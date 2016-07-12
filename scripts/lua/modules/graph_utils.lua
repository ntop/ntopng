--
-- (C) 2013-16 - ntop.org
--
require "lua_utils"
require "db_utils"
require "historical_utils"

top_rrds = {
   ["bytes.rrd"] = "Traffic",
   ["packets.rrd"] = "Packets",
   ["drops.rrd"] = "Packet Drops",
   ["num_flows.rrd"] = "Active Flows",
   ["num_hosts.rrd"] = "Active Hosts",
   ["num_http_hosts.rrd"] = "Active HTTP Servers",
   ["tcp_lost.rrd"] = "TCP Packets Lost",
   ["tcp_ooo.rrd"] = "TCP Packets Out-Of-Order",
   ["tcp_retransmissions.rrd"] = "TCP Retransmitted Packets",
}

-- ########################################################

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "nv_graph_utils"
end

-- ########################################################

function getProtoVolume(ifName, start_time, end_time)
   ifId = getInterfaceId(ifName)
   path = fixPath(dirs.workingdir .. "/" .. ifId .. "/rrd/")
   rrds = ntop.readdir(path)

   ret = { }
   for rrdFile,v in pairs(rrds) do
      if((string.ends(rrdFile, ".rrd")) and (top_rrds[rrdFile] == nil)) then
	 rrdname = getRRDName(ifId, nil, rrdFile)
	 if(ntop.notEmptyFile(rrdname)) then
	    local fstart, fstep, fnames, fdata = ntop.rrd_fetch(rrdname, 'AVERAGE', start_time, end_time)

	    if(fstart ~= nil) then
	       local num_points_found = table.getn(fdata)

	       accumulated = 0
	       for i, v in ipairs(fdata) do
		  for _, w in ipairs(v) do
		     if(w ~= w) then
			-- This is a NaN
			v = 0
		     else
			--io.write(w.."\n")
			v = tonumber(w)
			if(v < 0) then
			   v = 0
			end
		     end
		  end

		  accumulated = accumulated + v
	       end

	       if(accumulated > 0) then
		  rrdFile = string.sub(rrdFile, 1, string.len(rrdFile)-4)
		  ret[rrdFile] = accumulated
	       end
	    end
	 end
      end
   end

   return(ret)
end

-- ########################################################

function navigatedir(url, label, base, path, go_deep, print_html, ifid, host, start_time, end_time)
   local shown = false
   local to_skip = false
   local ret = { }
   local do_debug = false
   local printed = false

   -- io.write(debug.traceback().."\n")

   rrds = ntop.readdir(path)
   table.sort(rrds)

   for k,v in pairsByKeys(rrds, asc) do
      if(v ~= nil) then
	 p = fixPath(path .. "/" .. v)

	 if(ntop.isdir(p)) then
	    if(go_deep) then
	       r = navigatedir(url, label.."/"..v, base, p, print_html, ifid, host, start_time, end_time)
	       for k,v in pairs(r) do
		  ret[k] = v
		  if(do_debug) then print(v.."<br>\n") end
	       end
	    end
	else
	    rrd = singlerrd2json(ifid, host, v, start_time, end_time, true, false)

	    if((rrd.totalval ~= nil) and (rrd.totalval > 0)) then
	       if(top_rrds[v] == nil) then
		  if(label == "*") then
		     to_skip = true
		  else
		     if(not(shown) and not(to_skip)) then
			if(print_html) then
			   if(not(printed)) then print('<li class="divider"></li>\n') printed = true end
			   print('<li class="dropdown-submenu"><a tabindex="-1" href="#">'..label..'</a>\n<ul class="dropdown-menu">\n')
			end
			shown = true
		     end
		  end

		  what = string.sub(path.."/"..v, string.len(base)+2)

		  label = string.sub(v,  1, string.len(v)-4)
		  label = l4Label(string.gsub(label, "_", " "))

		  ret[label] = what
		  if(do_debug) then print(what.."<br>\n") end

		  if(print_html) then
		     if(not(printed)) then print('<li class="divider"></li>\n') printed = true end
		     print("<li> <A HREF="..url..what..">"..label.."</A>  </li>\n")
		  end
	       end
	    end
	 end
      end
   end

   if(shown) then
      if(print_html) then print('</ul></li>\n') end
   end

   return(ret)
end

-- ########################################################

function breakdownBar(sent, sentLabel, rcvd, rcvdLabel, thresholdLow, thresholdHigh)
   if((sent+rcvd) > 0) then
      sent2rcvd = round((sent * 100) / (sent+rcvd), 0)
       --print(sent.."/"..rcvd.."/"..sent2rcvd)
    if((thresholdLow == nil) or (thresholdLow < 0)) then thresholdLow = 0 end
    if((thresholdHigh == nil) or (thresholdHigh > 100)) then thresholdHigh = 100 end

    if(sent2rcvd < thresholdLow) then sentLabel = '<i class="fa fa-warning fa-lg"></i> '..sentLabel
    elseif(sent2rcvd > thresholdHigh) then rcvdLabel = '<i class="fa fa-warning fa-lg""></i> '..rcvdLabel end

      print('<div class="progress"><div class="progress-bar progress-bar-warning" aria-valuenow="'.. sent2rcvd..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. sent2rcvd.. '%;">'..sentLabel)
      print('</div><div class="progress-bar progress-bar-info" aria-valuenow="'.. (100 -sent2rcvd)..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. (100-sent2rcvd) .. '%;">' .. rcvdLabel .. '</div></div>')

   else
      print('&nbsp;')
   end
end

-- ########################################################

function percentageBar(total, value, valueLabel)
   if((total ~= nil) and (total > 0)) then
      pctg = round((value * 100) / total, 0)
      print('<div class="progress"><div class="progress-bar progress-bar-warning" aria-valuenow="'.. pctg..'" aria-valuemin="0" aria-valuemax="100" style="width: ' .. pctg.. '%;">'..valueLabel)
      print('</div></div>')
   else
      print('&nbsp;')
   end
end

-- ########################################################
-- host_or_network: host or network name.
-- If network, must be prefixed with 'net:'
-- If profile, must be prefixed with 'profile:'
function getRRDName(ifid, host_or_network, rrdFile)
   if host_or_network ~= nil and string.starts(host_or_network, 'net:') then
       host_or_network = string.gsub(host_or_network, 'net:', '')
       rrdname = fixPath(dirs.workingdir .. "/" .. ifid .. "/subnetstats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'profile:') then
       host_or_network = string.gsub(host_or_network, 'profile:', '')
       rrdname = fixPath(dirs.workingdir .. "/" .. ifid .. "/profilestats/")
   elseif host_or_network ~= nil and string.starts(host_or_network, 'vlan:') then

      host_or_network = string.gsub(host_or_network, 'vlan:', '')
       rrdname = fixPath(dirs.workingdir .. "/" .. ifid .. "/vlanstats/")
   else
       rrdname = fixPath(dirs.workingdir .. "/" .. ifid .. "/rrd/")
   end

   if(host_or_network ~= nil) then
      rrdname = rrdname .. getPathFromKey(host_or_network) .. "/"
   end

   return(rrdname..rrdFile)
end

-- ########################################################

zoom_vals = {
   { "1m",  "now-60s",  60 },
   { "5m",  "now-300s", 60*5 },
   { "10m", "now-600s", 60*10 },
   { "1h",  "now-1h",   60*60*1 },
   { "3h",  "now-3h",   60*60*3 },
   { "6h",  "now-6h",   60*60*6 },
   { "12h", "now-12h",  60*60*12 },
   { "1d",  "now-1d",   60*60*24 },
   { "1w",  "now-1w",   60*60*24*7 },
   { "2w",  "now-2w",   60*60*24*14 },
   { "1M",  "now-1mon", 60*60*24*31 },
   { "6M",  "now-6mon", 60*60*24*31*6 },
   { "1Y",  "now-1y",   60*60*24*366 }
}

function getZoomAtPos(cur_zoom, pos_offset)
  local pos = 1
  local new_zoom_level = cur_zoom
  for k,v in pairs(zoom_vals) do
    if(zoom_vals[k][1] == cur_zoom) then
      if (pos+pos_offset >= 1 and pos+pos_offset < 13) then
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

function zoomLevel2sec(zoomLevel)
   if(zoomLevel == nil) then zoomLevel = "1h" end

   for k,v in ipairs(zoom_vals) do
      if(zoom_vals[k][1] == zoomLevel) then
	 return(zoom_vals[k][3])
      end
   end

   return(3600) -- NOT REACHED
end


-- ########################################################

function drawPeity(ifid, host, rrdFile, zoomLevel, selectedEpoch)
   rrdname = getRRDName(ifid, host, rrdFile)

   if(zoomLevel == nil) then
      zoomLevel = "1h"
   end

   nextZoomLevel = zoomLevel;
   epoch = tonumber(selectedEpoch);

   for k,v in ipairs(zoom_vals) do
      if(zoom_vals[k][1] == zoomLevel) then
	 if(k > 1) then
	    nextZoomLevel = zoom_vals[k-1][1]
	 end
	 if(epoch) then
	    start_time = epoch - zoom_vals[k][3]/2
	    end_time = epoch + zoom_vals[k][3]/2
	 else
	    start_time = zoom_vals[k][2]
	    end_time = "now"
	 end
      end
   end

   --print("=> Found "..rrdname.."<p>\n")
   if(ntop.notEmptyFile(rrdname)) then
      --io.write("=> Found ".. start_time .. "|" .. end_time .. "<p>\n")
      local fstart, fstep, fnames, fdata = ntop.rrd_fetch(rrdname, 'AVERAGE', start_time..", end_time..")

      if(fstart ~= nil) then
	 local max_num_points = 512 -- This is to avoid having too many points and thus a fat graph
	 local num_points_found = table.getn(fdata)
	 local sample_rate = round(num_points_found / max_num_points)
	 local num_points = 0
	 local step = 1
	 local series = {}

	 if(sample_rate < 1) then
	    sample_rate = 1
	 end

	 -- print("=> "..num_points_found.."[".. sample_rate .."]["..fstart.."]<p>")

	 id = 0
	 num = 0
	 total = 0
	 sample_rate = sample_rate-1
	 points = {}
	 for i, v in ipairs(fdata) do
	    timestamp = fstart + (i-1)*fstep
	    num_points = num_points + 1

	    local elemId = 1
	    for _, w in ipairs(v) do
	       if(w ~= w) then
		  -- This is a NaN
		  v = 0
	       else
		  v = tonumber(w)
		  if(v < 0) then
		     v = 0
		  end
	       end

	       value = v*8 -- bps

	       total = total + value
	       if(id == sample_rate) then
		  points[num] = round(value)..""
		  num = num+1
		  id = 0
	       else
		  id = id + 1
	       end
	       elemId = elemId + 1
	    end
	 end
      end
   end

   print("<td class=\"text-right\">"..round(total).."</td><td> <span class=\"peity-line\">")
   for i=0,10 do
      if(i > 0) then print(",") end
      print(points[i])
   end
   print("</span>\n")
end

-- ########################################################

function drawRRD(ifid, host, rrdFile, zoomLevel, baseurl, show_timeseries,
		 selectedEpoch, selected_epoch_sanitized, topArray)
   local debug_rrd = false

   if(zoomLevel == nil) then zoomLevel = "1h" end

   if((selectedEpoch == nil) or (selectedEpoch == "")) then
      -- Refresh the page every minute unless:
      -- ** a specific epoch has been selected or
      -- ** the user is browsing historical top talkers and protocols
      print[[
       <script>
       setInterval(function() {
	 var talkers_loaded, protocols_loaded;
	 if($('a[href="#historical-top-talkers"]').length){
	   talkers_loaded   = $('a[href="#historical-top-talkers"]').attr("loaded");
	 }
	 if($('a[href="#historical-top-apps"]').length){
	   protocols_loaded = $('a[href="#historical-top-apps"]').attr("loaded");
	 }
	 if(typeof talkers_loaded == 'undefined' && typeof protocols_loaded == 'undefined'){
	   window.location.reload();
	 }
       }, 60*1000);
       </script>]]
   end

   if ntop.isPro() then
      _ifstats = interface.getStats()
      if(_ifstats.isView == true) then topArray = nil end
      drawProGraph(ifid, host, rrdFile, zoomLevel, baseurl, show_timeseries, selectedEpoch, selected_epoch_sanitized, topArray)
      return
   end

   dirs = ntop.getDirs()
   rrdname = getRRDName(ifid, host, rrdFile)
   names =  {}
   series = {}

   if(zoomLevel == nil) then
      zoomLevel = "1h"
   end

   nextZoomLevel = zoomLevel;
   epoch = tonumber(selectedEpoch);

   for k,v in ipairs(zoom_vals) do
      if(zoom_vals[k][1] == zoomLevel) then
	 if(k > 1) then
	    nextZoomLevel = zoom_vals[k-1][1]
	 end
	 if(epoch) then
	    start_time = epoch - zoom_vals[k][3]/2
	    end_time = epoch + zoom_vals[k][3]/2
	 else
	    start_time = zoom_vals[k][2]
	    end_time = "now"
	 end
      end
   end

   prefixLabel = l4Label(string.gsub(rrdFile, ".rrd", ""))

   -- io.write(prefixLabel.."\n")
   if(prefixLabel == "Bytes") then
      prefixLabel = "Traffic"
   end

   if(ntop.notEmptyFile(rrdname)) then

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

if ntop.getPrefs().is_dump_flows_to_mysql_enabled
   -- hide historical tabs for networks
   and not string.starts(host, 'net:')
then
   print('<li><a href="#ipv4" role="tab" data-toggle="tab" id="tab-ipv4"> IPv4 Flows </a> </li>\n')
  print('<li><a href="#ipv6" role="tab" data-toggle="tab" id="tab-ipv6"> IPv6 Flows </a> </li>\n')
end

print[[
</ul>


  <div class="tab-content">
    <div class="tab-pane fade active in" id="historical-tab-chart">

<br>
<table border=0>
<tr><td valign="top">
]]


if(show_timeseries == 1) then
   print [[
<div class="btn-group">
  <button class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">Timeseries <span class="caret"></span></button>
  <ul class="dropdown-menu">
]]

for k,v in pairs(top_rrds) do
   rrdname = getRRDName(ifid, host, k)
   if(ntop.notEmptyFile(rrdname)) then
      rrd = singlerrd2json(ifid, host, k, start_time, end_time, true, false)
      if((rrd.totalval ~= nil) and (rrd.totalval > 0)) then
	 print('<li><a  href="'..baseurl .. '&rrd_file=' .. k .. '&graph_zoom=' .. zoomLevel .. '&epoch=' .. (selectedEpoch or '') .. '">'.. v ..'</a></li>\n')
      end
   end
end

dirs = ntop.getDirs()
p = dirs.workingdir .. "/" .. purifyInterfaceName(ifid) .. "/rrd/"
if(host ~= nil) then
   p = p .. getPathFromKey(host)
end
d = fixPath(p)

   go_deep = false
   navigatedir(baseurl .. '&graph_zoom=' .. zoomLevel .. '&epoch=' .. (selectedEpoch or '')..'&rrd_file=',
	       "*", d, d, go_deep, true, ifid, host, start_time, end_time)

   print [[
  </ul>
</div><!-- /btn-group -->
]]
end -- show_timeseries == 1

print('&nbsp;Timeframe:  <div class="btn-group" data-toggle="buttons" id="graph_zoom">\n')

for k,v in ipairs(zoom_vals) do
   -- display 1 minute button only for networks and interface stats
   -- but exclude applications. Application statistics are gathered
   -- every 5 minutes
   local net_or_profile = false

   if host and (string.starts(host, 'net:') or string.starts(host, 'profile:')) then
       net_or_profile = true
   end
   if zoom_vals[k][1] == '1m' and (net_or_profile or (not net_or_profile and not top_rrds[rrdFile])) then
       goto continue
   end
   print('<label class="btn btn-link ')

   if(zoom_vals[k][1] == zoomLevel) then
      print("active")
   end
   print('">')
   print('<input type="radio" name="options" id="zoom_level_'..k..'" value="'..baseurl .. '&rrd_file=' .. rrdFile .. '&graph_zoom=' .. zoom_vals[k][1] .. '">'.. zoom_vals[k][1] ..'</input></label>\n')
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

if(string.contains(rrdFile, "num_")) then
   formatter_fctn = "fint"
else
   formatter_fctn = "fpackets"
end

if (topArray ~= nil) then
print [[
   <table class="table table-bordered table-striped" style="border: 0; margin-right: 10px; display: table-cell">
   ]]

print('   <tr><th>&nbsp;</th><th>Time</th><th>Value</th></tr>\n')

rrd = rrd2json(ifid, host, rrdFile, start_time, end_time, true, false) -- the latest false means: expand_interface_views

if(string.contains(rrdFile, "num_") or string.contains(rrdFile, "tcp_") or string.contains(rrdFile, "packets")  or string.contains(rrdFile, "drops")) then
   print('   <tr><th>Min</th><td>' .. os.date("%x %X", rrd.minval_time) .. '</td><td>' .. formatValue(rrd.minval) .. '</td></tr>\n')
   print('   <tr><th>Max</th><td>' .. os.date("%x %X", rrd.maxval_time) .. '</td><td>' .. formatValue(rrd.maxval) .. '</td></tr>\n')
   print('   <tr><th>Last</th><td>' .. os.date("%x %X", rrd.lastval_time) .. '</td><td>' .. formatValue(round(rrd.lastval), 1) .. '</td></tr>\n')
   print('   <tr><th>Average</th><td colspan=2>' .. formatValue(round(rrd.average, 2)) .. '</td></tr>\n')
   print('   <tr><th>Total Number</th><td colspan=2>' ..  formatValue(round(rrd.totalval)) .. '</td></tr>\n')
else
   formatter_fctn = "fbits"
   print('   <tr><th>Min</th><td>' .. os.date("%x %X", rrd.minval_time) .. '</td><td>' .. bitsToSize(rrd.minval) .. '</td></tr>\n')
   print('   <tr><th>Max</th><td>' .. os.date("%x %X", rrd.maxval_time) .. '</td><td>' .. bitsToSize(rrd.maxval) .. '</td></tr>\n')
   print('   <tr><th>Last</th><td>' .. os.date("%x %X", rrd.lastval_time) .. '</td><td>' .. bitsToSize(rrd.lastval)  .. '</td></tr>\n')
   print('   <tr><th>Average</th><td colspan=2>' .. bitsToSize(rrd.average*8) .. '</td></tr>\n')
   print('   <tr><th>Total Traffic</th><td colspan=2>' .. bytesToSize(rrd.totalval) .. '</td></tr>\n')
end

print('   <tr><th>Selection Time</th><td colspan=2><div id=when></div></td></tr>\n')
print('   <tr><th>Minute<br>Interface<br>Top Talkers</th><td colspan=2><div id=talkers></div></td></tr>\n')


print [[
   </table>
]]
end -- topArray ~= nil

print[[</div></td></tr></table>

    </div> <!-- closes div id "historical-tab-chart "-->
]]

if ntop.getPrefs().is_dump_flows_to_mysql_enabled
   -- hide historical tabs for networks and profiles
   and not string.starts(host, 'net:')
then
  if tonumber(start_time) ~= nil and tonumber(end_time) ~= nil then
    -- if both start_time and end_time are vaid epoch we can print finer-grained top flows
    printTopFlows(ifid, (host or ''), start_time, end_time, rrdFile, '', '', '', 5, 5)
  else
    printGraphTopFlows(ifid, (host or ''), _GET["epoch"], zoomLevel, rrdFile)
  end
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
				   series:
				]]

print(rrd.json)

print [[
				} );

graph.render();

var chart_legend = document.querySelector('#chart_legend');


function fdate(when) {
      var epoch = when*1000;
      var d = new Date(epoch);

      return(d);
}

function fbits(bits) {
	var sizes = ['bps', 'Kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'];
	if(bits == 0) return 'n/a';
	var i = parseInt(Math.floor(Math.log(bits) / Math.log(1000)));
	return Math.round(bits / Math.pow(1000, i), 2) + ' ' + sizes[i];
}

function capitaliseFirstLetter(string)
{
   return string.charAt(0).toUpperCase() + string.slice(1);
}

/**
 * Convert number of bytes into human readable format
 *
 * @param integer bytes     Number of bytes to convert
 * @param integer precision Number of digits after the decimal separator
 * @return string
 */
   function formatBytes(bytes, precision)
      {
	 var kilobyte = 1024;
	 var megabyte = kilobyte * 1024;
	 var gigabyte = megabyte * 1024;
	 var terabyte = gigabyte * 1024;

	 if((bytes >= 0) && (bytes < kilobyte)) {
	    return bytes + ' B';
	 } else if((bytes >= kilobyte) && (bytes < megabyte)) {
	    return (bytes / kilobyte).toFixed(precision) + ' KB';
	 } else if((bytes >= megabyte) && (bytes < gigabyte)) {
	    return (bytes / megabyte).toFixed(precision) + ' MB';
	 } else if((bytes >= gigabyte) && (bytes < terabyte)) {
	    return (bytes / gigabyte).toFixed(precision) + ' GB';
	 } else if(bytes >= terabyte) {
	    return (bytes / terabyte).toFixed(precision) + ' TB';
	 } else {
	    return bytes + ' B';
	 }
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

if(topArray ~= nil and topArray["top_talkers"] ~= nil) then
print[[

infoHTML += "<ul>";
$.ajax({
	  type: 'GET',
	  url: ']]
	  print(ntop.getHttpPrefix().."/lua/top_generic.lua?m=top_talkers&epoch='+point.value.x+'&addvlan=true&id="..tostring(ifid))
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
		       if(items < 3) {
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
end -- topArray
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

$("#chart").click(function() {
  if(hover.selected_epoch)
    window.location.href = ']]
print(baseurl .. '&rrd_file=' .. rrdFile .. '&graph_zoom=' .. nextZoomLevel .. '&epoch=')
print[['+hover.selected_epoch;
});

</script>

]]
else
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> File "..rrdname.." cannot be found</div>")
end
end

-- ########################################################

function create_rrd(name, step, ds)
   if(not(ntop.exists(name))) then
      if(enable_second_debug == 1) then io.write('Creating RRD ', name, '\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 name,
	 step,   -- step
	 'DS:' .. ds .. ':DERIVE:5:U:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.intf_rrd_raw_days*24*60*60),   -- raw: 1 day = 86400
	 'RRA:AVERAGE:0.5:60:'..tostring(prefs.intf_rrd_1min_days*24*60),   -- 1 min resolution = 1 month
	 'RRA:AVERAGE:0.5:3600:'..tostring(prefs.intf_rrd_1h_days*24), -- 1h resolution (3600 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:86400:'..tostring(prefs.intf_rrd_1d_days) -- 1d resolution (86400 points)  365 days
	 -- 'RRA:HWPREDICT:1440:0.1:0.0035:20'
      )
   end
end

function create_rrd_num(name, ds)
   if(not(ntop.exists(name))) then
      if(enable_second_debug == 1) then io.write('Creating RRD ', name, '\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 name,
	 1,   -- step
	 'DS:' .. ds .. ':GAUGE:5:0:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.intf_rrd_raw_days*24*60*60),   -- raw: 1 day = 86400
	 'RRA:AVERAGE:0.5:3600:'..tostring(prefs.intf_rrd_1h_days*24), -- 1h resolution (3600 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:86400:'..tostring(prefs.intf_rrd_1d_days) -- 1d resolution (86400 points)  365 days
	 -- 'RRA:HWPREDICT:1440:0.1:0.0035:20'
      )
   end
end

function makeRRD(basedir, ifname, rrdname, step, value)
   local name = fixPath(basedir .. "/" .. rrdname .. ".rrd")

   if(string.contains(rrdname, "num_")) then
      create_rrd_num(name, rrdname)
   else
      create_rrd(name, 1, rrdname)
   end
   ntop.rrd_update(name, "N:".. tolongint(value))
   if(enable_second_debug == 1) then io.write('Updating RRD ['.. ifname..'] '.. name .. " " .. value ..'\n') end
end

function createRRDcounter(path, step, verbose)
   if(not(ntop.exists(path))) then
      if(verbose) then print('Creating RRD ', path, '\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 path,
	 step, -- step
	 'DS:sent:DERIVE:600:U:U',
	 'DS:rcvd:DERIVE:600:U:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.other_rrd_raw_days*24*300),  -- raw: 1 day = 1 * 24 = 24 * 300 sec = 7200
	 'RRA:AVERAGE:0.5:12:'..tostring(prefs.other_rrd_1h_days*24), -- 1h resolution (12 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:288:'..tostring(prefs.other_rrd_1d_days) -- 1d resolution (288 points)  365 days
	 --'RRA:HWPREDICT:1440:0.1:0.0035:20'
      )
   end
end

-- ########################################################

function createSingleRRDcounter(path, step, verbose)
   if(not(ntop.exists(path))) then
      if(verbose) then print('Creating RRD ', path, '\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 path,
	 step, -- step
	 'DS:num:DERIVE:600:U:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.other_rrd_raw_days*24*300),  -- raw: 1 day = 1 * 24 = 24 * 300 sec = 7200
	 'RRA:AVERAGE:0.5:12:'..tostring(prefs.other_rrd_1h_days*24), -- 1h resolution (12 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:288:'..tostring(prefs.other_rrd_1d_days), -- 1d resolution (288 points)  365 days
	 'RRA:HWPREDICT:1440:0.1:0.0035:20')
   end
end

-- ########################################################
-- this method will be very likely used when saving subnet rrd traffic statistics
function createTripleRRDcounter(path, step, verbose)
   if(not(ntop.exists(path))) then
      if(verbose) then io.write('Creating RRD '..path..'\n') end
      local prefs = ntop.getPrefs()
      ntop.rrd_create(
	 path,
	 step, -- step
	 'DS:ingress:DERIVE:600:U:U',
	 'DS:egress:DERIVE:600:U:U',
	 'DS:inner:DERIVE:600:U:U',
	 'RRA:AVERAGE:0.5:1:'..tostring(prefs.other_rrd_raw_days*24*300),  -- raw: 1 day = 1 * 24 = 24 * 300 sec = 7200
	 'RRA:AVERAGE:0.5:12:'..tostring(prefs.other_rrd_1h_days*24), -- 1h resolution (12 points)   2400 hours = 100 days
	 'RRA:AVERAGE:0.5:288:'..tostring(prefs.other_rrd_1d_days) -- 1d resolution (288 points)  365 days
	 --'RRA:HWPREDICT:1440:0.1:0.0035:20'
      )
   end
end

-- ########################################################

function dumpSingleTreeCounters(basedir, label, host, verbose)
   what = host[label]

   if(what ~= nil) then
      for k,v in pairs(what) do
	 for k1,v1 in pairs(v) do
	    -- print("-->"..k1.."/".. type(v1).."<--\n")

	    if(type(v1) == "table") then
	       for k2,v2 in pairs(v1) do

		  dname = fixPath(basedir.."/"..label.."/"..k.."/"..k1)

		  if(not(ntop.exists(dname))) then
		     ntop.mkdir(dname)
		  end

		  fname = dname..fixPath("/"..k2..".rrd")
		  createSingleRRDcounter(fname, 300, verbose)
		  ntop.rrd_update(fname, "N:"..toint(v2))
		  if(verbose) then print("\t"..fname.."\n") end
	       end
	    else
	       dname = fixPath(basedir.."/"..label.."/"..k)

	       if(not(ntop.exists(dname))) then
		  ntop.mkdir(dname)
	       end

	       fname = dname..fixPath("/"..k1..".rrd")
	       createSingleRRDcounter(fname, 300, verbose)
	       ntop.rrd_update(fname, "N:"..toint(v1))
	       if(verbose) then print("\t"..fname.."\n") end
	    end
	 end
      end
   end
end

function printGraphTopFlows(ifId, host, epoch, zoomLevel, l7proto)
   -- Check if the DB is enabled
   rsp = interface.execSQLQuery("show tables")
   if(rsp == nil) then return end

   if((epoch == nil) or (epoch == "")) then epoch = os.time() end

   local d = getZoomDuration(zoomLevel)

   epoch_end = epoch
   epoch_begin = epoch-d

   local tot_flows = { }
   local versions = { ['IPv4']=4, ['IPv6']=6 }
   for k,v in pairs(versions) do
      local res = getNumFlows(ifId, v, (host or ''), '', '', (l7proto or ''), '', epoch_begin, epoch_end)

      for _,flow in pairs(res) do
	 tot_flows[v] = flow['TOT_FLOWS']
      end
   end

   printTopFlows(ifId, host, epoch_begin, epoch_end, l7proto, '', '', '', tot_flows[4], tot_flows[6])
end

function printTopFlows(ifId, host, epoch_begin, epoch_end, l7proto, l4proto, port, info, limitv4, limitv6)
   url_update = ntop.getHttpPrefix().."/lua/get_db_flows.lua?ifId="..ifId.. "&host="..(host or '') .. "&epoch_begin="..(epoch_begin or '').."&epoch_end="..(epoch_end or '').."&l4proto="..(l4proto or '').."&port="..(port or '').."&info="..(info or '')

   if(l7proto ~= "") then
      if(not(isnumber(l7proto))) then
	 local id

	 -- io.write(l7proto.."\n")
	 l7proto = string.gsub(l7proto, "%.rrd", "")

	 if(string.ends(l7proto, ".rrd")) then l7proto = string.sub(l7proto, 1, -5) end

	 id = interface.getnDPIProtoId(l7proto)

	 if(id ~= -1) then
	    l7proto = id
	    title = "Top "..l7proto.." Flows"
	 else
	    l7proto = ""
	 end
      end

      if(l7proto ~= "") then
	 url_update = url_update.."&l7proto="..l7proto
      end
   end


   if((host == "") and (l4proto == "") and (port == "")) then
      title = "Top Flows ["..formatEpoch(epoch_begin).." - "..formatEpoch(epoch_end).."]"
   else
      title = ""
   end


if(host ~= nil) then
  local chunks = {host:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
  if(#chunks == 4) then
     limitv6="0"
  end
end

-- prepare some attributes that will be attached to divs
local div_data = ""
if epoch_begin ~= "" and epoch_begin ~= nil then
   div_data = div_data..' epoch_begin="'..tostring(epoch_begin)..'" '
end
if epoch_end ~= "" and epoch_end ~= nil then
   div_data = div_data..' epoch_end="'..tostring(epoch_end)..'" '
end
if host ~= "" and host ~= nil then
   div_data = div_data..' host="'..tostring(host)..'" '
end
if l7proto ~= "" and l7proto ~= nil then
   div_data = div_data..' l7_proto_id="'..l7proto..'" '
end
if l4proto ~= "" and l4proto ~= nil then
   div_data = div_data..' l4_proto_id="'..l4proto..'" '
end
if port ~= "" and port ~= nil then
   div_data = div_data..' port="'..port..'" '
end

local ipv4_enabled = not(limitv4 == nil or limitv4 == "" or limitv4 == "0")
local ipv6_enabled = not(limitv6 == nil or limitv6 == "" or limitv6 == "0")

if ipv4_enabled == true then
print [[
      <div class="tab-pane fade" id="ipv4" ]] print(div_data) print[[">
	<div id="table-flows4"></div>
]] historicalDownloadButtonsBar('flows_v4', 'ipv4',
				ipv4_enabled,
				ipv6_enabled) print[[
      </div>
]]
else
print[[
  <script>
    $('#tab-ipv4').remove()
  </script>
]]
end

if ipv6_enabled == true then
print[[
      <div class="tab-pane fade" id="ipv6" ]] print(div_data) print[[">
    <div id="table-flows6"></div>
]] historicalDownloadButtonsBar('flows_v6', 'ipv6',
				ipv4_enabled,
				ipv6_enabled
			       ) print[[
  </div>
]]
else
print[[
  <script>
    $('#tab-ipv6').remove()
  </script>
]]
end

print [[

      <script>
      $('a[href="#ipv4"]').on('shown.bs.tab', function (e) {
        if ($('a[href="#ipv4"]').attr("loaded") == 1){
          // do nothing if the tab has already been computed and populated
          return;
        }

        // if here, then we actually have to load the datatable
        $('a[href="#ipv4"]').attr("loaded", 1);

   ]]

if(not((limitv4 == nil) or (limitv4 == "") or (limitv4 == "0"))) then
print [[
	    var url_update4 = "]] print(url_update.."&limit="..limitv4) print [[&version=4";

	    var graph_options4 = {
						    url: url_update4,
	       perPage: 5, ]]

			      if(title ~= "") then print('title: "IPv4 '..title..'",\n') else print("title: '',\n") end

print [[
						    showFilter: true,
						    showPagination: true,
						    sort: [ [ "BYTES","desc"] ],
						    columns: [
						       {
							  title: "Key",
							  field: "idx",
							  hidden: true,
						       },
						 ]]

						 if(ntop.isPro()) then
						    print [[
						       {
							  title: "",
							  field: "FLOW_URL",
							  sortable: false,
							  css: {
							     textAlign: 'center'
							  }
						       },
						 ]]
					      end

print [[
						       {
							  title: "Application",
							  field: "L7_PROTO",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "L4 Proto",
							  field: "PROTOCOL",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "Client",
							  field: "CLIENT",
							  sortable: false,
						       },
						       {
							  title: "Server",
							  field: "SERVER",
							  sortable: false,
						       },
						       {
							  title: "Begin",
							  field: "FIRST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "End",
							  field: "LAST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "Traffic Sent",
							  field: "IN_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "Traffic Received",
							  field: "OUT_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "Total Traffic",
							  field: "BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "Info",
							  field: "INFO",
							  sortable: true,
							  css: {
							     textAlign: 'left'
							  }
						       },
						       {
							  title: "Avg Thpt",
							  field: "AVG_THROUGHPUT",
							  sortable: false,
							  css: {
							     textAlign: 'right'
							  }
						       }
						    ]

						 };



	    var table4 = $("#table-flows4").datatable(graph_options4);
      });  // closes the event handler on shown.bs.tab
      ]]
   end


      if((limitv6 == nil) or (limitv6 == "") or (limitv6 == "0")) then print("</script>") return end

print [[
      $('a[href="#ipv6"]').on('shown.bs.tab', function (e) {
        if ($('a[href="#ipv6"]').attr("loaded") == 1){
          // do nothing if the tab has already been computed and populated
          return;
        }

        // if here, then we actually have to load the datatable
        $('a[href="#ipv6"]').attr("loaded", 1);


	    var url_update6 = "]] print(url_update.."&limit="..limitv6) print [[&version=6";

	    var graph_options6 = {
						    url: url_update6,
						    perPage: 5, ]]

					      if(title ~= "") then print('title: "IPv6 '..title..'",\n') else print("title: '',\n") end

print [[

						    showFilter: true,
						    showPagination: true,
						    sort: [ [ "BYTES","desc"] ],
						    columns: [
						       {
							  title: "Key",
							  field: "idx",
							  hidden: true,
						       },
						 ]]

						 if(ntop.isPro()) then
						    print [[
						       {
							  title: "",
							  field: "FLOW_URL",
							  sortable: false,
							  css: {
							     textAlign: 'center'
							  }
						       },
						 ]]
					      end

print [[
						       {
							  title: "Application",
							  field: "L7_PROTO",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "L4 Proto",
							  field: "PROTOCOL",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "Client",
							  field: "CLIENT",
							  sortable: false,
						       },
						       {
							  title: "Server",
							  field: "SERVER",
							  sortable: false,
						       },
						       {
							  title: "Begin",
							  field: "FIRST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "End",
							  field: "LAST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "Traffic Sent",
							  field: "IN_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "Traffic Received",
							  field: "OUT_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "Total Traffic",
							  field: "BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "Avg Thpt",
							  field: "AVG_THROUGHPUT",
							  sortable: false,
							  css: {
							     textAlign: 'right'
							  }
						       }
						    ]

						 };


	 var table6 = $("#table-flows6").datatable(graph_options6);
      }); // closes the event handler on shown.bs.tab
	 </script>
]]

end

-- ########################################################

-- reads one or more RRDs and returns a json suitable to feed rickshaw

function singlerrd2json(ifid, host, rrdFile, start_time, end_time, rickshaw_json, append_ifname_to_labels)
   local rrdname = getRRDName(ifid, host, rrdFile)
   local names =  {}
   local names_cache = {}
   local series = {}
   local prefixLabel = l4Label(string.gsub(rrdFile, ".rrd", ""))
   -- with a scaling factor we can stretch or shrink rrd values
   -- by default we set this to a value of 8, in order to convert bytes
   -- rrds into bits.
   local scaling_factor = 8

   --io.write(prefixLabel.."\n")
   if(prefixLabel == "Bytes" or string.starts(rrdFile, 'categories/')) then
      prefixLabel = "Traffic"
   end

   if(string.contains(rrdFile, "num_") or string.contains(rrdFile, "tcp_") or string.contains(rrdFile, "packets") or string.contains(rrdFile, "drops")) then
      -- do not scale number, packets, and drops
      scaling_factor = 1
   end

   if(not ntop.notEmptyFile(rrdname)) then return '{}' end

   local fstart, fstep, fnames, fdata = ntop.rrd_fetch(rrdname, 'AVERAGE', start_time, end_time)
   if(fstart == nil) then return '{}' end

   --[[
   io.write('start time: '..start_time..'  end_time: '..end_time..'\n')
   io.write('fstart: '..fstart..'  fstep: '..fstep..' rrdname: '..rrdname..'\n')
   io.write('len(fdata): '..table.getn(fdata)..'\n')
   --]]
   local max_num_points = 600 -- This is to avoid having too many points and thus a fat graph
   local num_points_found = table.getn(fdata)
   local sample_rate = round(num_points_found / max_num_points)
   local port_mode = false

   if(sample_rate < 1) then sample_rate = 1 end
   
   -- Pretty printing for flowdevs/a.b.c.d/e.rrd
   local elems = split(prefixLabel, "/")
   if((elems[#elems] ~= nil) and (#elems > 1)) then
      prefixLabel = "Port "..elems[#elems]
      port_mode = true
   end
   
   -- prepare rrd labels
   for i, n in ipairs(fnames) do
      -- handle duplicates
      if (names_cache[n] == nil) then
	 local extra_info = ''
	 names_cache[n] = true
	 if append_ifname_to_labels then
	     extra_info = getInterfaceName(ifid)
	 end
	 if host ~= nil and not string.starts(host, 'profile:') and not string.starts(rrdFile, 'categories/') then
	     extra_info = extra_info.." ".. firstToUpper(n)
	 end
	 if extra_info ~= "" then
	    if(port_mode) then
	       if(#names == 0) then
		  names[#names+1] = prefixLabel.." Egress ("..trimSpace(extra_info)..") "
	       else
		  names[#names+1] = prefixLabel.." Ingress ("..trimSpace(extra_info)..") "
	       end
	    else
	       names[#names+1] = prefixLabel.." ("..trimSpace(extra_info)..") "
	    end
	 else
	     names[#names+1] = prefixLabel
	 end
      end
    end

   local minval, maxval, lastval = 0, 0, 0
   local maxval_time, minval_time, lastval_time  = nil, nil, nil
   local sampling = 1
   local s = {}
   local totalval, avgval = {}, {}
   for i, v in ipairs(fdata) do
      local instant = fstart + (i-1)*fstep  -- this is the instant in time corresponding to the datapoint
      s[0] = instant  -- s holds the instant and all the values
      totalval[instant] = 0  -- totalval holds the sum of all values of this instant
      avgval[instant] = 0

      local elemId = 1
      for _, w in ipairs(v) do

	 if(w ~= w) then
	    -- This is a NaN
	    w = 0
	 else
	    --io.write(w.."\n")
	    w = tonumber(w)
	    if(w < 0) then
	       w = 0
	    end
	 end

	 -- update the total value counter, which is the non-scaled integral over time
	 totalval[instant] = totalval[instant] + w * fstep
	 -- also update the average val (do not multiply by fstep, this is not the integral)
	 avgval[instant] = avgval[instant] + w
	 -- and the scaled current value (remember that these are derivatives)
	 w = w * scaling_factor
	 -- the scaled current value w goes into its own element elemId
	 if (s[elemId] == nil) then s[elemId] = 0 end
	 s[elemId] = s[elemId] + w
	 --if(s[elemId] > 0) then io.write("[".. elemId .. "]=" .. s[elemId] .."\n") end
	 elemId = elemId + 1
      end

      -- stops every sample_rate samples, or when there are no more points
      if(sampling == sample_rate or num_points_found == i) then
	 local sample_sum = 0
	 for elemId=1,#s do
	    -- calculate the average in the sampling period
	    s[elemId] = s[elemId] / sampling
	    sample_sum = sample_sum + s[elemId]
	 end
	 -- update last instant
	 if lastval_time == nil or instant > lastval_time then
	    lastval = sample_sum
	    lastval_time = instant
	 end
	 -- possibly update maximum value (grab the most recent in case of a tie)
	 if maxval_time == nil or (sample_sum >= maxval and instant > maxval_time) then
	    maxval = sample_sum
	    maxval_time = instant
	 end
	 -- possibly update the minimum value (grab the most recent in case of a tie)
	 if minval_time == nil or (sample_sum <= minval and instant > minval_time) then
	    minval = sample_sum
	    minval_time = instant
	 end
	 series[#series+1] = s
	 sampling = 1
	 s = {}
     else
	 sampling = sampling + 1
      end
   end

   local tot = 0
   for k, v in pairs(totalval) do tot = tot + v end
   totalval = tot
   tot = 0
   for k, v in pairs(avgval) do tot = tot + v end
   local average = tot / num_points_found

   local percentile = 0.95*maxval
   local colors = {
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

   if(names ~= nil) then
      json_ret = ''

      if(rickshaw_json) then
	 for elemId=1,#names do
	    if(elemId > 1) then
	       json_ret = json_ret.."\n,\n"
	    end
	    local name = names[elemId]
	    json_ret = json_ret..'{"name": "'.. name .. '",\n'
	    json_ret = json_ret..'color: \''.. colors[elemId] ..'\',\n'
	    json_ret = json_ret..'"data": [\n'
	    n = 0
	    for key, value in pairs(series) do
	       if(n > 0) then
		  json_ret = json_ret..',\n'
	       end
	       json_ret = json_ret..'\t{ "x": '..  value[0] .. ', "y": '.. value[elemId] .. '}'
	       n = n + 1
	    end

	    json_ret = json_ret.."\n]}\n"
	 end
      else
	 -- NV3
	 local num_entries = 0;

	 for elemId=1,#names do
	    num_entries = num_entries + 1
	    if(elemId > 1) then
	       json_ret = json_ret.."\n,\n"
	    end
	    name = names[elemId]

	    json_ret = json_ret..'{"key": "'.. name .. '",\n'
--	    json_ret = json_ret..'"color": "'.. colors[num_entries] ..'",\n'
	    json_ret = json_ret..'"area": true,\n'
	    json_ret = json_ret..'"values": [\n'
	    n = 0
	    for key, value in pairs(series) do
	       if(n > 0) then
		  json_ret = json_ret..',\n'
	       end
	       json_ret = json_ret..'\t[ '..value[0] .. ', '.. value[elemId] .. ' ]'
	       --json_ret = json_ret..'\t{ "x": '..  value[0] .. ', "y": '.. value[elemId] .. '}'
	       n = n + 1
	    end

	    json_ret = json_ret.."\n] }\n"
	 end

	 if(false) then
	    json_ret = json_ret..",\n"

	    num_entries = num_entries + 1
	    json_ret = json_ret..'\n{"key": "Average",\n'
	    json_ret = json_ret..'"color": "'.. colors[num_entries] ..'",\n'
	    json_ret = json_ret..'"type": "line",\n'

	    json_ret = json_ret..'"values": [\n'
	    n = 0
	    for key, value in pairs(series) do
	       if(n > 0) then
		  json_ret = json_ret..',\n'
	       end
	       --json_ret = json_ret..'\t[ '..value[0] .. ', '.. value[elemId] .. ' ]'
	       json_ret = json_ret..'\t{ "x": '..  value[0] .. ', "y": '.. average .. '}'
	       n = n + 1
	    end
	    json_ret = json_ret..'\n] },\n'


	    num_entries = num_entries + 1
	    json_ret = json_ret..'\n{"key": "95th Percentile",\n'
	    json_ret = json_ret..'"color": "'.. colors[num_entries] ..'",\n'
	    json_ret = json_ret..'"type": "line",\n'
	    json_ret = json_ret..'"yAxis": 1,\n'
	    json_ret = json_ret..'"values": [\n'
	    n = 0
	    for key, value in pairs(series) do
	       if(n > 0) then
		  json_ret = json_ret..',\n'
	       end
	       --json_ret = json_ret..'\t[ '..value[0] .. ', '.. value[elemId] .. ' ]'
	       json_ret = json_ret..'\t{ "x": '..  value[0] .. ', "y": '.. percentile .. '}'
	       n = n + 1
	    end

	    json_ret = json_ret..'\n] }\n'
	 end
      end
   end

   local ret = {}
   ret.maxval_time = maxval_time
   ret.maxval = round(maxval, 0)

   ret.minval_time = minval_time
   ret.minval = round(minval, 0)

   ret.lastval_time = lastval_time
   ret.lastval = round(lastval, 0)

   ret.totalval = round(totalval, 0)
   ret.percentile = round(percentile, 0)
   ret.average = round(average, 0)
   ret.json = json_ret

  return(ret)
end

-- #################################################

function rrd2json(ifid, host, rrdFile, start_time, end_time, rickshaw_json, expand_interface_views)
   local ret = {}
   local num = 0
   local debug_metric = false

   interface.select(getInterfaceName(ifid))
   local ifstats = interface.getStats()
   local rrd_if_ids = {}  -- read rrds for interfaces listed here
   rrd_if_ids[1] = ifid -- the default submitted interface
   -- interface.select(getInterfaceName(ifid))

   if(debug_metric) then
       io.write('ifid: '..ifid..' ifname:'..getInterfaceName(ifid)..'\n')
       io.write('expand_interface_views: '..tostring(expand_interface_views)..'\n')
       io.write('ifstats.isView: '..tostring(ifstats.isView)..'\n')
   end
   if expand_interface_views and ifstats.isView then
	-- expand rrds for views and read each physical interface separately
	for iface,_ in pairs(ifstats.interfaces) do
	    if(debug_metric) then io.write('iface: '..iface..' id: '..getInterfaceId(iface)..'\n') end
	    rrd_if_ids[#rrd_if_ids+1] = getInterfaceId(iface)
	end
   end


   if(debug_metric) then io.write("RRD File: "..rrdFile.."\n") end

   if(rrdFile == "all") then
       -- disable expand interface views for rrdFile == all
       expand_interface_views=false
       local dirs = ntop.getDirs()
       local p = dirs.workingdir .. "/" .. ifid .. "/rrd/"
       if(debug_metric) then io.write("Navigating: "..p.."\n") end

       if(host ~= nil) then
	   p = p .. getPathFromKey(host)
	   go_deep = true
       else
	   go_deep = false
       end

       d = fixPath(p)
       rrds = navigatedir("", "*", d, d, go_deep, false, ifid, host, start_time, end_time)

       local traffic_array = {}
       for key, value in pairs(rrds) do
	   rsp = singlerrd2json(ifid, host, value, start_time, end_time, rickshaw_json, expand_interface_views)
	   if(rsp.totalval ~= nil) then total = rsp.totalval else total = 0 end

	   if(total > 0) then
	       traffic_array[total] = rsp
	       if(debug_metric) then io.write("Analyzing: "..value.." [total "..total.."]\n") end
	   end
       end

       for key, value in pairsByKeys(traffic_array, rev) do
	   ret[#ret+1] = value
	   if(ret[#ret].json ~= nil) then
	       if(debug_metric) then io.write(key.."\n") end
	       num = num + 1
	       if(num >= 10) then break end
	   end
       end
   else
       num = 0
       for _,iface in pairs(rrd_if_ids) do
	   if(debug_metric) then io.write('iface: '..iface..'\n') end
	    for i,rrd in pairs(split(rrdFile, ",")) do
		if(debug_metric) then io.write("["..i.."] "..rrd..' iface: '..iface.."\n") end
		ret[#ret + 1] = singlerrd2json(iface, host, rrd, start_time, end_time, rickshaw_json, expand_interface_views)
		if(ret[#ret].json ~= nil) then num = num + 1 end
	    end
       end

   end

   if(debug_metric) then io.write("#rrds="..num.."\n") end
   if(num == 0) then
      ret = {}
      ret.json = "[]"
      return(ret)
   end
   local i = 1
   -- if we are expanding an interface view, we want to concatenate
   -- jsons for single interfaces, and not for the view. Since view statistics
   -- are in ret[1], it suffices to aggregate jsons from index i >= 2
   if expand_interface_views and ifstats.isView then
       i = 2
   end
   local json = "["
   local first = true  -- used to decide where to append commas
   while i <= num do
      if(debug_metric) then io.write("->"..i.."\n") end
      if not first then json = json.."," end
      json = json..ret[i].json
      i = i + 1
      first = false
   end
   json = json.."]"
   -- the (possibly aggregated) json always goes into ret[1]
   -- ret[1] possibly contains aggregated view statistics such as
   -- maxval and maxval_time or minval and minval_time
   ret[1].json = json
   -- io.write(json.."\n")
   return(ret[1])
end
