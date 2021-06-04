--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local snmp_utils
local snmp_location
if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   snmp_utils = require "snmp_utils"
   snmp_location = require "snmp_location"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local alert_utils = require "alert_utils"
require "historical_utils"
require "discover_utils"
require "mac_utils"

local page_utils = require("page_utils")

local have_nedge = ntop.isnEdge()

local info = ntop.getInfo()
local os_utils = require "os_utils"
local discover = require "discover_utils"
local host_pools = require "host_pools"
local template = require "template_utils"
local page        = _GET["page"]
local host_info = url2hostinfo(_GET)

local mac         = host_info["host"]
local pool_id

interface.select(ifname)

-- Instantiate host pools
local host_pools_instance = host_pools:create()

local ifstats = interface.getStats()
local ifId = ifstats.id
local prefs = ntop.getPrefs()

if isAdministrator() then
   if (_SERVER["REQUEST_METHOD"] == "POST") and (page == "config") then
      setHostAltName(mac, _POST["custom_name"])

      local devtype = tonumber(_POST["device_type"])
      setCustomDeviceType(mac, devtype)
      ntop.setMacDeviceType(mac, devtype, true --[[ overwrite ]])

      pool_id = _POST["pool"]
      host_pools_instance:bind_member(mac, tonumber(pool_id))
   end
end

if (pool_id == nil) then
   local cur_pool = host_pools_instance:get_pool_by_member(mac)

   if cur_pool then
      pool_id = cur_pool["pool_id"]
   else
      pool_id = host_pools_instance.DEFAULT_POOL_ID
   end
end

local vlanId      = host_info["vlan"]
local label       = mac2label(mac)

local devicekey = hostinfo2hostkey(host_info)

if(vlanId == nil) then vlanId = 0 end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.devices)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(mac == nil) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i>" .. " " .. i18n("mac_details.mac_parameter_missing_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

if isAdministrator() then
   if _POST["action"] == "reset_stats" then
      if interface.resetMacStats(mac) then
         print("<div class=\"alert alert alert-dismissable alert-success\">")
         print(i18n("mac_details.reset_stats_in_progress"))
         print([[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]])
         print("</div>")
      end
   end
end

local mac_info = interface.getMacInfo(mac)

-- tprint(mac_info)

local only_historical = (mac_info == nil) and (page == "historical")

if(mac_info == nil) and not only_historical then
   print('<div class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle fa-lg fa-ntopng-warning"></i>'..' '..i18n("mac_details.mac_cannot_be_found_message",{mac=mac}))
   print("</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local url = ntop.getHttpPrefix().."/lua/mac_details.lua?"..hostinfo2url(host_info)
local has_snmp_location = snmp_location and snmp_location.host_has_snmp_location(mac)
local title = i18n("mac_details.mac")..": "..mac

page_utils.print_navbar(title, url,
			{
			   {
			      hidden = only_historical,
			      active = page == "overview" or page == nil,
			      page_name = "overview",
			      label = "<i class=\"fas fa-home fa-lg\"></i>",
			   },
			   {
			      hidden = only_historical or (mac_info["packets.sent"] + mac_info["packets.rcvd"] == 0),
			      active = page == "packets",
			      page_name = "packets",
			      label = i18n("packets"),
			   },
			   {
			      hidden = not has_snmp_location,
			      active = page == "snmp",
			      page_name = "snmp",
			      label = i18n("host_details.snmp"),
			   },
			   {
			      hidden = not areMacsTimeseriesEnabled(ifId),
			      active = page == "historical",
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			   {
			      hidden = not isAdministrator() or interface.isPcapDumpInterface(),
			      active = page == "config",
			      page_name = "config",
			      label = "<i class=\"fas fa-lg fa-cog\"></i>",
			   },
			}
)

if((page == "overview") or (page == nil)) then

   print("<table class=\"table table-bordered table-striped\">\n")
   print("<tr><th width=35%>"..i18n("mac_address").."</th><td> "..mac)

   local s = get_symbolic_mac(mac, true)

   if(s ~= mac) then 
      print(" ("..s..")")
   end

   if mac_info["num_hosts"] > 0 then
      print(" [ <A HREF=\"".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?mac="..mac.."\">"..i18n("details.show_hosts").."</A> ]")
   end
   
   print("</td>")

   print("<td>")

   print(discover.devtype2icon(mac_info.devtype) .. " ")
   if mac_info.devtype ~= 0 then
      print(discover.devtype2string(mac_info.devtype) .. " ")
   else
      print(i18n("host_details.unknown_device_type") .. " ")
   end
   
   if isAdministrator() then
      print('<a href="'..ntop.getHttpPrefix()..'/lua/mac_details.lua?'..hostinfo2url(mac_info)..'&page=config"><i class="fas fa-cog"></i></a>\n')
   end

   if(not isEmptyString(mac_info.model)) then
      local _model = discover.apple_products[mac_info.model] or mac_info.model
      print(" [ "..i18n("model")..": ".. _model .." ]")
   end

   print("</td></tr>")

   if mac_info["num_hosts"] > 0 then
      print("<tr>")
      print("<th>"..i18n("ip_address").."</th><td colspan=2>"..printMacHosts(mac).."</td>")
      print("</tr>")
   end

   if has_snmp_location then
      snmp_location.print_host_snmp_location(mac, url .. [[&page=snmp]])
   end

   print("<tr><th>"..i18n("name").."</th><td><span id=name>"..label.."</span>")

   if isAdministrator() then
      print[[ <a href="]] print(ntop.getHttpPrefix()) print[[/lua/mac_details.lua?]] print(hostinfo2url(mac_info)) print[[&page=config">]]
      print[[<i class="fas fa-sm fa-cog" aria-hidden="true" title="Set Host Alias"></i></a></span> ]]
   end

   print("</td>\n")

   print("<td>\n")

   print[[<span>]] print(i18n(ternary(have_nedge, "nedge.user", "details.host_pool"))..": ")
   if not ifstats.isView then
      print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/hosts_stats.lua?pool=]] print(pool_id) print[[">]] print(host_pools_instance:get_pool_name(pool_id)) print[[</a></span>]]
         if isAdministrator() then
          print[[&nbsp; <a href="]] print(ntop.getHttpPrefix()) print[[/lua/mac_details.lua?]] print(hostinfo2url(mac_info)) print[[&page=config&ifid=]] print(tostring(ifId)) print[[">]]
          print[[<i class="fas fa-sm fa-cog" aria-hidden="true"></i></a></span>]]
         end
      else
        -- no link for view interfaces
        print(host_pools_instance:get_pool_name(pool_id))
      end
      print("</td></tr>")

   print("</td>\n")

   print("</td></tr>")

   if(mac_info.devtype ~= 0) then
      -- This is a known device type
      print("<tr><th>".. i18n("details.device_type") .. "</th><td>" .. discover.devtype2icon(mac_info.devtype) .. " ")
      print(discover.devtype2string(mac_info.devtype))
      if(mac_info.ssid ~= nil) then
	 print(' ( <i class="fas fa-wifi fa-lg devtype-icon" aria-hidden="true"></i> '..mac_info.ssid..' )')
      end

      print("</td><td></td></tr>\n")
   end

   if(mac_info.fingerprint ~= "") then
    print("<tr><th><A HREF=https://en.wikipedia.org/wiki/Device_fingerprint>DHCP Fingerprint</A> "..'<i class="fas fa-hand-o-up fa-lg" aria-hidden="true"></i>'
	     .."</th><td colspan=2>"..mac_info.fingerprint.."</td></tr>\n")
   end

   if have_nedge then
     print("<tr><th>" .. i18n("hosts_stats.location") .. " </th><td colspan=2>".. firstToUpper(mac_info.location) .."</td></tr>\n")
   end

   print("<tr><th>".. i18n("details.first_last_seen") .. "</th><td nowrap><span id=first_seen>" .. formatEpoch(mac_info["seen.first"]) ..  " [" .. secondsToTime(os.time()-mac_info["seen.first"]) .. " " .. i18n("details.ago").."]" .. "</span></td>\n")
   print("<td  width='35%'><span id=last_seen>" .. formatEpoch(mac_info["seen.last"]) .. " [" .. secondsToTime(os.time()-mac_info["seen.last"]) .. " " .. i18n("details.ago").."]" .. "</span></td></tr>\n")

   if((mac_info["bytes.sent"]+mac_info["bytes.rcvd"]) > 0) then
      print("<tr><th>" .. i18n("details.sent_vs_received_traffic_breakdown") .. "</th><td colspan=2>")
      graph_utils.breakdownBar(mac_info["bytes.sent"], i18n("sent"), mac_info["bytes.rcvd"], i18n("details.rcvd"), 0, 100)
      print("</td></tr>\n")
   end

   local first_observed = ntop.getHashCache(getFirstSeenDevicesHashKey(ifId), mac_info["mac"])

   if(not isEmptyString(first_observed)) then
      print("<tr><th>" .. i18n("details.first_observed_on") .. "</th><td colspan=2>")
      print(formatEpoch(first_observed))
      print("</td></tr>\n")
   end

   if interface.isBridgeInterface(ifstats) then
      print("<tr id=bridge_dropped_flows_tr ") if not mac_info["flows.dropped"] then print("style='display:none;'") end print(">")

      print("<th><i class=\"fas fa-ban fa-lg\"></i> "..i18n("details.flows_dropped_by_bridge").."</th>")
      print("<td colspan=2><span id=bridge_dropped_flows>" .. formatValue((mac_info["flows.dropped"] or 0)) .. "</span>")

      print("</tr>")
   end

   print("<tr><th>" .. i18n("details.traffic_sent_received") .. "</th><td><span id=pkts_sent>" .. formatPackets(mac_info["packets.sent"]) .. "</span> / <span id=bytes_sent>".. bytesToSize(mac_info["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" .. formatPackets(mac_info["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>".. bytesToSize(mac_info["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

if not have_nedge then
   print([[
<tr>
   <th rowspan="2"><A HREF=https://en.wikipedia.org/wiki/Address_Resolution_Protocol>]]) print(i18n("details.address_resolution_protocol")) print[[</A></th>
   <th>]] print(i18n("details.arp_requests")) print[[</th>
   <th>]] print(i18n("details.arp_replies")) print([[</th></tr>]])

print([[<tr>
   <td><span id="arp_requests_sent">]]..formatValue(mac_info["arp_requests.sent"])..[[</span> ]]..i18n("sent")..[[ / <span id="arp_requests_rcvd">]]..formatValue(mac_info["arp_requests.rcvd"])..[[</span> ]]..i18n("received")..[[</td>
   <td><span id="arp_replies_sent">]]..formatValue(mac_info["arp_replies.sent"])..[[</span> ]]..i18n("sent")..[[ / <span id="arp_replies_rcvd">]]..formatValue(mac_info["arp_replies.rcvd"])..[[</span> ]]..i18n("received")..[[</td>
</tr>]])
end

   -- Stats reset
   print(
     template.gen("modal_confirm_dialog.html", {
       dialog={
         id      = "reset_mac_stats_dialog",
         action  = "$('#reset_mac_stats_form').submit();",
         title   = i18n("mac_details.reset_mac_stats"),
         message = i18n("host_details.reset_host_stats_confirm", {host=mac}) .. "<br><br>" .. i18n("mac_details.reset_mac_stats_note"),
         confirm = i18n("reset"),
       }
     })
   )
   print[[<tr><th width=30% >]] print(i18n("mac_details.reset_mac_stats"))
   print[[</th><td colspan=2><form id='reset_mac_stats_form' method="POST">
      <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
      <input name="action" type="hidden" value="reset_stats" />
   </form>
   <button class="btn btn-secondary" onclick="$('#reset_mac_stats_dialog').modal('show')">]] print(i18n("mac_details.reset_mac_stats")) print[[</button>
   </td></tr>]]

   print("</table>")

   print('<script type="text/javascript">')

   print("var last_pkts_sent = " .. mac_info["packets.sent"] .. ";\n")
   print("var last_pkts_rcvd = " .. mac_info["packets.rcvd"] .. ";\n")

   print [[

var host_details_interval = window.setInterval(function() {
  $.ajax({
    type: 'GET',
    url: ']] print (ntop.getHttpPrefix()) print [[/lua/mac_stats.lua',
    data: { ifid: "]] print(ifId.."")  print('", '..hostinfo2json(mac_info)) print [[ },
    datatype: "json",
    /* error: function(content) { alert("]] print(i18n("mac_details.json_error_inactive", {product=info["product"]})) print[["); }, */
    success: function(content) {
      var host = jQuery.parseJSON(content);
      $('#first_seen').html(NtopUtils.epoch2Seen(host["seen.first"]));
      $('#last_seen').html(NtopUtils.epoch2Seen(host["seen.last"]));
      $('#pkts_sent').html(NtopUtils.formatPackets(host["packets.sent"]));
      $('#pkts_rcvd').html(NtopUtils.formatPackets(host["packets.rcvd"]));
      $('#bytes_sent').html(NtopUtils.bytesToVolume(host["bytes.sent"]));
      $('#bytes_rcvd').html(NtopUtils.bytesToVolume(host["bytes.rcvd"]));
      $('#arp_requests_sent').html(NtopUtils.addCommas(host["arp_requests.sent"]));
      $('#arp_requests_rcvd').html(NtopUtils.addCommas(host["arp_requests.rcvd"]));
      $('#arp_replies_sent').html(NtopUtils.addCommas(host["arp_replies.sent"]));
      $('#arp_replies_rcvd').html(NtopUtils.addCommas(host["arp_replies.rcvd"]));
]]
   if interface.isBridgeInterface(ifstats) then
print[[
      if(host["flows.dropped"] > 0) {
        $('#bridge_dropped_flows').html(NtopUtils.addCommas(host["flows.dropped"]));

        $('#bridge_dropped_flows_tr').show();
      } else {
        $('#bridge_dropped_flows_tr').hide();
      }
]]
   end

print[[
    },
  });
}, 3000);

]]
   print('</script>')

elseif(page == "packets") then
   print [[ <table class="table table-bordered table-striped"> ]]
   print("<tr><th width=30% rowspan=3>" .. i18n("packets_page.ip_version_distribution") .. '</th><td><div class="pie-chart" id="ipverDistro"></div></td></tr>\n')
   print[[</table>

   <script type='text/javascript'>
    var refresh = ]] print(getInterfaceRefreshRate(ifstats.id)) print[[ * 1000; /* ms */;

	 window.onload=function() {
       do_pie("#ipverDistro", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/mac_pkt_distro.lua', { distr: "ipver", mac: "]] print(mac) print[[", ifid: "]] print(ifstats.id.."\"")
   print [[
	   }, "", refresh);
   };
   </script>]]

elseif(page == "snmp" and has_snmp_location) then
   print[[<table class="table table-bordered table-striped">]]
   snmp_location.print_host_snmp_localization_table_entry(mac)
   print[[</table>]]
elseif(page == "historical") then
   local schema = _GET["ts_schema"] or "mac:traffic"
   local selected_epoch = _GET["epoch"] or ""
   url = url..'&page=historical'

   local tags = {
      ifid = ifId,
      mac = mac,
      category = _GET["category"],
   }

   graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
      top_categories = "top:mac:ndpi_categories",
      timeseries = table.merge({
         {schema="mac:traffic",                 label=i18n("traffic"), split_directions = true --[[ split RX and TX directions ]]},
      }, graph_utils.getDeviceCommonTimeseries())
   })

elseif(page == "config") then
   if(not isAdministrator()) then
      return
   end

   print[[
   <form id="mac_config" class="form-inline" method="post">
   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <table class="table table-bordered table-striped">
      <tr>
         <th>]] print(i18n("host_config.host_alias")) print[[</th>
         <td>]]

      print[[<input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width:240px;display:inline;" value="]]
      if(label ~= nil) then print(label) end
      print("\"></input> &nbsp;<div style=\"width:240px;display:inline-block;\" >")

      discover.printDeviceTypeSelector(mac_info.devtype, "device_type")

      print [[</div>
         </td>
      </tr>]]

      if not ifstats.isView then
	 graph_utils.printPoolChangeDropdown(ifId, pool_id.."", have_nedge)
      end

print[[
   </table>
   <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
   </form>
   <script>
      aysHandleForm("#mac_config");
   </script>]]

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
