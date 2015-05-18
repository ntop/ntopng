--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
require "graph_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

local function makeTopStatsScriptsArray()
   path = dirs.installdir .. "/scripts/lua/modules/top_scripts"
   path = fixPath(path)
   local files = ntop.readdir(path)
   topArray = {}

   for k,v in pairs(files) do
      if(v ~= nil) then
	 value = {}
	 fn,ext = v:match("([^.]+).([^.]+)")
	 mod = require("top_scripts."..fn)
	 if(type(mod) ~= type(true)) then
            value["name"] = mod.name
            value["script"] = mod.infoScript
            value["key"] = mod.infoScriptKey
            value["levels"] = mod.numLevels
            topArray[fn] = value
	 end
      end
   end
   return(topArray)
end

page = _GET["page"]
if_name = _GET["if_name"]

if(if_name == nil) then if_name = ifname end

max_num_shapers = 10
interface.select(if_name)
ifid = interface.name2id(ifname)
shaper_key = "ntopng.prefs."..ifid..".shaper_max_rate"
is_historical = interface.isHistoricalInterface(ifid)
ifstats = interface.getStats()

if(_GET["custom_name"] ~=nil) then
   if(_GET["csrf"] ~= nil) then
      ntop.setCache('ntopng.prefs.'..ifstats.name..'.name',_GET["custom_name"])
   end
end

if(_GET["dump_all_traffic"] ~= nil and _GET["csrf"] ~= nil) then
   page = "packetdump"
   ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic',_GET["dump_all_traffic"])
   interface.loadDumpPrefs()
end
if(_GET["dump_traffic_to_tap"] ~= nil and _GET["csrf"] ~= nil) then
   page = "packetdump"
   ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_tap',_GET["dump_traffic_to_tap"])
   interface.loadDumpPrefs()
end
if(_GET["dump_traffic_to_disk"] ~= nil and _GET["csrf"] ~= nil) then
   page = "packetdump"
   ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_disk',_GET["dump_traffic_to_disk"])
   interface.loadDumpPrefs()
end
if(_GET["dump_unknown_to_disk"] ~= nil and _GET["csrf"] ~= nil) then
   page = "packetdump"
   ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_disk',_GET["dump_unknown_to_disk"])
   interface.loadDumpPrefs()
end
if(_GET["dump_security_to_disk"] ~= nil and _GET["csrf"] ~= nil) then
   page = "packetdump"
   ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_security_disk',_GET["dump_security_to_disk"])
   interface.loadDumpPrefs()
end

if(_GET["sampling_rate"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["sampling_rate"]) ~= nil) then
     page = "packetdump"
     val = ternary(_GET["sampling_rate"] ~= "0", _GET["sampling_rate"], "1")
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate', val)
     interface.loadDumpPrefs()
   end
end
if(_GET["max_pkts_file"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["max_pkts_file"]) ~= nil) then
     page = "packetdump"
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file',_GET["max_pkts_file"])
     interface.loadDumpPrefs()
   end
end
if(_GET["max_sec_file"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["max_sec_file"]) ~= nil) then
     page = "packetdump"
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file',_GET["max_sec_file"])
     interface.loadDumpPrefs()
   end
end
if(_GET["max_files"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["max_files"]) ~= nil) then
     page = "packetdump"
     local max_files_size = tonumber(_GET["max_files"])
     max_files_size = max_files_size * 1000000
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_files', tostring(max_files_size))
     interface.loadDumpPrefs()
   end
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
print("<link href=\""..ntop.getHttpPrefix().."/css/tablesorted.css\" rel=\"stylesheet\">")
active_page = "if_stats"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

rrdname = fixPath(dirs.workingdir .. "/" .. ifstats.id .. "/rrd/bytes.rrd")

if(if_name == nil) then
   _ifname = ifname
else
   _ifname = if_name
end

url= ntop.getHttpPrefix()..'/lua/if_stats.lua?if_name=' .. _ifname

--   Added global javascript variable, in order to disable the refresh of pie chart in case
--  of historical interface
if not is_historical then
   print('\n<script>var refresh = 3000 /* ms */;</script>\n')
else
   print('\n<script>var refresh = null /* ms */;</script>\n')
end

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]

--io.write(ifname.."\n")
short_name = getHumanReadableInterfaceName(ifname)
if(short_name ~= ifname) then
   short_name = short_name .. "..."
end

print("<li><a href=\"#\">Interface: " .. short_name .."</a></li>\n")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\">Overview</a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\">Overview</a></li>")
end

-- Disable Packets and Protocols tab in case of the number of packets is equal to 0
if((ifstats ~= nil) and (ifstats.stats_packets > 0)) then
   if(ifstats.type ~= "zmq") then
      if(page == "packets") then
	 print("<li class=\"active\"><a href=\"#\">Packets</a></li>\n")
      else
	 print("<li><a href=\""..url.."&page=packets\">Packets</a></li>")
      end
   end

   if(page == "ndpi") then
      print("<li class=\"active\"><a href=\"#\">Protocols</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=ndpi\">Protocols</a></li>")
   end
end

if(is_historical) then
   if(page == "config_historical") then
      print("<li class=\"active\"><a href=\"#\">Load Data</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=config_historical\">Load Data</a></li>")
   end
else
   if(ntop.exists(rrdname) and not is_historical) then
      if (page == "historical") then
        print("<li class=\"active\"><a href=\""..url.."&page=historical\">Historical Activity</a></li>")
      else
        print("<li><a href=\""..url.."&page=historical\">Historical Activity</a></li>")
      end
   end
end

if(not(ifstats.iface_view)) then
   if (isAdministrator()) then
      if (page == "packetdump") then
	 print("<li class=\"active\"><a href=\""..url.."&page=packetdump\">Packet Dump</a></li>")
      else
	 print("<li><a href=\""..url.."&page=packetdump\">Packet Dump</a></li>")
      end
   end
end

if(ifstats.iface_inline) then
   if (page == "filtering") then
      print("<li class=\"active\"><a href=\""..url.."&page=filtering\">Traffic Filtering</a></li>")
   else
      print("<li><a href=\""..url.."&page=filtering\">Traffic Filtering</a></li>")
   end

   if (page == "shaping") then
      print("<li class=\"active\"><a href=\""..url.."&page=shaping\">Traffic Shaping</a></li>")
   else
      print("<li><a href=\""..url.."&page=shaping\">Traffic Shaping</a></li>")
   end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
   ]]

if((page == "overview") or (page == nil)) then
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=15%>Id</th><td colspan=3>" .. ifstats.id .. " ")
   print("</td></tr>\n")
   if not (is_historical) then
      print("<tr><th width=250>State</th><td colspan=3>")
      state = toggleTableButton("", "", "Active", "1","primary", "Paused", "0","primary", "toggle_local", "ntopng.prefs."..if_name.."_not_idle")

      if(state == "0") then
	 on_state = true
      else
	 on_state = false
      end

      interface.setInterfaceIdleState(on_state)

      print("</td></tr>\n")
   end
   print("<tr><th width=250>Name</th><td colspan=2>" .. ifstats.name .. "</td>\n")

   if(ifstats.name ~= nil) then
      label = ntop.getCache('ntopng.prefs.'..ifstats.name..'.name')
      if(isAdministrator()) then
	 print("<td>")
      else
	 print("<td colspan=3>")
      end

      print [[
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="if_name" value="]]
      print(ifstats.name)
      print [[">]]

      if(isAdministrator()) then
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print [[
       <input type="text" name="custom_name" placeholder="Custom Name" value="]]
	 if(label ~= nil) then print(label) end
	 print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save Name</button>
    </form>
    </td></tr>
       ]]
      else
	 print("</td></tr>")
      end
   end
   if(ifstats.name ~= ifstats.description) then
      print("<tr><th>Description</th><td colspan=3>" .. ifstats.description .. "</td></tr>\n")
   end

   print("<tr><th>Family </th><td colspan=3>" .. ifstats.type)
   if(ifstats.iface_inline) then
      print(" In-Path Interface (Bump in the Wire)")
      elseif(ifstats.iface_view) then
      print(" (Aggregated Interface View)")
   end
   print("</td></tr>\n")
   print("<tr><th>Bytes</th><td colspan=3><div id=if_bytes>" .. bytesToSize(ifstats.stats_bytes) .. "</div>");

   print [[
   <p>
   <small>
   <div class="alert alert-info">
      <b>NOTE</b>: In ethernet networks, each packet has an <A HREF=https://en.wikipedia.org/wiki/Ethernet_frame>overhead of 24 bytes</A> [preamble (7 bytes), start of frame (1 byte), CRC (4 bytes), and <A HREF=http://en.wikipedia.org/wiki/Interframe_gap>IFG</A> (12 bytes)]. Such overhead needs to be accounted to the interface traffic, but it is not added to the traffic being exchanged between IP addresses. This is because such data contributes to interface load, but it cannot be accounted in the traffic being exchanged by hosts, and thus expect little discrepancies between host and interface traffic values.
         </div></small>
   </td></tr>
   ]]

   if(ifstats["pkt_dumper"] ~= nil) then
      print("<tr><th rowspan=2>Packet Dumper</th><th colspan=2>Dumped Packets</th><th>Dumped Files</th></tr>\n")
      print("<tr><td colspan=2><div id=dumped_pkts>".. formatValue(ifstats["pkt_dumper"]["num_dumped_pkts"]) .."</div></td>")
      print("<td><div id=dumped_files>".. formatValue(ifstats["pkt_dumper"]["num_dumped_files"]) .."</div></td></tr>\n")
   end


   if(ifstats.type ~= "zmq") then
      label = "Pkts"
   else
      label = "Flows"
   end

print[[ <tr><th colspan=1>Traffic Breakdown</th><td colspan=3><div class="pie-chart" id="ifaceTrafficBreakdown"></div></td></tr>

        <script type='text/javascript'>
	       window.onload=function() {

				   do_pie("#ifaceTrafficBreakdown", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_local_stats.lua', { ifname: ]] print(ifstats.id .. " }, \"\", refresh); \n")
      print ("}\n</script>\n")

   print("<tr><th colspan=4>Ingress Traffic</th></tr>\n")
   print("<tr><th>Received Packets</th><td width=20%><span if=if_bytes>"..bytesToSize(ifstats.stats_bytes).."</span> [<span id=if_pkts>".. formatValue(ifstats.stats_packets) .. " ".. label .."</span>] <span id=pkts_trend></span></td><th width=20%>Dropped Packets</th><td width=20%><span id=if_drops>")

   if(ifstats.stats_drops > 0) then print('<span class="label label-danger">') end
   print(formatValue(ifstats.stats_drops).. " " .. label)

   if((ifstats.stats_packets+ifstats.stats_drops) > 0) then
      local pctg = round((ifstats.stats_drops*100)/(ifstats.stats_packets+ifstats.stats_drops), 2)
      if(pctg > 0) then print(" [ " .. pctg .. " % ] ") end
   end

   if(ifstats.stats_drops > 0) then print('</span>') end
   print("</span>  <span id=drops_trend></span></td></tr>\n")

   if(ifstats["bridge.device_a"] ~= nil) then
      print("<tr><th colspan=4>Bridged Traffic</th></tr>\n")
      print("<tr><th>Interface Direction</th><th>Ingress Packets</th><th>Egress Packets</th><th>Filtered Packets</th></tr>\n")
      print("<tr><th>".. ifstats["bridge.device_a"] .. " -> ".. ifstats["bridge.device_b"] .."</th><td><span id=a_to_b_in_pkts>".. formatPackets(ifstats["bridge.a_to_b.in_pkts"]) .."</span></td>")
      print("<td><span id=a_to_b_out_pkts>".. formatPackets(ifstats["bridge.a_to_b.out_pkts"]) .."</span></td><td><span id=a_to_b_filtered_pkts>".. formatPackets(ifstats["bridge.a_to_b.filtered_pkts"]) .."</span></td></tr>\n")
      print("<tr><th>".. ifstats["bridge.device_b"] .. " -> ".. ifstats["bridge.device_a"] .."</th><td><span id=b_to_a_in_pkts>".. formatPackets(ifstats["bridge.b_to_a.in_pkts"]) .."</span></td>")
      print("<td><span id=b_to_a_out_pkts>"..formatPackets( ifstats["bridge.b_to_a.out_pkts"]) .."</span></td><td><span id=b_to_a_filtered_pkts>".. formatPackets(ifstats["bridge.b_to_a.filtered_pkts"]) .."</span></td></tr>\n")
   end

   print("</table>\n")
elseif((page == "packets")) then
   print [[
      <table class="table table-bordered table-striped">
        <tr><th class="text-center">Size Distribution</th><td colspan=5><div class="pie-chart" id="sizeDistro"></div></td></tr>
      </table>

        <script type='text/javascript'>
         window.onload=function() {

       do_pie("#sizeDistro", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_pkt_distro.lua', { type: "size", ifname: "]] print(_ifname.."\"")
   print [[
           }, "", refresh);
    }

      </script><p>
  ]]
elseif(page == "ndpi") then

--fc = interface.getNdpiFlowsCount()
--for k,v in pairs(fc) do
--   io.write(k.."="..v.."\n")
--end


   print [[
	    <script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/jquery.tablesorter.js"></script>
      <table class="table table-bordered table-striped">
      <tr><th class="text-left">Protocol Overview</th>
	       <td colspan=3><div class="pie-chart" id="topApplicationProtocols"></div></td>
	       <td colspan=2><div class="pie-chart" id="topApplicationBreeds"></div></td>
	       </tr>
      <tr><th class="text-left">Live Flows Count</th>
	       <td colspan=5><div class="pie-chart" id="topFlowsCount"></div></td>
	       </tr>
  </div>

        <script type='text/javascript'>
         window.onload=function() {

       do_pie("#topApplicationProtocols", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { mode: "sinceStartup", ifname: "]] print(_ifname) print [[" }, "", refresh);

       do_pie("#topApplicationBreeds", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { breed: "true", mode: "sinceStartup", ifname: "]] print(_ifname) print [[" }, "", refresh);

       do_pie("#topFlowsCount", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/iface_ndpi_stats.lua', { breed: "true", mode: "count", ifname: "]] print(_ifname) print [[" }, "", refresh);
    }

      </script><p>
  </table>
  ]]

   print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     ]]

   print("<thead><tr><th>Application Protocol</th><th>Total (Since Startup)</th><th>Percentage</th></tr></thead>\n")

   print ('<tbody id="if_stats_ndpi_tbody">\n')
   print ("</tbody>")
   print("</table>\n")
   print [[
<script>
function update_ndpi_table() {
  $.ajax({
    type: 'GET',
    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats_ndpi.lua',
    data: { ifname: "]] print(tostring(interface.name2id(ifstats.name))) print [[" },
    success: function(content) {
      $('#if_stats_ndpi_tbody').html(content);
      // Let the TableSorter plugin know that we updated the table
      $('#if_stats_ndpi_tbody').trigger("update");
    }
  });
}
update_ndpi_table();
]]

   --  Update interval ndpi table
   if not is_historical then print("setInterval(update_ndpi_table, 5000);") end

   print [[

</script>

]]

elseif(page == "historical") then
   rrd_file = _GET["rrd_file"]
   selected_epoch = _GET["epoch"]
   if(selected_epoch == nil) then selected_epoch = "" end
   topArray = makeTopStatsScriptsArray()

   if(rrd_file == nil) then rrd_file = "bytes.rrd" end

   drawRRD(ifstats.id, nil, rrd_file, _GET["graph_zoom"], url.."&page=historical", 1, _GET["epoch"], selected_epoch, topArray)
elseif (page == "packetdump") then
if (isAdministrator()) then
  dump_all_traffic = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_all_traffic')
  dump_status_tap = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_tap')
  dump_status_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_disk')
  dump_unknown_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_unknown_disk')
  dump_security_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_security_disk')

  if(dump_all_traffic == "true") then
    dump_all_traffic_checked = 'checked="checked"'
    dump_all_traffic_value = "false" -- Opposite
  else
    dump_all_traffic_checked = ""
    dump_all_traffic_value = "true" -- Opposite
  end
  if(dump_status_disk == "true") then
    dump_traffic_checked = 'checked="checked"'
    dump_traffic_value = "false" -- Opposite
  else
    dump_traffic_checked = ""
    dump_traffic_value = "true" -- Opposite
  end
  if(dump_unknown_disk == "true") then
    dump_unknown_checked = 'checked="checked"'
    dump_unknown_value = "false" -- Opposite
  else
    dump_unknown_checked = ""
    dump_unknown_value = "true" -- Opposite
  end
  if(dump_security_disk == "true") then
    dump_security_checked = 'checked="checked"'
    dump_security_value = "false" -- Opposite
  else
    dump_security_checked = ""
    dump_security_value = "true" -- Opposite
  end
  if(dump_status_tap == "true") then
    dump_traffic_tap_checked = 'checked="checked"'
    dump_traffic_tap_value = "false" -- Opposite
  else
    dump_traffic_tap_checked = ""
    dump_traffic_tap_value = "true" -- Opposite
  end

   print("<table class=\"table table-striped table-bordered\">\n")

   print("<tr><th width=30%>Packet Dump</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="host" value="]]
               print(ifstats.name)
               print('"><input type="hidden" name="dump_all_traffic" value="'..dump_all_traffic_value..'"><input type="checkbox" value="1" '..dump_all_traffic_checked..' onclick="this.form.submit();">  Dump All Traffic')
               print('</input>')
               print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
               print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%>Packet Dump To Disk</th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="host" value="]]
               print(ifstats.name)
               print('"><input type="hidden" name="dump_traffic_to_disk" value="'..dump_traffic_value..'"><input type="checkbox" value="1" '..dump_traffic_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Traffic To Disk')
               if (dump_traffic_checked ~= "") then
                 dumped = interface.getInterfacePacketsDumpedFile()
                 print(" - "..ternary(dumped, dumped, 0).." packets dumped")
               end
               print('</input>')
               print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
               print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="host" value="]]
               print(ifstats.name)
               print('"><input type="hidden" name="dump_unknown_to_disk" value="'..dump_unknown_value..'"><input type="checkbox" value="1" '..dump_unknown_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Unknown Traffic To Disk </input>')
               print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
               print('</form>')
   print("</td></tr>\n")

   print("<tr><th width=30%></th><td>")
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="host" value="]]
               print(ifstats.name)
               print('"><input type="hidden" name="dump_security_to_disk" value="'..dump_security_value..'"><input type="checkbox" value="1" '..dump_security_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> Dump Traffic To Disk On Security Alert </input>')
               print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
               print('</form>')
   print("</td></tr>\n")

   print("<tr><th>Packet Dump To Tap</th><td>")
   if(interface.getInterfaceDumpTapName() ~= "") then
   print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="host" value="]]
               print(ifstats.name)
               print('"><input type="hidden" name="dump_traffic_to_tap" value="'..dump_traffic_tap_value..'"><input type="checkbox" value="1" '..dump_traffic_tap_checked..' onclick="this.form.submit();"> <i class="fa fa-filter fa-lg"></i> Dump Traffic To Tap ')
	       print('('..interface.getInterfaceDumpTapName()..')')
               if (dump_traffic_tap_checked ~= "") then
                 dumped = interface.getInterfacePacketsDumpedTap()
                 print(" - "..ternary(dumped, dumped, 0).." packets dumped")
               end
	       print(' </input>')
               print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
               print('</form>')
   else
      print("Disabled. Please restart ntopng with --enable-taps")
end
   print("</td></tr>\n")
   print("<tr><th width=250>Sampling Rate</th>\n")
   print [[<td>]]
   if (dump_security_checked ~= "") then
   print[[<form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="if_name" value="]]
      print(ifstats.name)
      print [[">]]
      print('1 : <input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="sampling_rate" placeholder="" min="0" step="100" max="100000" value="]]
         srate = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate')
	 if(srate ~= nil and srate ~= "" and srate ~= "0") then print(srate) else print("1000") end
	 print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
<small>
    NOTE: Sampling rate is applied only when dumping packets caused by a security alert<br>
(e.g. a volumetric DDoS attack) and not to those hosts/flows that have been marked explicitly for dump.
</small>]]
  else
    print('Disabled. Enable packet dump on security alert.')
  end
  print[[
    </td></tr>
       ]]

   print("<tr><th colspan=2>Dump To Disk Parameters</th></tr>")
   print("<tr><th width=250>Max Packets per File</th>\n")
   print [[<td>
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="if_name" value="]]
      print(ifstats.name)
      print [[">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="max_pkts_file" placeholder="" min="0" step="1000" max="100000" value="]]
         max_pkts_file = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file')
	 if(max_pkts_file ~= nil and max_pkts_file ~= "") then
           print(max_pkts_file.."")
         else
           print(interface.getInterfaceDumpMaxPkts().."")
         end
	 print [["></input> pkts &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>Maximum number of packets to store on a pcap file before creating a new file.</small>
    </td></tr>
       ]]
   print("<tr><th width=250>Max Duration of File</th>\n")
   print [[<td>
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="if_name" value="]]
      print(ifstats.name)
      print [[">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="max_sec_file" placeholder="" min="0" step="60" max="100000" value="]]
         max_sec_file = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file')
	 if(max_sec_file ~= nil and max_sec_file ~= "") then
           print(max_sec_file.."")
         else
           print(interface.getInterfaceDumpMaxSec().."")
         end
	 print [["></input>
		  &nbsp;sec &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>Maximum pcap file duration before creating a new file.<br>NOTE: a dump file is closed when it reaches first the maximum size or duration specified.</small>
    </td></tr>
       ]]
   print("<tr><th width=250>Max Size of Dump Files</th>\n")
   print [[<td>
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="if_name" value="]]
      print(ifstats.name)
      print [[">]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="max_files" placeholder="" min="0" step="1" max="100000000" value="]]
         max_files = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_max_files')
	 if(max_files ~= nil and max_files ~= "") then
           print(tostring(tonumber(max_files)/1000000).."")
         else
           print(tostring(tonumber(interface.getInterfaceDumpMaxFiles())/1000000).."")
         end
	 print [["></input>
		  &nbsp; MB &nbsp;&nbsp;&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
    <small>Maximum size of created pcap files.<br>NOTE: total file size is checked daily and old dump files are automatically overwritten after reaching the threshold.</small>
    </td></tr>
      ]]
   print("</table>")
end
elseif(page == "config_historical") then
   --
   --  Historical Interface configuration page
   --

   historical_info = interface.getHistorical()

   print ('<div id="alert_placeholder"></div>')

   print('<form class="form-horizontal" role="form" method="get" id="conf_historical_form" action="'..ntop.getHttpPrefix()..'/lua/config_historical_interface.lua">')
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print[[
    <input type="hidden" name="from" value="" id="form_from">
    <input type="hidden" name="to" value="" id="form_to">
    <input type="hidden" name="id" value="" id="form_interface_id">
   ]]
   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th >Begin Date/Time</th><td colspan=2>")
   print [[
   <div class='input-group date' id='datetime_from'>
          <span class="input-group-addon"><span class="glyphicon glyphicon-calendar"></span></span>
          <input id='datetime_from_val' type='text' class="form-control" readonly/>
    </div>
    <span class="help-block">Specify the date and time from which to begin loading data.</span>
   ]]
   print("</td></tr>\n")

   print("<tr><th >End Date/Time</th><td colspan=2>")
   print [[
   <div class='input-group date' id='datetime_to'>
          <span class="input-group-addon"><span class="glyphicon glyphicon-calendar"></span></span>
          <input id='datetime_to_val' type='text' class="form-control" readonly/>
    </div>
    <span class="help-block">Specify the end of the loading interval.</span>
   ]]
   print("</td></tr>\n")

   print("<tr><th >Source Interface</th><td colspan=2>")
   print [[
   <div class="btn-group">
    ]]

   names = interface.getIfNames()

   current_name = historical_info["interface_name"]

   if(current_name ~= nil) then
      v = interface.name2id(current_name)

      key = 'ntopng.prefs.'..current_name..'.name'
      custom_name = ntop.getCache(key)

      if((custom_name ~= nil) and (custom_name ~= "")) then
	 current_name = custom_name
      else
	 current_name = getHumanReadableInterfaceName(tostring(v))
      end
   else
      v = ""
   end


   if(current_name == nil) then
      for k,v in pairs(names) do
	 if(v ~= "Historical") then
	    current_name = v
	    break
	 end
      end
   end

   print('<button id="interface_displayed"  value="' .. v .. '" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">' .. current_name.. '<span class="caret"></span></button>\n')

   print('    <ul class="dropdown-menu" id="interface_list">\n')

   for k,v in pairs(names) do
      key = 'ntopng.prefs.'..v..'.name'
      custom_name = ntop.getCache(key)
      --  io.write(v .. ' - ' ..interface.name2id(v).. '\n')
      if(v ~= "Historical") then
	 print('<li><a name="' ..interface.name2id(v)..'" >')
	 if((custom_name ~= nil) and (custom_name ~= "")) then
	    print(custom_name..'</a></li>')
	 else
	    interface.select(v)
	    ifstats = interface.getStats()

	    print(getHumanReadableInterfaceName(tostring(ifstats.id))..'</a></li>')
	 end
      end
   end

   print [[
            </ul>
          </div><!-- /btn-group -->
          <span class="help-block">Specify the interface from which to load the data (previously saved into your data directory).</span>
   ]]
   print("</td></tr>\n")

   print [[
<tr><th colspan=3 class="text-center">
      <button type="submit" class="btn btn-default">Load Historical Data</button>
      <button type="reset" class="btn btn-default">Reset Form</button>
</th></tr>
</table>
</form>
]]

   print [[
	 <form id="start_historical" class="form-horizontal" method="get" action="]]
   print (ntop.getHttpPrefix())
   print [[/lua/config_historical_interface.lua">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print [[
  <input type="hidden" name="from" value="" id="form_from">
  <input type="hidden" name="to" value="" id="form_to">
  <input type="hidden" name="id" value="" id="form_interface_id">
</form>
]]

   actual_time =os.time()
   mod = actual_time%300
   actual_time = actual_time - mod

   print [[
<script>

$('#interface_list li > a').click(function(e){
    $('#interface_displayed').html(this.innerHTML+' <span class="caret"></span>');
    $('#interface_displayed').val(this.name);
  });

$('#datetime_from').datetimepicker({
          minuteStepping:5,               //set the minute stepping
          language:'en',
          pick12HourFormat: false]]

   if((historical_info["from_epoch"] ~= nil) and (historical_info["from_epoch"] ~= 0) )then
      print (',\ndefaultDate: moment('..tonumber(historical_info["from_epoch"]*1000)..')')
   else
      print (',\ndefaultDate: moment('..tonumber(actual_time - 600) * 1000 ..')')
   end
   print (',\nmaxDate: "'.. os.date("%x", actual_time+ 86400) .. '"') -- One day more in order to enable today (library issue)

   print [[
        });

$('#datetime_to').datetimepicker({
          minuteStepping:5,               //set the minute stepping
          language:'en',
          pick12HourFormat: false]]

   if((historical_info["to_epoch"] ~= nil) and (historical_info["to_epoch"] ~= 0) )then
      print (',\ndefaultDate: moment('..tonumber(historical_info["to_epoch"]*1000)..')')
   else
      print (',\ndefaultDate: moment('..tonumber(actual_time - 300) * 1000 ..')')
   end

   print (',\nmaxDate: "'.. os.date("%x", actual_time+ 86400) .. '"') -- One day more in order to enable today (library issue)

   print [[
        });

  function check_date () {

    var submit = true;
    var from = $('#datetime_from_val').val();
    var to = $('#datetime_to_val').val();

    if(from == "" || from == NaN) {
       $('#datetime_from').addClass("has-error has-feedback");
       $('#alert_placeholder').html('<div class="alert alert-warning"><button type="button" class="close" data-dismiss="alert">x</button><strong> Invalid From:</strong> please select form date and time.</div>');
      return false;
    }

    if(to == ""|| to == NaN) {
       $('#datetime_to').addClass("has-error has-feedback");
      return false;
    }

    var from_epoch = moment(from);
    var from_unix = from_epoch.unix();
    var to_epoch = moment(to);
    var to_unix = to_epoch.unix();

    if((from_epoch > moment()) || (from_epoch.isValid() == false) ){
      $('#datetime_from').addClass("has-error has-feedback");
      $('#alert_placeholder').html('<div class="alert alert-warning"><button type="button" class="close" data-dismiss="alert">x</button><strong> Invalid From:</strong> please choose a valid date and time.</div>');
      submit = false;
    } else {
      $('#datetime_from').addClass("has-success has-feedback");
    }

    if((to_epoch > moment()) || (to_epoch.isValid() == false) ){
      $('#datetime_to').addClass("has-error has-feedback");
       $('#alert_placeholder').html('<div class="alert alert-warning"><button type="button" class="close" data-dismiss="alert">x</button><strong> Invalid To:</strong> please choose a valid date and time.</div>');
      submit = false;
    } else {
      $('#datetime_to').addClass("has-success has-feedback");
    }

    $('#form_from').val( from_unix);
    $('#form_to').val(to_unix );
    $('#form_interface_id').val($('#interface_displayed').text().trim());

    return submit;

  }


$( "#conf_historical_form" ).submit(function( event ) {
  var frm = $('#conf_historical_form');
  $('#alert_placeholder').html("");

  if(check_date()) {
    $.ajax({
      type: frm.attr('method'),
      url: frm.attr('action'),
      data: frm.serialize(),
      async: false,
      success: function (data) {
        var response = jQuery.parseJSON(data);
        if(response.result == "0") {
            $('#alert_placeholder').html('<div class="alert alert-success"><button type="button" class="close" data-dismiss="alert">x</button><strong>Well Done!</strong> Data loading process started successfully</div>');
        } else {
          $('#alert_placeholder').html('<div class="alert alert-warning"><button type="button" class="close" data-dismiss="alert">x</button><strong>Warning</strong> Please wait while loading data...<br></div>');
        }
      }
    });
   //window.setTimeout('window.location="index.lua"; ', 3000);
  }
  event.preventDefault();
});

</script>

 ]]
elseif(page == "shaping") then
shaper_id = _GET["shaper_id"]
max_rate = _GET["max_rate"]

if((shaper_id ~= nil) and (max_rate ~= nil)) then
   shaper_id = tonumber(shaper_id)
   max_rate = tonumber(max_rate)
   if((shaper_id >= 0) and (shaper_id < max_num_shapers)) then
      if(max_rate > 1048576) then max_rate = -1 end
      if(max_rate < -1) then max_rate = -1 end
      ntop.setHashCache(shaper_key, shaper_id, max_rate.."")
      interface.reloadShapers()
   end
end

print [[
<table class="table table-striped table-bordered">
 <tr><th width=10%>Shaper Id</th><th>Max Rate</th></tr>
]]


for i=0,max_num_shapers-1 do
   max_rate = ntop.getHashCache(shaper_key, i)
   if(max_rate == "") then max_rate = -1 end
   print('<tr><th style=\"text-align: center;\">'..i)

   print [[
	 </th><td><form class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="page" value="shaping">
	 <input type="hidden" name="if_name" value="]] print(ifname) print[[">
         <input type="hidden" name="shaper_id" value="]] print(i.."") print [[">]]

      if(isAdministrator()) then
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

	 print('<input type="number" name="max_rate" placeholder="" min="-1" step="1000" value="'.. max_rate ..'">&nbsp;Kbps')
	 print('&nbsp;<button type="submit" style="margin-top: 0; height: 26px" class="btn btn-default btn-xs">Set Rate Shaper '.. i ..'</button></form></td></tr>')
      else
	 print("</td></tr>")
      end
end
print [[</table>
  NOTES
<ul>
<li>Shaper 0 is the default shaper used for local hosts that have no shaper defined.
<li>Set max rate to:<ul><li>-1 for no shaping<li>0 for dropping all traffic</ul>
</ul>
]]

elseif(page == "filtering") then
   policy_key = "ntopng.prefs.".. ifid ..".l7_policy"

   -- ====================================

   if((_GET["new_vlan"] ~= nil) and (_GET["new_network"] ~= nil)) then
      network_key = _GET["new_network"].."@".._GET["new_vlan"]
      ntop.setHashCache(policy_key, network_key, "")
   end

   if(_GET["delete_network"] ~= nil) then
      ntop.delHashCache(policy_key, _GET["delete_network"])
   end

   net = _GET["network"]

   if(net ~= nil) then
      if(findString(net, "@") == nil) then
	 net = net.."@0"
      end

      if(ntop.getHashCache(policy_key, net) == "") then
	 ntop.setHashCache(policy_key, net, "")
      end
   end

   -- io.write(net.."\n")

   if((net ~= nil) and (_GET["blacklist"] ~= nil)) then
      ntop.setHashCache(policy_key, net, _GET["blacklist"])

      -- ****************************** 
      ingress_shaper_id = _GET["ingress_shaper_id"]
      if(ingress_shaper_id == nil) then ingress_shaper_id = 0 end
      key = "ntopng.prefs.".. ifid ..".l7_policy_ingress_shaper_id"
      ntop.setHashCache(key, net, ingress_shaper_id)
      -- ******************************
      egress_shaper_id = _GET["egress_shaper_id"]
      if(egress_shaper_id == nil) then egress_shaper_id = 0 end
      key = "ntopng.prefs.".. ifid ..".l7_policy_egress_shaper_id"
      ntop.setHashCache(key, net, egress_shaper_id)
      -- ******************************
      interface.reloadL7Rules()
   end

   any_net = "0.0.0.0/0@0"
   nets = ntop.getHashKeysCache(key)

   if((nets == nil) or (nets == "")) then
      ntop.setHashCache(policy_key, any_net, "")
      nets = ntop.getHashKeysCache(policy_key)
   end

   selected_network = net
   if(selected_network == nil) then
      selected_network = any_net
   end

   print [[
<div id="badnet" class="alert alert-danger" style="display: none">
    <strong>Warning</strong> Invalid VLAN/network specified.
</div>

  <form id="ndpiprotosform" action="]] print(ntop.getHttpPrefix()) print [[/lua/if_stats.lua" method="get">
  <input type=hidden name=page value=filtering>
  <table class="table table-striped table-bordered">
  <tr><th colspan=2>Manage Traffic Filtering Policies</th></tr>
  <tr><th width=10%>Network:</th><td> <select name="network" id="network">
]]
   selected_found = false
   if(nets ~= nil) then
      for k,v in pairsByKeys(nets, asc) do
	 if(k ~= "") then
	    print("\t<option")
	    if(k == selected_network) then print(" selected") end
	    print(">"..k.."</option>\n")
	    selected_found = true
	 end
      end
   end

print [[
</select>

<script>
$("#network").change(function() {
   document.location.href = "]] print(ntop.getHttpPrefix()) print [[/lua/if_stats.lua?page=filtering&network="+$("#network").val();
});
</script>
</form>
]]

if((selected_found == true)
      and (string.contains(selected_network, "/32")
	   or string.contains(selected_network, "/128"))) then
   nw = string.gsub(selected_network, "/32", "");
   nw = string.gsub(nw, "/128", "");
   print("&nbsp;[ <A HREF=/lua/host_details.lua?host="..nw.."><i class=\"fa fa-desktop fa-lg\"></i> Show Host</A> ] ")
end

print(' [ <A HREF=/lua/if_stats.lua?page=filtering&delete_network='..selected_network..'> <i class="fa fa-trash-o fa-lg"></i> Delete '.. selected_network ..'</A> ]')
print('</td></tr>')

-- ******************************************

print [[
<tr><th>Ingress Shaper Id</th><td>
<select name="ingress_shaper_id" id="ingress_shaper_id">
   ]]

   key = "ntopng.prefs.".. ifid ..".l7_policy_ingress_shaper_id"
   ingress_shaper_id = ntop.getHashCache(key, selected_network)
   if(ingress_shaper_id == "") then ingress_shaper_id = 0 else ingress_shaper_id = tonumber(ingress_shaper_id) end
   if((ingress_shaper_id < 0) or (ingress_shaper_id > max_num_shapers)) then ingress_shaper_id = 0 end

   for i=0,max_num_shapers-1 do
      print("<option value="..i)
      if(i == ingress_shaper_id) then print(" selected") end
      print(">"..i.." (")
      
      max_rate = ntop.getHashCache(shaper_key, i)

      print(maxRateToString(max_rate)..")</option>\n")
   end

print [[
</select><br>&nbsp;<br><small>Specify the max <u>ingress</u> transmission bandwidth to be associated to this network/host.</small></td></tr>
   ]]

-- ******************************************

print [[
<tr><th>Egress Shaper Id</th><td>
<select name="egress_shaper_id" id="egress_shaper_id">
   ]]

   key = "ntopng.prefs.".. ifid ..".l7_policy_egress_shaper_id"
   egress_shaper_id = ntop.getHashCache(key, selected_network)
   if(egress_shaper_id == "") then egress_shaper_id = 0 else egress_shaper_id = tonumber(egress_shaper_id) end
   if((egress_shaper_id < 0) or (egress_shaper_id > max_num_shapers)) then egress_shaper_id = 0 end

   for i=0,max_num_shapers-1 do
      print("<option value="..i)
      if(i == egress_shaper_id) then print(" selected") end
      print(">"..i.." (")

      max_rate = ntop.getHashCache(shaper_key, i)

      if((max_rate == nil) or (max_rate == "")) then max_rate = -1 end
      max_rate = tonumber(max_rate)
      if(max_rate == -1) then 
	 print("No Limit") 
      else
	 if(max_rate == 0) then 
	    print("Drop All Traffic") 
	 else
	    if(max_rate < 1024) then
	       print(max_rate.." Kbps")
	    else
	       local mr
	       mr = round(max_rate / 1024, 2)
	       print(mr.." Mbps")
	    end
	 end
      end
      print(")</option>\n")
   end

print [[
</select><br>&nbsp;<br><small>Specify the max <u>egress</u> transmission bandwidth to be associated to this network/host.</small></td></tr>
   ]]

-- ******************************************

print [[
<tr><td colspan=2>
  <input type=hidden id=blacklist name=blacklist value="">
  <select multiple="multiple" size="10" name="ndpiprotos">
]]

blacklist = { }
rules = ntop.getHashCache(policy_key, selected_network)
if(rules ~= nil) then
   local protos = split(rules, ",")
   for k,v in pairs(protos) do
      blacklist[v] = 1
   end
end

   protos = interface.getnDPIProtocols()

   for k,v in pairsByKeys(protos, asc) do
      if((k ~= "GRE")
	    and (k ~= "BGP")
	    and (k ~= "IGMP")
	    and (k ~= "IPP")
	    and (k ~= "IP_in_IP")
	    and (k ~= "OSPF")
	    and (k ~= "PPTP")
	    and (k ~= "SCTP")
	    and (k ~= "TFTP")
      ) then
	 print("<option value=\""..v.."\"")

	 --print(""..v.."<p>")
	 if(blacklist[v] ~= nil) then
	    print(" selected=\"selected\"")
	 end

	 print(">"..k.."</option>\n")
      end
   end

   print [[
    </select>
    </td></tr>
    <tr><td colspan=2><button type="submit" class="btn btn-default btn-block">Set Protocol Policy and Shaper</button></td></tr>

<script>
/* FIX - Check form */
    function validateAddNetworkForm() {
      if(is_network_mask($('#new_network').val())) {
         var vlan= $('#new_vlan').val();

         if((vlan >= 0) && (vlan <= 4095)) {
           $('#badnet').hide();
           return(true);
         } else {
           $('#badnet').show();
           return false;
         }
      } else {
       //alert("Invalid network specified");
      $('#badnet').show();
      return false;
     }
    }
</script>



<tr><th colspan=2>&nbsp;</th></tr>
<tr><th colspan=2>Add VLAN/Network To Filter</th></tr>

<tr><td colspan=2>
<form class="form-inline">
<div class="form-group">
<input type=hidden name=page value="filtering">
Network <input type="text" id="new_network" name="new_network" placeholder="Network/Mask" value="" width=32>
VLAN <input type="text" id="new_vlan" name="new_vlan" value="0" size=4>
<button type="submit" class="btn btn-default btn-sm" onclick="return validateAddNetworkForm();">Add VLAN/Network</button>
</div>
</form>
</td>

</tr>
 </table>
  </form>
  <script>
    var ndpiprotos1 = $('select[name="ndpiprotos"]').bootstrapDualListbox({
                        nonSelectedListLabel: 'White Listed Protocols for ]] print(selected_network) print [[',
                        selectedListLabel: 'Black Listed Protocols for ]] print(selected_network) print [[',
                        moveOnSelect: false
                      });
    $("#ndpiprotosform").submit(function() {
      // alert($('[name="ndpiprotos"]').val());
      $('#blacklist').val($('[name="ndpiprotos"]').val());
      return true;
    });
  </script>
]]

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

print("<script>\n")
print("var last_pkts  = " .. ifstats.stats_packets .. ";\n")
print("var last_drops = " .. ifstats.stats_drops .. ";\n")

if(ifstats["bridge.device_a"] ~= nil) then
   print("var a_to_b_last_in_pkts  = " .. ifstats["bridge.a_to_b.in_pkts"] .. ";\n")
   print("var a_to_b_last_out_pkts  = " .. ifstats["bridge.a_to_b.out_pkts"] .. ";\n")
   print("var a_to_b_last_filtered_pkts  = " .. ifstats["bridge.a_to_b.filtered_pkts"] .. ";\n")
   print("var b_to_a_last_in_pkts  = " .. ifstats["bridge.b_to_a.in_pkts"] .. ";\n")
   print("var b_to_a_last_out_pkts  = " .. ifstats["bridge.b_to_a.out_pkts"] .. ";\n")
   print("var b_to_a_last_filtered_pkts  = " .. ifstats["bridge.b_to_a.filtered_pkts"] .. ";\n")
end

print [[
setInterval(function() {
      $.ajax({
          type: 'GET',
          url: ']]
print (ntop.getHttpPrefix())
print [[/lua/network_load.lua',
          data: { ifname: "]] print(tostring(interface.name2id(ifstats.name))) print [[" },
          success: function(content) {
        var rsp = jQuery.parseJSON(content);
        $('#if_bytes').html(bytesToVolume(rsp.bytes));
        $('#if_pkts').html(addCommas(rsp.packets)+"]]


if(ifstats.type == "zmq") then print(" Flows\");") else print(" Pkts\");") end
print [[
        var pctg = 0;
        var drops = "";

        $('#pkts_trend').html(get_trend(last_pkts, rsp.packets));
        $('#drops_trend').html(get_trend(last_drops, rsp.drops));
        last_pkts = rsp.packets;
        last_drops = rsp.drops;

        if((rsp.packets+rsp.drops) > 0) { pctg = ((rsp.drops*100)/(rsp.packets+rsp.drops)).toFixed(2); }
        if(rsp.drops > 0) { drops = '<span class="label label-danger">'; }
        drops = drops + addCommas(rsp.drops)+" ]]

if(ifstats.type == "zmq") then print("Flows") else print("Pkts") end
print [[";

        if(pctg > 0)      { drops = drops + " [ "+pctg+" % ]"; }
        if(rsp.drops > 0) { drops = drops + '</span>';         }
        $('#if_drops').html(drops);
]]

if(ifstats["bridge.device_a"] ~= nil) then
print [[
   $('#a_to_b_in_pkts').html(addCommas(rsp["a_to_b_in_pkts"])+" Pkts "+get_trend(a_to_b_last_in_pkts, rsp["a_to_b_in_pkts"]));
   $('#a_to_b_out_pkts').html(addCommas(rsp["a_to_b_out_pkts"])+" Pkts "+get_trend(a_to_b_last_out_pkts, rsp["a_to_b_out_pkts"]));
   $('#a_to_b_filtered_pkts').html(addCommas(rsp["a_to_b_filtered_pkts"])+" Pkts "+get_trend(a_to_b_last_filtered_pkts, rsp["a_to_b_filtered_pkts"]));
   $('#b_to_a_in_pkts').html(addCommas(rsp["b_to_a_in_pkts"])+" Pkts "+get_trend(b_to_a_last_in_pkts, rsp["b_to_a_in_pkts"]));
   $('#b_to_a_out_pkts').html(addCommas(rsp["b_to_a_out_pkts"])+" Pkts "+get_trend(b_to_a_last_out_pkts, rsp["b_to_a_out_pkts"]));
   $('#b_to_a_filtered_pkts').html(addCommas(rsp["b_to_a_filtered_pkts"])+" Pkts "+get_trend(b_to_a_last_filtered_pkts, rsp["b_to_a_filtered_pkts"]));

   a_to_b_last_in_pkts = rsp["a_to_b_in_pkts"];
   a_to_b_last_out_pkts = rsp["a_to_b_out_pkts"];
   a_to_b_last_filtered_pkts = rsp["a_to_b_filtered_pkts"];
   b_to_a_last_in_pkts = rsp["b_to_a_in_pkts"];
   b_to_a_last_out_pkts = rsp["b_to_a_out_pkts"];
   b_to_a_last_filtered_pkts = rsp["b_to_a_filtered_pkts"];

]]
end

print [[
           }
               });
       }, 3000)

</script>

]]

print [[
	 <script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/jquery.tablesorter.js"></script>
<script>
$(document).ready(function()
    {
        $("#myTable").tablesorter();
    }
);
</script>
]]
