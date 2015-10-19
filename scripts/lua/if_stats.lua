--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
require "graph_utils"
require "alert_utils"
require "db_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

page = _GET["page"]
if_name = _GET["if_name"]

if(if_name == nil) then if_name = ifname end

max_num_shapers = 10
interface.select(if_name)
ifid = interface.name2id(ifname)
shaper_key = "ntopng.prefs."..ifid..".shaper_max_rate"
ifstats = aggregateInterfaceStats(interface.getStats())

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
   if(tonumber(_GET["sampling_rate"]) ~= nil) then
     page = "packetdump"
     val = ternary(_GET["sampling_rate"] ~= "0", _GET["sampling_rate"], "1")
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_sampling_rate', val)
     interface.loadDumpPrefs()
   end
end
if(_GET["max_pkts_file"] ~= nil and _GET["csrf"] ~= nil) then
   if(tonumber(_GET["max_pkts_file"]) ~= nil) then
     page = "packetdump"
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_pkts_file',_GET["max_pkts_file"])
     interface.loadDumpPrefs()
   end
end
if(_GET["max_sec_file"] ~= nil and _GET["csrf"] ~= nil) then
   if(tonumber(_GET["max_sec_file"]) ~= nil) then
     page = "packetdump"
     ntop.setCache('ntopng.prefs.'..ifstats.name..'.dump_max_sec_file',_GET["max_sec_file"])
     interface.loadDumpPrefs()
   end
end
if(_GET["max_files"] ~= nil and _GET["csrf"] ~= nil) then
   if(tonumber(_GET["max_files"]) ~= nil) then
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
print('\n<script>var refresh = 3000 /* ms */;</script>\n')

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
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i></a></li>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i></a></li>")
end

-- Disable Packets and Protocols tab in case of the number of packets is equal to 0
if((ifstats ~= nil) and (ifstats.packets > 0)) then
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

if(ntop.exists(rrdname) and not is_historical) then
   if(page == "historical") then
      print("<li class=\"active\"><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   else
      print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end

if(not(ifstats.view)) then
   if(isAdministrator()) then
      if(page == "packetdump") then
	 print("<li class=\"active\"><a href=\""..url.."&page=packetdump\"><i class=\"fa fa-hdd-o fa-lg\"></i></a></li>")
      else
	 print("<li><a href=\""..url.."&page=packetdump\"><i class=\"fa fa-hdd-o fa-lg\"></i></a></li>")
      end
   end
end

if(isAdministrator()) then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-warning fa-lg\"></i></a></li>\n")
   else
      print("\n<li><a href=\""..url.."&page=alerts\"><i class=\"fa fa-warning fa-lg\"></i></a></li>")
   end
end

if(isAdministrator()) then
   if(page == "config") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")
   else
      print("\n<li><a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
   end
end

if(ifstats.inline) then
   if(page == "filtering") then
      print("<li class=\"active\"><a href=\""..url.."&page=filtering\">Traffic Filtering</a></li>")
   else
      print("<li><a href=\""..url.."&page=filtering\">Traffic Filtering</a></li>")
   end

   if(page == "shaping") then
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
   print("<tr><th width=15%>Id</th><td colspan=6>" .. ifstats.id .. " ")
   print("</td></tr>\n")
   print("<tr><th width=250>State</th><td colspan=6>")
   state = toggleTableButton("", "", "Active", "1","primary", "Paused", "0","primary", "toggle_local", "ntopng.prefs."..if_name.."_not_idle")
   
   if(state == "0") then
      on_state = true
   else
      on_state = false
   end
   
   interface.setInterfaceIdleState(on_state)   
   print("</td></tr>\n")

   print("<tr><th width=250>Name</th><td colspan=2>" .. ifstats.name .. "</td>\n")

   if(ifstats.name ~= nil) then
      label = getInterfaceNameAlias(ifstats.name)
      if(not isAdministrator()) then
	 print("<td>")
      else
	 print("<td colspan=6>")
      end

      print [[
    <form class="form-inline" style="margin-bottom: 0px;">
       <input type="hidden" name="if_name" value="]]
      print(ifstats.name)
      print [[">]]

      if(isAdministrator()) then
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print [[
       <input type="text" class=form-control name="custom_name" placeholder="Custom Name" value="]]
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

   print("<tr><th width=250>Speed</th><td colspan=2>" .. maxRateToString(ifstats.speed*1000) .. "</td><th>MTU</th><td colspan=3>"..ifstats.mtu.." bytes</td></tr>\n")

   if(ifstats.ip_addresses ~= "") then
      tokens = split(ifstats.ip_addresses, ",")

      if(tokens ~= nil) then
	 print("<tr><th width=250>IP Address</th><td colspan=5>")

	 for _,s in pairs(tokens) do
	    t = string.split(s, "/")
	    host = interface.getHostInfo(t[1])
	    
	    if(host ~= nil) then
	       print("<li><A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..t[1]..">".. t[1].."</A>\n")
	    else
	       print("<li>".. t[1].."\n")
	    end
	 end

	 print("</td></tr>")
      end
   end

   if(ifstats.name ~= ifstats.description) then
      print("<tr><th>Description</th><td colspan=6>" .. ifstats.description .. "</td></tr>\n")
   end

   print("<tr><th>Family </th><td colspan=6>")
   if(ifstats.isView == true) then print("<i class=\"fa fa-eye\"></i> ") end

   print(ifstats.type)
   if(ifstats.inline) then
      print(" In-Path Interface (Bump in the Wire)")
      elseif(ifstats.isView == true) then
      print(" (Aggregated Interface View)")
   end
   print("</td></tr>\n")

   if(ifstats["pkt_dumper"] ~= nil) then
      print("<tr><th rowspan=2>Packet Dumper</th><th colspan=4>Dumped Packets</th><th>Dumped Files</th></tr>\n")
      print("<tr><td colspan=2><div id=dumped_pkts>".. formatValue(ifstats["pkt_dumper"]["num_dumped_pkts"]) .."</div></td>")
      print("<td colspan=2><div id=dumped_files>".. formatValue(ifstats["pkt_dumper"]["num_dumped_files"]) .."</div></td></tr>\n")
   end

   label = "Pkts"

print[[ <tr><th colspan=1>Traffic Breakdown</th><td colspan=6><div class="pie-chart" id="ifaceTrafficBreakdown"></div></td></tr>

        <script type='text/javascript'>
	       window.onload=function() {
				   do_pie("#ifaceTrafficBreakdown", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_local_stats.lua', { ifname: ]] print(ifstats.id .. " }, \"\", refresh); \n")
      print ("}\n</script>\n")

   print("<tr><th colspan=7>Ingress Traffic</th></tr>\n")
   print("<tr><th>Received Traffic</th><td width=20%><span if=if_bytes_1>"..bytesToSize(ifstats.bytes).."</span> [<span id=if_pkts>".. formatValue(ifstats.packets) .. " ".. label .."</span>] ")
   print("<span id=pkts_trend></span></td><th width=20%>Dropped Packets</th><td width=20%><span id=if_drops>")

   if(ifstats.drops > 0) then print('<span class="label label-danger">') end
   print(formatValue(ifstats.drops).. " " .. label)

   if((ifstats.packets+ifstats.drops) > 0) then
      local pctg = round((ifstats.drops*100)/(ifstats.packets+ifstats.drops), 2)
      if(pctg > 0) then print(" [ " .. pctg .. " % ] ") end
   end

   if(ifstats.drops > 0) then print('</span>') end
   print("</span>  <span id=drops_trend></span></td><td colspan=3>&nbsp;</td></tr>\n")

   if(ifstats["bridge.device_a"] ~= nil) then
      print("<tr><th colspan=7>Bridged Traffic</th></tr>\n")
      print("<tr><th nowrap>Interface Direction</th><th nowrap>Ingress Packets</th><th nowrap>Egress Packets</th><th nowrap>Shaped Packets</th><th nowrap>Filtered Packets</th><th nowrap>Send Error</th><th nowrap>Buffer Full</th></tr>\n")
      print("<tr><th>".. ifstats["bridge.device_a"] .. " <i class=\"fa fa-arrow-right\"></i> ".. ifstats["bridge.device_b"] .."</th><td><span id=a_to_b_in_pkts>".. formatPackets(ifstats["bridge.a_to_b.in_pkts"]) .."</span> <span id=a_to_b_in_pps></span></td>")
      print("<td><span id=a_to_b_out_pkts>".. formatPackets(ifstats["bridge.a_to_b.out_pkts"]) .."</span> <span id=a_to_b_out_pps></span></td>")
      print("<td><span id=a_to_b_shaped_pkts>".. formatPackets(ifstats["bridge.a_to_b.shaped_pkts"]) .."</span></td>")
      print("<td><span id=a_to_b_filtered_pkts>".. formatPackets(ifstats["bridge.a_to_b.filtered_pkts"]) .."</span></td>")

      print("<td><span id=a_to_b_num_pkts_send_error>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=a_to_b_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.a_to_b.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")

      print("<tr><th>".. ifstats["bridge.device_b"] .. " <i class=\"fa fa-arrow-right\"></i> ".. ifstats["bridge.device_a"] .."</th><td><span id=b_to_a_in_pkts>".. formatPackets(ifstats["bridge.b_to_a.in_pkts"]) .."</span> <span id=b_to_a_in_pps></span></td>")
      print("<td><span id=b_to_a_out_pkts>"..formatPackets( ifstats["bridge.b_to_a.out_pkts"]) .."</span> <span id=b_to_a_out_pps></span></td>")
      print("<td><span id=b_to_a_shaped_pkts>".. formatPackets(ifstats["bridge.b_to_a.shaped_pkts"]) .."</span></td>")
      print("<td><span id=b_to_a_filtered_pkts>".. formatPackets(ifstats["bridge.b_to_a.filtered_pkts"]) .."</span></td>")

      print("<td><span id=b_to_a_num_pkts_send_error>".. formatPackets(ifstats["bridge.b_to_a.num_pkts_send_error"]) .."</span></td>")
      print("<td><span id=b_to_a_num_pkts_send_buffer_full>".. formatPackets(ifstats["bridge.b_to_a.num_pkts_send_buffer_full"]) .."</span></td>")

      print("</tr>\n")
   end

   print [[
   <tr><td colspan=7> <small> <b>NOTE</b>:<p>In ethernet networks, each packet has an <A HREF=https://en.wikipedia.org/wiki/Ethernet_frame>overhead of 24 bytes</A> [preamble (7 bytes), start of frame (1 byte), CRC (4 bytes), and <A HREF=http://en.wikipedia.org/wiki/Interframe_gap>IFG</A> (12 bytes)]. Such overhead needs to be accounted to the interface traffic, but it is not added to the traffic being exchanged between IP addresses. This is because such data contributes to interface load, but it cannot be accounted in the traffic being exchanged by hosts, and thus expect little discrepancies between host and interface traffic values. </small> </td></tr>
   ]]

   print("</table>\n")
elseif((page == "packets")) then
   print [[
      <table class="table table-bordered table-striped">
        <tr><th class="text-left">Size Distribution</th><td colspan=5><div class="pie-chart" id="sizeDistro"></div></td></tr>
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

--fc = interface.getnDPIFlowsCount()
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
print("setInterval(update_ndpi_table, 5000);")

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
elseif(page == "packetdump") then
if(isAdministrator()) then
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
               if(dump_traffic_checked ~= "") then
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
               if(dump_traffic_tap_checked ~= "") then
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
   if(dump_security_checked ~= "") then
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
elseif(page == "alerts") then
local if_name = ifstats.name
local ifname_clean = string.gsub(ifname, "/", "_")
local tab = _GET["tab"]

if(tab == nil) then tab = alerts_granularity[1][1] end

print [[ <ul class="nav nav-tabs">
]]

for _,e in pairs(alerts_granularity) do
   k = e[1]
   l = e[2]

   if(k == tab) then print("\t<li class=active>") else print("\t<li>") end
   print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?if_name="..if_name.."&page=alerts&tab="..k.."\">"..l.."</a></li>\n")
end

-- Before doing anything we need to check if we need to save values

vals = { }
alerts = ""
to_save = false

if((_GET["to_delete"] ~= nil) and (_GET["SaveAlerts"] == nil)) then
   delete_interface_alert_configuration(ifname_clean)
   alerts = nil
else
   for k,_ in pairs(alert_functions_description) do
      value    = _GET["value_"..k]
      operator = _GET["operator_"..k]

      if((value ~= nil) and (operator ~= nil)) then
	 --io.write("\t"..k.."\n")
	 to_save = true
	 value = tonumber(value)
	 if(value ~= nil) then
	    if(alerts ~= "") then alerts = alerts .. "," end
	    alerts = alerts .. k .. ";" .. operator .. ";" .. value
	 end
      end
   end

   --print(alerts)

   if(to_save) then
      if(alerts == "") then
	 ntop.delHashCache("ntopng.prefs.alerts_"..tab, ifname_clean)
      else
	 ntop.setHashCache("ntopng.prefs.alerts_"..tab, ifname_clean, alerts)
      end
   else
      alerts = ntop.getHashCache("ntopng.prefs.alerts_"..tab, ifname_clean)
   end
end

if(alerts ~= nil) then
   --print(alerts)
   --tokens = string.split(alerts, ",")
   tokens = split(alerts, ",")

   --print(tokens)
   if(tokens ~= nil) then
      for _,s in pairs(tokens) do
	 t = string.split(s, ";")
	 --print("-"..t[1].."-")
	 if(t ~= nil) then vals[t[1]] = { t[2], t[3] } end
      end
   end
end

if(tab == "alerts_preferences") then
   suppressAlerts = ntop.getHashCache("ntopng.prefs.alerts", ifname_clean)
   if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
      alerts_checked = 'checked="checked"'
      alerts_value = "false" -- Opposite
   else
      alerts_checked = ""
      alerts_value = "true" -- Opposite
   end

else
   print [[
    </ul>
    <table id="user" class="table table-bordered table-striped" style="clear: both"> <tbody>
    <tr><th width=20%>Alert Function</th><th>Threshold</th></tr>


   <form>
    <input type=hidden name=page value=alerts>
   ]]

   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print("<input type=hidden name=host value=\""..if_name.."\">\n")
   print("<input type=hidden name=tab value="..tab..">\n")

   for k,v in pairsByKeys(alert_functions_description, asc) do
      print("<tr><th>"..k.."</th><td>\n")
      print("<select name=operator_".. k ..">\n")
      if((vals[k] ~= nil) and (vals[k][1] == "gt")) then print("<option selected=\"selected\"") else print("<option ") end
      print("value=\"gt\">&gt;</option>\n")

      if((vals[k] ~= nil) and (vals[k][1] == "eq")) then print("<option selected=\"selected\"") else print("<option ") end
      print("value=\"eq\">=</option>\n")

      if((vals[k] ~= nil) and (vals[k][1] == "lt")) then print("<option selected=\"selected\"") else print("<option ") end
      print("value=\"lt\">&lt;</option>\n")
      print("</select>\n")
      print("<input type=text class=form-control name=\"value_"..k.."\" value=\"")
      if(vals[k] ~= nil) then print(vals[k][2]) end
      print("\">\n\n")
      print("<br><small>"..v.."</small>\n")
      print("</td></tr>\n")
   end

   print [[
   <tr><th colspan=2  style="text-align: center; white-space: nowrap;" >

   <input type="submit" class="btn btn-primary" name="SaveAlerts" value="Save Configuration">

   <a href="#myModal" role="button" class="btn" data-toggle="modal">[ <i type="submit" class="fa fa-trash-o"></i> Delete All Interface Configured Alerts ]</button></a>
   <!-- Modal -->
   <div class="modal fade" id="myModal" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
     <div class="modal-dialog">
       <div class="modal-content">
         <div class="modal-header">
       <button type="button" class="close" data-dismiss="modal" aria-hidden="true">X</button>
       <h3 id="myModalLabel">Confirm Action</h3>
     </div>
     <div class="modal-body">
   	 <p>Do you really want to delete all configured alerts for interface ]] print(if_name) print [[?</p>
     </div>
     <div class="modal-footer">
       <form class=form-inline style="margin-bottom: 0px;" method=get action="#"><input type=hidden name=to_delete value="__all__">
   ]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print [[    <button class="btn btn-default" data-dismiss="modal" aria-hidden="true">Close</button>
       <button class="btn btn-primary btn-xs" type="submit">Delete All</button>

     </div>
   </form>
   </div>
   </div>

   </th> </tr>



   </tbody> </table>
   ]]
end
elseif(page == "config") then
local if_name = ifstats.name
local ifname_clean = string.gsub(ifname, "/", "_")

   if(isAdministrator()) then
      trigger_alerts = _GET["trigger_alerts"]
      if(trigger_alerts ~= nil) then
         if(trigger_alerts == "true") then
	    ntop.delHashCache("ntopng.prefs.alerts", "iface_"..ifname_clean)
         else
	    ntop.setHashCache("ntopng.prefs.alerts", "iface_"..ifname_clean, trigger_alerts)
         end
      end
   end

   print("<table class=\"table table-striped table-bordered\">\n")
       suppressAlerts = ntop.getHashCache("ntopng.prefs.alerts", ifname_clean)
       if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
	  alerts_checked = 'checked="checked"'
	  alerts_value = "false" -- Opposite
       else
	  alerts_checked = ""
	  alerts_value = "true" -- Opposite
       end

       print [[
	    <tr><th>Interface Alerts</th><td nowrap>
	    <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	    <input type="hidden" name="tab" value="alerts_preferences">
	    <input type="hidden" name="host" value="]]

         print(if_name)
         print('"><input type="hidden" name="trigger_alerts" value="'..alerts_value..'"><input type="checkbox" value="1" '..alerts_checked..' onclick="this.form.submit();"> <i class="fa fa-exclamation-triangle fa-lg"></i> Trigger alerts for interface '..if_name..'</input>')
         print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
         print('<input type="hidden" name="page" value="config">')
         print('</form>')
         print('</td>')
	 print [[</tr>]]

    print("</table>")
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

	 print('<input class=form-control type="number" name="max_rate" placeholder="" min="-1" value="'.. max_rate ..'">&nbsp;Kbps')
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
      -- We need to check if this network is local or not
      network_key = _GET["new_network"].."@".._GET["new_vlan"]
      ntop.setHashCache(policy_key, network_key, "")
   end

   if(_GET["delete_network"] ~= nil) then
      ntop.delHashCache(policy_key, _GET["delete_network"])
   end

   net = _GET["network"]

   any_net = "0.0.0.0/0@0"  

   nets = ntop.getHashKeysCache(key, any_net)

   if((nets == nil) or (nets == "")) then
      nets = ntop.getHashKeysCache(policy_key)
   end
   
   if((net == nil) and (nets ~= nil)) then
      -- If there is not &network= parameter then use the first network available
      for k,v in pairsByKeys(nets, asc) do
	 net = k
	 break
      end
   end

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
      print(maxRateToString(tonumber(max_rate)))
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
if((rules ~= nil) and (string.len(rules) > 0)) then
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
    <tr><td colspan=2><button type="submit" class="btn btn-primary btn-block">Set Protocol Policy and Shaper</button></td></tr>

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
Local Network :
<select name="new_network">
    ]]


 locals = ntop.getLocalNetworks()
 for s,_ in pairs(locals) do
    print('<option value="'..s..'">'..s..'</option>\n')
 end
print [[
</select>
VLAN <input type="text" class=form-control id="new_vlan" name="new_vlan" value="0" size=4>
<button type="submit" class="btn btn-primary btn-sm" onclick="return validateAddNetworkForm();">Add VLAN/Network</button>
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
print("var last_pkts  = " .. ifstats.packets .. ";\n")
print("var last_drops = " .. ifstats.drops .. ";\n")

if(ifstats["bridge.device_a"] ~= nil) then
   print("var last_epoch  = 0;\n")
   print("var a_to_b_last_in_pkts  = " .. ifstats["bridge.a_to_b.in_pkts"] .. ";\n")
   print("var a_to_b_last_out_pkts  = " .. ifstats["bridge.a_to_b.out_pkts"] .. ";\n")
   print("var a_to_b_last_in_bytes  = " .. ifstats["bridge.a_to_b.in_bytes"] .. ";\n")
   print("var a_to_b_last_out_bytes  = " .. ifstats["bridge.a_to_b.out_bytes"] .. ";\n")
   print("var a_to_b_last_filtered_pkts  = " .. ifstats["bridge.a_to_b.filtered_pkts"] .. ";\n")
   print("var a_to_b_last_shaped_pkts  = " .. ifstats["bridge.a_to_b.shaped_pkts"] .. ";\n")
   print("var a_to_b_last_num_pkts_send_buffer_full  = " .. ifstats["bridge.a_to_b.num_pkts_send_buffer_full"] .. ";\n")
   print("var a_to_b_last_num_pkts_send_error  = " .. ifstats["bridge.a_to_b.num_pkts_send_error"] .. ";\n")

   print("var b_to_a_last_in_pkts  = " .. ifstats["bridge.b_to_a.in_pkts"] .. ";\n")
   print("var b_to_a_last_out_pkts  = " .. ifstats["bridge.b_to_a.out_pkts"] .. ";\n")
   print("var b_to_a_last_in_bytes  = " .. ifstats["bridge.b_to_a.in_bytes"] .. ";\n")
   print("var b_to_a_last_out_bytes  = " .. ifstats["bridge.b_to_a.out_bytes"] .. ";\n")
   print("var b_to_a_last_filtered_pkts  = " .. ifstats["bridge.b_to_a.filtered_pkts"] .. ";\n")
   print("var b_to_a_last_shaped_pkts  = " .. ifstats["bridge.b_to_a.shaped_pkts"] .. ";\n")
   print("var b_to_a_last_num_pkts_send_buffer_full  = " .. ifstats["bridge.b_to_a.num_pkts_send_buffer_full"] .. ";\n")
   print("var b_to_a_last_num_pkts_send_error  = " .. ifstats["bridge.b_to_a.num_pkts_send_error"] .. ";\n")  
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
	var v = bytesToVolume(rsp.bytes);
        $('#if_bytes').html(v);
        $('#if_bytes').html(v);
        $('#if_pkts').html(addCommas(rsp.packets)+"]]


print(" Pkts\");")
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

print("Pkts")
print [[";

        if(pctg > 0)      { drops = drops + " [ "+pctg+" % ]"; }
        if(rsp.drops > 0) { drops = drops + '</span>';         }
        $('#if_drops').html(drops);
]]

if(ifstats["bridge.device_a"] ~= nil) then
print [[
   epoch_diff = rsp["epoch"]-last_epoch;
   $('#a_to_b_in_pkts').html(addCommas(rsp["a_to_b_in_pkts"])+" Pkts "+get_trend(a_to_b_last_in_pkts, rsp["a_to_b_in_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) { 
      /* pps = (rsp["a_to_b_in_pkts"]-a_to_b_last_in_pkts) / epoch_diff; */
      bps = 8*(rsp["a_to_b_in_bytes"]-a_to_b_last_in_bytes) / epoch_diff;
      $('#a_to_b_in_pps').html(" ["+fbits(bps)+"]"); 
    }
   $('#a_to_b_out_pkts').html(addCommas(rsp["a_to_b_out_pkts"])+" Pkts "+get_trend(a_to_b_last_out_pkts, rsp["a_to_b_out_pkts"]));   
   if((last_epoch > 0) && (epoch_diff > 0)) {
      /* pps = (rsp["a_to_b_out_pkts"]-a_to_b_last_out_pkts) / epoch_diff; */
      bps = 8*(rsp["a_to_b_out_bytes"]-a_to_b_last_out_bytes) / epoch_diff;
      $('#a_to_b_out_pps').html(" ["+fbits(bps)+"]");
    }

   $('#a_to_b_filtered_pkts').html(addCommas(rsp["a_to_b_filtered_pkts"])+" Pkts "+get_trend(a_to_b_last_filtered_pkts, rsp["a_to_b_filtered_pkts"]));
   $('#a_to_b_shaped_pkts').html(addCommas(rsp["a_to_b_shaped_pkts"])+" Pkts "+get_trend(a_to_b_last_shaped_pkts, rsp["a_to_b_shaped_pkts"]));
   $('#a_to_b_num_pkts_send_error').html(addCommas(rsp["a_to_b_num_pkts_send_error"])+" Pkts "+get_trend(a_to_b_last_num_pkts_send_error, rsp["a_to_b_num_pkts_send_error"]));
   $('#a_to_b_num_pkts_send_buffer_full').html(addCommas(rsp["a_to_b_num_pkts_send_buffer_full"])+" Pkts "+get_trend(a_to_b_last_num_pkts_send_buffer_full, rsp["a_to_b_num_pkts_send_buffer_full"]));

   $('#b_to_a_in_pkts').html(addCommas(rsp["b_to_a_in_pkts"])+" Pkts "+get_trend(b_to_a_last_in_pkts, rsp["b_to_a_in_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) { 
      /* pps = (rsp["b_to_a_in_pkts"]-b_to_a_last_in_pkts) / epoch_diff; */
      bps = 8*(rsp["b_to_a_in_bytes"]-b_to_a_last_in_bytes) / epoch_diff;
      $('#b_to_a_in_pps').html(" ["+fbits(bps)+"]"); 
    }
   $('#b_to_a_out_pkts').html(addCommas(rsp["b_to_a_out_pkts"])+" Pkts "+get_trend(b_to_a_last_out_pkts, rsp["b_to_a_out_pkts"]));
   if((last_epoch > 0) && (epoch_diff > 0)) {
      /* pps = (rsp["b_to_a_out_pkts"]-b_to_a_last_out_pkts) / epoch_diff; */
      bps = 8*(rsp["b_to_a_out_bytes"]-b_to_a_last_out_bytes) / epoch_diff;
      $('#b_to_a_out_pps').html(" ["+fbits(bps)+"]");
    }
   $('#b_to_a_filtered_pkts').html(addCommas(rsp["b_to_a_filtered_pkts"])+" Pkts "+get_trend(b_to_a_last_filtered_pkts, rsp["b_to_a_filtered_pkts"]));
   $('#b_to_a_shaped_pkts').html(addCommas(rsp["b_to_a_shaped_pkts"])+" Pkts "+get_trend(b_to_a_last_shaped_pkts, rsp["b_to_a_shaped_pkts"]));
   $('#b_to_a_num_pkts_send_error').html(addCommas(rsp["b_to_a_num_pkts_send_error"])+" Pkts "+get_trend(b_to_a_last_num_pkts_send_error, rsp["b_to_a_num_pkts_send_error"]));
   $('#b_to_a_num_pkts_send_buffer_full').html(addCommas(rsp["b_to_a_num_pkts_send_buffer_full"])+" Pkts "+get_trend(b_to_a_last_num_pkts_send_buffer_full, rsp["b_to_a_num_pkts_send_buffer_full"]));

   a_to_b_last_in_pkts = rsp["a_to_b_in_pkts"];
   a_to_b_last_out_pkts = rsp["a_to_b_out_pkts"];
   a_to_b_last_in_bytes = rsp["a_to_b_in_bytes"];
   a_to_b_last_out_bytes = rsp["a_to_b_out_bytes"];
   a_to_b_last_filtered_pkts = rsp["a_to_b_filtered_pkts"];
   a_to_b_last_shaped_pkts = rsp["a_to_b_shaped_pkts"];
   a_to_b_last_num_pkts_send_buffer_full = rsp["a_to_b_num_pkts_send_buffer_full"];
   a_to_b_last_num_pkts_send_error = rsp["a_to_b_num_pkts_send_error"];

   b_to_a_last_in_pkts = rsp["b_to_a_in_pkts"];
   b_to_a_last_out_pkts = rsp["b_to_a_out_pkts"];
   b_to_a_last_in_bytes = rsp["b_to_a_in_bytes"];
   b_to_a_last_out_bytes = rsp["b_to_a_out_bytes"];
   b_to_a_last_filtered_pkts = rsp["b_to_a_filtered_pkts"];
   b_to_a_last_shaped_pkts = rsp["b_to_a_shaped_pkts"];
   b_to_a_last_num_pkts_send_buffer_full = rsp["b_to_a_num_pkts_send_buffer_full"];
   b_to_a_last_num_pkts_send_error = rsp["b_to_a_num_pkts_send_error"];
   last_epoch = rsp["epoch"];
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
