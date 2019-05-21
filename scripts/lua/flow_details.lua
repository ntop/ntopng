--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local shaper_utils
require "lua_utils"
local format_utils = require "format_utils"
local have_nedge = ntop.isnEdge()
local NfConfig = nil

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")

   if ntop.isnEdge() then
      package.path = dirs.installdir .. "/scripts/lua/pro/nedge/modules/?.lua;" .. package.path
      NfConfig = require("nf_config")
   end
end

require "historical_utils"
require "flow_utils"
require "voip_utils"

local template = require "template_utils"
local categories_utils = require "categories_utils"
local protos_utils = require("protos_utils")
local discover = require("discover_utils")
local json = require ("dkjson")
local page_utils = require("page_utils")

local function ja3url(what, safety)
   if(what == nil) then
      print("&nbsp;")
   else
      ret = '<A HREF="https://sslbl.abuse.ch/ja3-fingerprints/'..what..'/">'..what..'</A> <i class="fa fa-external-link"></i>'
      if(safety ~= "safe") then
	 ret = ret .. ' [ <i class="fa fa-warning" aria-hidden=true style="color: orange;"></i> <A HREF=https://en.wikipedia.org/wiki/Cipher_suite>'..capitalize(safety)..' Cipher</A> ]'
      end

      print(ret)
   end
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("flow_details.flow_details"))

warn_shown = 0

local alert_banners = {}

if isAdministrator() then
   if _POST["custom_hosts"] and _POST["l7proto"] then
      local proto_id = tonumber(_POST["l7proto"])
      local proto_name = interface.getnDPIProtoName(proto_id)

      if protos_utils.addAppRule(proto_name, {match="host", value=_POST["custom_hosts"]}) then
	 local info = ntop.getInfo()

	 alert_banners[#alert_banners + 1] = {
          type = "success",
          text = i18n("custom_categories.protos_reboot_necessary", {product=info.product})
        }
      else
	 alert_banners[#alert_banners + 1] = {
	    type="danger",
	    text=i18n("flow_details.could_not_add_host_to_category",
	       {host=_POST["custom_hosts"], category=proto_name})
	 }
      end
   elseif _POST["custom_hosts"] and _POST["category"] then
      local lists_utils = require("lists_utils")
      local category_id = tonumber(split(_POST["category"], "cat_")[2])

      if categories_utils.addCustomCategoryHost(category_id, _POST["custom_hosts"]) then
	 lists_utils.reloadLists()

	 alert_banners[#alert_banners + 1] = {
	    type="success",
	    text=i18n("flow_details.host_successfully_added_to_category",
	       {host=_POST["custom_hosts"], category=interface.getnDPICategoryName(category_id),
	       url = ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua?l7proto=" .. category_id})
	 }
      else
	 alert_banners[#alert_banners + 1] = {
	    type="danger",
	    text=i18n("flow_details.could_not_add_host_to_category",
	       {host=_POST["custom_hosts"], category=interface.getnDPICategoryName(category_id)})
	 }
      end
   end
end

local function printAddCustomHostRule(full_url)
   if not isAdministrator() then
      return
   end

   local categories = interface.getnDPICategories()
   local protocols = interface.getnDPIProtocols()
   local short_url = categories_utils.getSuggestedHostName(full_url)

   -- Fill the category dropdown
   local cat_select_dropdown = '<select id="flow_target_category" class="form-control">'

   for cat_name, cat_id in pairsByKeys(categories, asc_insensitive) do
      cat_select_dropdown = cat_select_dropdown .. [[<option value="cat_]] ..cat_id .. [[">]] .. cat_name .. [[</option>]]
   end
   cat_select_dropdown = cat_select_dropdown .. "</select>"

   -- Fill the application dropdown
   local app_select_dropdown = '<select id="flow_target_app" class="form-control" style="display:none">'

   for proto_name, proto_id in pairsByKeys(protocols, asc_insensitive) do
      app_select_dropdown = app_select_dropdown .. [[<option value="]] ..proto_id .. [[">]] .. proto_name .. [[</option>]]
   end
   app_select_dropdown = app_select_dropdown .. "</select>"

   -- Put a note if the URL is already assigned to another customized category
   local existing_note = ""
   local matched_category = ntop.matchCustomCategory(full_url)

   existing_note = "<br>" ..
      i18n("flow_details.existing_rules_note",
	 {name=i18n("custom_categories.apps_and_categories"), url=ntop.getHttpPrefix().."/lua/admin/edit_categories.lua"})

   if matched_category ~= nil then
      existing_note = existing_note .. "<br><br>" .. i18n("details.note") .. ": " ..
	 i18n("custom_categories.similar_host_found", {host=full_url, category=interface.getnDPICategoryName(matched_category)}) ..
	 "<br><br>"
   end

   local rule_type_selection = ""
   if protos_utils.hasProtosFile() then
      rule_type_selection = i18n("flow_details.rule_type")..":"..[[<br><select id="new_rule_type" onchange="new_rule_dropdown_select(this)" class="form-control">
	    <option value="application">]]..i18n("application")..[[</option>
	    <option value="category" selected>]]..i18n("category")..[[</option>
	 </select><br>]]
   end

   print(
     template.gen("modal_confirm_dialog.html", {
       dialog={
	 id      = "add_to_customized_categories",
	 action  = "addToCustomizedCategories()",
	 custom_alert_class = "",
	 custom_dialog_class = "dialog-body-full-height",
	 title   = i18n("custom_categories.custom_host_category"),
	 message = rule_type_selection .. i18n("custom_categories.select_url_category") .. "<br>" ..
	    cat_select_dropdown .. app_select_dropdown .. "<br>" .. i18n("custom_categories.the_following_url_will_be_added") ..
	    '<br><input id="categories_url_add" class="form-control" required value="'.. short_url ..'">' .. existing_note,
	 confirm = i18n("custom_categories.add"),
	 cancel = i18n("cancel"),
       }
     })
   )

   print(' <a href="#" onclick="$(\'#add_to_customized_categories\').modal(\'show\'); return false;"><i title="'.. i18n("custom_categories.add_to_categories") ..'" class="fa fa-plus"></i></a>')

   print[[<script>
   function addToCustomizedCategories() {
      var is_category = ($("#new_rule_type").val() == "category");
      var target_value = is_category ? $("#flow_target_category").val() : $("#flow_target_app").val();;
      var target_url = cleanCustomHostUrl($("#categories_url_add").val());

      if(!target_value || !target_url)
	 return;

      var params = {};
      params.custom_hosts = target_url;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      if(is_category)
	 params.category = target_value;
      else
	 params.l7proto = target_value;

      paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
   }

   function new_rule_dropdown_select(dropdown) {
      if($(dropdown).val() == "category") {
	 $("#flow_target_category").show();
	 $("#flow_target_app").hide();
      } else {
	 $("#flow_target_category").hide();
	 $("#flow_target_app").show();
      }
   }
</script>]]
end

local function displayContainer(cont, label)
   print(label)

   if not isEmptyString(cont["id"]) then
      -- short 12-chars UUID as in docker
      print("<tr><th width=30%>"..i18n("containers_stats.container").."</th><td colspan=2><a href='"..ntop.getHttpPrefix().."/lua/flows_stats.lua?container=".. cont["id"] .."'>"..format_utils.formatContainer(cont).."</a></td></tr>\n")
   end

   local k8s_name = cont["k8s.name"]
   local k8s_pod = cont["k8s.pod"]
   local k8s_ns = cont["k8s.ns"]

   local k8s_rows = {}
   if not isEmptyString(k8s_name) then k8s_rows[#k8s_rows + 1] = {i18n("flow_details.k8s_name"), k8s_name} end
   if not isEmptyString(k8s_pod)  then k8s_rows[#k8s_rows + 1] = {i18n("flow_details.k8s_pod"), '<a href="' .. ntop.getHttpPrefix() .. '/lua/containers_stats.lua?pod='.. k8s_pod ..'">' .. k8s_pod .. '</a>'} end
   if not isEmptyString(k8s_ns)   then k8s_rows[#k8s_rows + 1] = {i18n("flow_details.k8s_ns"), k8s_ns} end

   for i, row in ipairs(k8s_rows) do
      local header = ''

      if i == 1 then
	 header = "<th width=30% rowspan="..(#k8s_rows)..">"..i18n("flow_details.k8s").."</th>"
      end

      print("<tr>"..header.."<th>"..row[1].."</th><td>"..row[2].."</td></tr>\n")
   end

   local docker_name = cont["docker.name"]

   local docker_rows = {}
   if not isEmptyString(docker_name) then docker_rows[#docker_rows + 1] = {i18n("flow_details.docker_name"), docker_name} end

   for i, row in ipairs(docker_rows) do
      local header = ''

      if i == 1 then
	 header = "<th width=30% rowspan="..(#docker_rows)..">"..i18n("flow_details.docker").."</th>"
      end

      print("<tr>"..header.."<th>"..row[1].."</th><td>"..row[2].."</td></tr>\n")
   end
end

local function displayProc(proc, label)
   if(proc.pid == 0) then return end

   print(label)

   print("<tr><th width=30%>"..i18n("flow_details.user_name").."</th><td colspan=2><A HREF=\""..ntop.getHttpPrefix().."/lua/username_details.lua?uid=" .. proc.uid .. "&username=".. proc.user_name .."&".. hostinfo2url(flow,"cli").."\">".. proc.user_name .."</A></td></tr>\n")
   print("<tr><th width=30%>"..i18n("flow_details.process_pid_name").."</th><td colspan=2><A HREF=\""..ntop.getHttpPrefix().."/lua/process_details.lua?pid=".. proc.pid .."&pid_name=".. proc.name .. "&" .. hostinfo2url(flow,"srv").. "\">".. proc.name .. " [pid: "..proc.pid.."]</A>")
   if proc.father_pid then
      print(" "..i18n("flow_details.son_of_father_process",{url=ntop.getHttpPrefix().."/lua/get_process_info.lua?pid="..proc.father_pid, proc_father_pid = proc.father_pid, proc_father_name = proc.father_name}).."</td></tr>\n")
   end

   if((proc.actual_memory ~= nil) and (proc.actual_memory > 0)) then
      print("<tr><th width=30%>"..i18n("graphs.actual_memory").."</th><td colspan=2>".. bytesToSize(proc.actual_memory * 1024) .. "</td></tr>\n")
      print("<tr><th width=30%>"..i18n("graphs.peak_memory").."</th><td colspan=2>".. bytesToSize(proc.peak_memory * 1024) .. "</td></tr>\n")
   end
end

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

printMessageBanners(alert_banners)

if not table.empty(alert_banners) then
   print("<br>")
end

print('<div style=\"display:none;\" id=\"flow_purged\" class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i>&nbsp;'..i18n("flow_details.not_purged")..'</div>')

throughput_type = getThroughputType()

flow_key = _GET["flow_key"]

interface.select(ifname)
if(flow_key == nil) then
   flow = nil
else
   flow = interface.findFlowByKey(tonumber(flow_key))
end

local ifid = interface.name2id(ifname)
local label = getFlowLabel(flow)

print [[

<div class="bs-docs-example">
	    <nav class="navbar navbar-default" role="navigation">
	      <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
	 <li><a href="#">]] print(i18n("flow")) print[[: ]] print(label) print [[ </a></li>
<li class="active"><a href="#">]] print(i18n("overview")) print[[</a></li>
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</div>
</div>
</nav>
]]

if(flow == nil) then
   print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i> '..i18n("flow_details.flow_cannot_be_found_message")..' '.. purgedErrorString()..'</div>')
else

   if isAdministrator() then
      if(_POST["drop_flow_policy"] == "true") then
	 interface.dropFlowTraffic(tonumber(flow_key))
	 flow["verdict.pass"] = false
      end
   end

   ifstats = interface.getStats()
   print("<table class=\"table table-bordered table-striped\">\n")
   if ifstats.vlan and flow["vlan"] > 0 then
      print("<tr><th width=30%>")
      print(i18n("details.vlan_id"))
      print("</th><td colspan=2>" .. flow["vlan"].. "</td></tr>\n")
   end

   print("<tr><th width=30%>"..i18n("flow_details.flow_peers_client_server").."</th><td colspan=2>"..getFlowLabel(flow, true, true).."</td></tr>\n")

   print("<tr><th width=30%>"..i18n("protocol").." / "..i18n("application").."</th>")
   if((ifstats.inline and flow["verdict.pass"]) or (flow.vrfId ~= nil)) then
      print("<td>")
   else
      print("<td colspan=2>")
   end

   if(flow["verdict.pass"] == false) then print("<strike>") end
   print(flow["proto.l4"].." / <A HREF=\""..ntop.getHttpPrefix().."/lua/")
   if((flow.client_process ~= nil) or (flow.server_process ~= nil))then	print("s") end
   print("flows_stats.lua?application=" .. flow["proto.ndpi"] .. "\">")
   print(getApplicationLabel(flow["proto.ndpi"]).."</A> ")
   print("(<A HREF=\""..ntop.getHttpPrefix().."/lua/")
   print("flows_stats.lua?category=" .. flow["proto.ndpi_cat"] .. "\">")
   print(getCategoryLabel(flow["proto.ndpi_cat"]))
   print("</A>) ".. formatBreed(flow["proto.ndpi_breed"]))
   if(flow["verdict.pass"] == false) then print("</strike>") end
   historicalProtoHostHref(ifid, flow["cli.ip"], nil, flow["proto.ndpi_id"], flow["protos.ssl.certificate"])

   if(ifstats.inline) then
      if(flow["verdict.pass"]) then
	 print('<form class="form-inline pull-right" style="margin-bottom: 0px;" method="post">')
	 print('<input type="hidden" name="drop_flow_policy" value="true">')
	 print('<button style="position: relative; margin-top: 0; height: 26px" type="submit" class="btn btn-default btn-xs"><i class="fa fa-ban"></i> '..i18n("flow_details.drop_flow_traffic_btn")..'</button>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('</form>')
      end
   end
   print('</td>')

   if(flow.vrfId ~= nil) then
      print("<td><b> <A HREF=https://en.wikipedia.org/wiki/Virtual_routing_and_forwarding>VRF</A> Id</b> "..flow.vrfId.."</td>")
   end
   print("</tr>\n")
   
   if(ntop.isPro() and ifstats.inline and (flow["shaper.cli2srv_ingress"] ~= nil)) then
      local host_pools_utils = require("host_pools_utils")
      print("<tr><th width=30% rowspan=2>"..i18n("flow_details.flow_shapers").."</th>")
      c = flowinfo2hostname(flow,"cli")
      s = flowinfo2hostname(flow,"srv")

      if flow["cli.pool_id"] ~= nil then
        c = c .. " (<a href='".. host_pools_utils.getUserUrl(flow["cli.pool_id"]) .."'>".. host_pools_utils.poolIdToUsername(flow["cli.pool_id"]) .."</a>)"
      end

      if flow["srv.pool_id"] ~= nil then
        s = s .. " (<a href='".. host_pools_utils.getUserUrl(flow["srv.pool_id"]) .."'>".. host_pools_utils.poolIdToUsername(flow["srv.pool_id"]) .."</a>)"
      end

      local shaper = shaper_utils.nedge_shaper_id_to_shaper(flow["shaper.cli2srv_egress"])
      print("<td nowrap>"..c.."</td><td>".. shaper.icon .. " " .. shaper.text .."</td></tr>")

      local shaper = shaper_utils.nedge_shaper_id_to_shaper(flow["shaper.cli2srv_ingress"])
      print("<td nowrap>"..s.."</td><td>".. shaper.icon .. " " .. shaper.text.."</td></tr>")
      print("</tr>")

      if flow["cli.pool_id"] ~= nil and flow["srv.pool_id"] ~= nil then
         print("<tr><th width=30% rowspan=2>"..i18n("flow_details.flow_quota").."</th>")
         print("<td>"..c.."</td>")
         print("<td id='cli2srv_quota'>")
         printFlowQuota(ifstats.id, flow, true --[[ client ]])
         print("</td></tr>")
         print("<td nowrap>"..s.."</td>")
         print("<td id='srv2cli_quota'>")
         printFlowQuota(ifstats.id, flow, false --[[ server ]])
         print("</td>")
         print("</tr>")
      end

      -- ENABLE MARKER DEBUG
      if ntop.isnEdge() and false then
        print("<tr><th width=30%>"..i18n("flow_details.flow_marker").."</th>")
        print("<td colspan=2>".. NfConfig.formatMarker(flow["marker"]) .."</td>")
        print("</tr>")
      end

      local status_info = flow2statusinfo(flow)

      if status_info then
         local cli_mac = flow["cli.mac"] and interface.getMacInfo(flow["cli.mac"])
         local srv_mac = flow["srv.mac"] and interface.getMacInfo(flow["srv.mac"])
         local cli_show = (cli_mac and cli_mac.location == "lan" and flow["cli.pool_id"] == 0)
         local srv_show = (srv_mac and srv_mac.location == "lan" and flow["srv.pool_id"] == 0)
         local num_rows = 0

         if cli_show then
           num_rows = num_rows + 1
         end
         if srv_show then
           num_rows = num_rows + 1
         end

         if num_rows > 0 then
           print("<tr><th width=30% rowspan=".. num_rows ..">"..i18n("device_protocols.device_protocol_policy").."</th>")
	   local proto = status_info["devproto_forbidden_id"] or flow["proto.ndpi_id"]

           if cli_show then
             print("<td>"..i18n("device_protocols.devtype_as_proto_client", {devtype=discover.devtype2string(status_info["cli.devtype"]), proto=interface.getnDPIProtoName(proto)}).."</td>")
             print("<td><a href=\"".. getDeviceProtocolPoliciesUrl("device_type=" .. status_info["cli.devtype"]) .."&l7proto=".. proto .."\">")
             print(i18n(ternary(status_info["devproto_forbidden_peer"] ~= "cli", "allowed", "forbidden")))
             print("</a></td></tr><tr>")
           end

           if srv_show then
             print("<td>"..i18n("device_protocols.devtype_as_proto_server", {devtype=discover.devtype2string(status_info["srv.devtype"]), proto=interface.getnDPIProtoName(proto)}).."</td>")
             print("<td><a href=\"".. getDeviceProtocolPoliciesUrl("device_type=" .. status_info["srv.devtype"]) .."&l7proto=".. proto .."\">")
             print(i18n(ternary(status_info["devproto_forbidden_peer"] ~= "srv", "allowed", "forbidden")))
             print("</a></td></tr><tr>")
           end
         end
      end
   end

   print("<tr><th width=33%>"..i18n("details.first_last_seen").."</th><td nowrap width=33%><div id=first_seen>"
	    .. formatEpoch(flow["seen.first"]) ..  " [" .. secondsToTime(os.time()-flow["seen.first"]) .. " "..i18n("details.ago").."]" .. "</div></td>\n")
   print("<td nowrap><div id=last_seen>" .. formatEpoch(flow["seen.last"]) .. " [" .. secondsToTime(os.time()-flow["seen.last"]) .. " "..i18n("details.ago").."]" .. "</div></td></tr>\n")

   if flow["bytes"] > 0 then
      print("<tr><th width=30% rowspan=3>"..i18n("details.total_traffic").."</th><td>"..i18n("total")..": <span id=volume>" .. bytesToSize(flow["bytes"]) .. "</span> <span id=volume_trend></span></td>")
      if((ifstats.type ~= "zmq") and ((flow["proto.l4"] == "TCP") or (flow["proto.l4"] == "UDP")) and (flow["goodput_bytes"] > 0)) then
	 print("<td><A HREF=\"https://en.wikipedia.org/wiki/Goodput\">"..i18n("details.goodput").."</A>: <span id=goodput_volume>" .. bytesToSize(flow["goodput_bytes"]) .. "</span> (<span id=goodput_percentage>")
	 pctg = round(((flow["goodput_bytes"]*100)/flow["bytes"]), 2)
	 if(pctg < 50) then
	    pctg = "<font color=red>"..pctg.."</font>"
	 elseif(pctg < 60) then
	    pctg = "<font color=orange>"..pctg.."</font>"
	 end
	 print(pctg.."")

	 print("</span> %) <span id=goodput_volume_trend></span> </td></tr>\n")
      else
	 print("<td>&nbsp;</td></tr>\n")
      end

      print("<tr><td nowrap>" .. i18n("client") .. " <i class=\"fa fa-arrow-right\"></i> " .. i18n("server") .. ": <span id=cli2srv>" .. formatPackets(flow["cli2srv.packets"]) .. " / ".. bytesToSize(flow["cli2srv.bytes"]) .. "</span> <span id=sent_trend></span></td><td nowrap>" .. i18n("client") .. " <i class=\"fa fa-arrow-left\"></i> " .. i18n("server") .. ": <span id=srv2cli>" .. formatPackets(flow["srv2cli.packets"]) .. " / ".. bytesToSize(flow["srv2cli.bytes"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

      print("<tr><td colspan=2>")
      cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)

      cli_name = shortHostName(getResolvedAddress(hostkey2hostinfo(flow["cli.ip"])))
      srv_name = shortHostName(getResolvedAddress(hostkey2hostinfo(flow["srv.ip"])))

      if(flow["cli.port"] > 0) then
	 cli_name = cli_name .. ":" .. flow["cli.port"]
	 srv_name = srv_name .. ":" .. flow["srv.port"]
      end
      print('<div class="progress"><div class="progress-bar progress-bar-warning" style="width: ' .. cli2srv.. '%;">'.. cli_name..'</div><div class="progress-bar progress-bar-info" style="width: ' .. (100-cli2srv) .. '%;">' .. srv_name .. '</div></div>')
      print("</td></tr>\n")
   end

   if(flow["tcp.nw_latency.client"] ~= nil) then
      local rtt = flow["tcp.nw_latency.client"] + flow["tcp.nw_latency.server"]

      if(rtt > 0) then
	 local cli2srv = round(flow["tcp.nw_latency.client"], 3)
	 local srv2cli = round(flow["tcp.nw_latency.server"], 3)
	 
	 print("<tr><th width=30%>"..i18n("flow_details.rtt_breakdown").."</th><td colspan=2>")
	 print('<div class="progress"><div class="progress-bar progress-bar-warning" style="width: ' .. (cli2srv * 100 / rtt) .. '%;">'.. cli2srv ..' ms (client)</div>')
	 print('<div class="progress-bar progress-bar-info" style="width: ' .. (srv2cli * 100 / rtt) .. '%;">' .. srv2cli .. ' ms (server)</div></div>')
	 print("</td></tr>\n")

	 -- Inspired by https://gist.github.com/geraldcombs/d38ed62650b1730fb4e90e2462f16125
	 print("<tr><th width=30%><A HREF=\"https://en.wikipedia.org/wiki/Velocity_factor\">"..i18n("flow_details.rtt_distance").."</A></th><td>")	 
	 local c_vacuum_km_s = 299792
	 local c_vacuum_mi_s = 186000
	 local fiber_vf      = .67
	 local delta_t       = rtt/1000
	 local dd_fiber_km   = delta_t * c_vacuum_km_s * fiber_vf
	 local dd_fiber_mi   = delta_t * c_vacuum_mi_s * fiber_vf
	  
	 print(formatValue(toint(dd_fiber_km)).." Km</td><td>"..formatValue(toint(dd_fiber_mi)).." Miles")
	 print("</td></tr>\n")
      end
   end

   if(flow["tcp.appl_latency"] ~= nil and flow["tcp.appl_latency"] > 0) then
      print("<tr><th width=30%>"..i18n("flow_details.application_latency").."</th><td colspan=2>"..msToTime(flow["tcp.appl_latency"]).."</td></tr>\n")
   end

    if(not string.starts(ifname, "nf:")) then
       if((flow["cli2srv.packets"] > 1) and (flow["interarrival.cli2srv"]["max"] > 0)) then
	  print("<tr><th width=30%")
	  if(flow["flow.idle"] == true) then print(" rowspan=2") end
	  print(">"..i18n("flow_details.packet_inter_arrival_time").."</th><td nowrap>"..i18n("client").." <i class=\"fa fa-arrow-right\"></i> "..i18n("server")..": ")
	  print(msToTime(flow["interarrival.cli2srv"]["min"]).." / "..msToTime(flow["interarrival.cli2srv"]["avg"]).." / "..msToTime(flow["interarrival.cli2srv"]["max"]))
	  print("</td>\n")
	  if(flow["srv2cli.packets"] < 2) then
	     print("<td>&nbsp;")
	  else
	     print("<td nowrap>"..i18n("client").." <i class=\"fa fa-arrow-left\"></i> "..i18n("server")..": ")
	     print(msToTime(flow["interarrival.srv2cli"]["min"]).." / "..msToTime(flow["interarrival.srv2cli"]["avg"]).." / "..msToTime(flow["interarrival.srv2cli"]["max"]))
	  end
	  print("</td></tr>\n")
	  if(flow["flow.idle"] == true) then print("<tr><td colspan=2><i class='fa fa-clock-o'></i> <small>"..i18n("flow_details.looks_like_idle_flow_message").."</small></td></tr>") end
       end

       if((flow["cli2srv.fragments"] + flow["srv2cli.fragments"]) > 0) then
	  rowspan = 3
	  print("<tr><th width=30% rowspan="..rowspan..">"..i18n("flow_details.ip_packet_analysis").."</th><td colspan=2 cellpadding='0' width='100%' cellspacing='0' style='padding-top: 0px; padding-left: 0px;padding-bottom: 0px; padding-right: 0px;'></tr>")
	  print("<tr><th>&nbsp;</th><th>"..i18n("client").." <i class=\"fa fa-arrow-right\"></i> "..i18n("server").." / "..i18n("client").." <i class=\"fa fa-arrow-left\"></i> "..i18n("server").."</th></tr>\n")
	  print("<tr><th>"..i18n("details.fragments").."</th><td align=right><span id=c2sFrag>".. formatPackets(flow["cli2srv.fragments"]) .."</span> / <span id=s2cFrag>".. formatPackets(flow["srv2cli.fragments"]) .."</span></td></tr>\n")
       end

       if(flow["tcp.seq_problems"] ~= nil) then
	  rowspan = 2
	  if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then rowspan = rowspan+1 end
	  if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0)       then rowspan = rowspan+1 end
	  if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0)                       then rowspan = rowspan+1 end
	  if((flow["cli2srv.keep_alive"] + flow["srv2cli.keep_alive"]) > 0)           then rowspan = rowspan+1 end

	  if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]
	      + flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]
	      + flow["cli2srv.lost"] + flow["srv2cli.lost"]
	      + flow["cli2srv.keep_alive"] + flow["srv2cli.keep_alive"]) > 0) then
	     print("<tr><th width=30% rowspan="..rowspan..">"..i18n("flow_details.tcp_packet_analysis").."</th><td colspan=2 cellpadding='0' width='100%' cellspacing='0' style='padding-top: 0px; padding-left: 0px;padding-bottom: 0px; padding-right: 0px;'></tr>")
	     print("<tr><th>&nbsp;</th><th>"..i18n("client").." <i class=\"fa fa-arrow-right\"></i> "..i18n("server").." / "..i18n("client").." <i class=\"fa fa-arrow-left\"></i> "..i18n("server").."</th></tr>\n")

	     if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then
		print("<tr><th>"..i18n("details.retransmissions").."</th><td align=right><span id=c2sretr>".. formatPackets(flow["cli2srv.retransmissions"]) .."</span> / <span id=s2cretr>".. formatPackets(flow["srv2cli.retransmissions"]) .."</span></td></tr>\n")
	     end
	     if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0) then
		print("<tr><th>"..i18n("details.out_of_order").."</th><td align=right><span id=c2sOOO>".. formatPackets(flow["cli2srv.out_of_order"]) .."</span> / <span id=s2cOOO>".. formatPackets(flow["srv2cli.out_of_order"]) .."</span></td></tr>\n")
	     end
	     if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0) then
		print("<tr><th>"..i18n("details.lost").."</th><td align=right><span id=c2slost>".. formatPackets(flow["cli2srv.lost"]) .."</span> / <span id=s2clost>".. formatPackets(flow["srv2cli.lost"]) .."</span></td></tr>\n")
	     end
	     if((flow["cli2srv.keep_alive"] + flow["srv2cli.keep_alive"]) > 0) then
		print("<tr><th>"..i18n("details.keep_alive").."</th><td align=right><span id=c2skeep_alive>".. formatPackets(flow["cli2srv.keep_alive"]) .."</span> / <span id=s2ckeep_alive>".. formatPackets(flow["srv2cli.keep_alive"]) .."</span></td></tr>\n")
	     end
	  end
       end
    end

   if(flow["protos.ssl.certificate"] ~= nil) then
      print("<tr><th width=30%><i class='fa fa-lock fa-lg'></i> "..i18n("flow_details.ssl_certificate").."</th><td>")
      print(i18n("flow_details.client_requested")..": <A HREF=\"http://"..flow["protos.ssl.certificate"].."\">"..flow["protos.ssl.certificate"].."</A> <i class=\"fa fa-external-link\"></i>")
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["protos.ssl.certificate"], flow["category"])) end
      historicalProtoHostHref(ifid, nil, nil, nil, flow["protos.ssl.certificate"])
      printAddCustomHostRule(flow["protos.ssl.certificate"])
      print("</td>")

      print("<td>")
      if(flow["protos.ssl.server_certificate"] ~= nil) then
	 print(i18n("flow_details.server_certificate")..": <A HREF=\"http://"..flow["protos.ssl.server_certificate"].."\">"..flow["protos.ssl.server_certificate"].."</A>")

	 if(flow["flow.status"] == 10) then
	    print("\n<br><i class=\"fa fa-warning fa-lg\" style=\"color: #f0ad4e;\"></i> <b><font color=\"#f0ad4e\">"..i18n("flow_details.certificates_not_match").."</font></b>")
	 end
      end
      print("</td>")
      print("</tr>\n")
   end

   if((flow["protos.ssl.ja3.client_hash"] ~= nil) or (flow["protos.ssl.ja3.server_hash"] ~= nil)) then
      print('<tr><th width=30%><A HREF="https://github.com/salesforce/ja3">JA3</A></th><td>')
      ja3url(flow["protos.ssl.ja3.client_hash"], flow["protos.ssl.ja3.client_unsafe_cipher"])
      print("</td><td>")
      ja3url(flow["protos.ssl.ja3.server_hash"], flow["protos.ssl.ja3.server_unsafe_cipher"])
      print("</td></tr>")
   end

   if((flow["tcp.max_thpt.cli2srv"] ~= nil) and (flow["tcp.max_thpt.cli2srv"] > 0)) then
     print("<tr><th width=30%>"..
     '<a href="https://en.wikipedia.org/wiki/TCP_tuning" data-toggle="tooltip" title="'..i18n("flow_details.computed_as_tcp_window_size_rtt")..'">'..
     i18n("flow_details.max_estimated_tcp_throughput").."</a><td nowrap> "..i18n("client").." <i class=\"fa fa-arrow-right\"></i> "..i18n("server")..": ")
     print(bitsToSize(flow["tcp.max_thpt.cli2srv"]))
     print("</td><td> "..i18n("client").." <i class=\"fa fa-arrow-left\"></i> "..i18n("server")..": ")
     print(bitsToSize(flow["tcp.max_thpt.srv2cli"]))
     print("</td></tr>\n")
   end
  
   if((flow["cli2srv.trend"] ~= nil) and false) then
     print("<tr><th width=30%>"..i18n("flow_details.throughput_trend").."</th><td nowrap>"..flow["cli.ip"].." <i class=\"fa fa-arrow-right\"></i> "..flow["srv.ip"]..": ")
     print(flow["cli2srv.trend"])
     print("</td><td>"..flow["cli.ip"].." <i class=\"fa fa-arrow-left\"></i> "..flow["srv.ip"]..": ")
     print(flow["srv2cli.trend"])
     print("</td></tr>\n")
    end

   local flags = flow["cli2srv.tcp_flags"] or flow["srv2cli.tcp_flags"]

   if((flags ~= nil) and (flags > 0)) then
      print("<tr><th width=30% rowspan=2>"..i18n("tcp_flags").."</th><td nowrap>"..i18n("client").." <i class=\"fa fa-arrow-right\"></i> "..i18n("server")..": ")
      printTCPFlags(flow["cli2srv.tcp_flags"])
      print("</td><td nowrap>"..i18n("client").." <i class=\"fa fa-arrow-left\"></i> "..i18n("server")..": ")
      printTCPFlags(flow["srv2cli.tcp_flags"])
      print("</td></tr>\n")

      print("<tr><td colspan=2>")

      local flow_msg = ""
      if flow["tcp_reset"] then
	 local resetter = ""

	 if(hasbit(flow["cli2srv.tcp_flags"],0x04)) then
	    resetter = "client"
	 else
	    resetter = "server"
	 end

	 flow_msg = flow_msg..i18n("flow_details.flow_reset_by_resetter_msg",{resetter = resetter})
      elseif flow["tcp_closed"] then
	 flow_msg = flow_msg..i18n("flow_details.flow_completed_msg")
      elseif flow["tcp_connecting"] then
	 flow_msg = flow_msg..i18n("flow_details.flow_connecting_msg")
      elseif flow["tcp_established"] then
	 flow_msg = flow_msg..i18n("flow_details.flow_active_msg")
      else
	 flow_msg = flow_msg.." "..i18n("flow_details.flow_peer_roles_inaccurate_msg")
      end

      print(flow_msg)
      print("</td></tr>\n")
   end

   -- ######################################
   
   local icmp = flow["icmp"]

   if(icmp ~= nil) then
      print("<tr><th width=30%>"..i18n("flow_details.icmp_info").."</th><td colspan=2>".. getICMPTypeCode(icmp))

      if icmp["unreach"] then
	 local unreachable_flow = interface.findFlowByTuple(flow["cli.ip"], flow["srv.ip"], flow["vlan"], icmp["unreach"]["dst_port"], icmp["unreach"]["src_port"], icmp["unreach"]["protocol"])

	 if unreachable_flow then
	    print(" ["..i18n("flow")..": ")
	    print(" <A HREF='"..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="..unreachable_flow["ntopng.key"].."'><span class='label label-info'>Info</span></A>")
	    print(" "..getFlowLabel(unreachable_flow, true, true))
	    print("]")
	 else
	 end
      end

      print("</td></tr>")
   end

   -- ######################################
   
   if interface.isPacketInterface() then
      print("<tr><th width=30%>"..i18n("flow_details.flow_status").."</th><td colspan=2>"..getFlowStatus(flow["flow.status"], flow2statusinfo(flow)).."</td></tr>\n")
   end

   if((flow.client_process == nil) and (flow.server_process == nil)) then
      print("<tr><th width=30%>"..i18n("flow_details.actual_peak_throughput").."</th><td width=20%>")
      if (throughput_type == "bps") then
	 print("<span id=throughput>" .. bitsToSize(8*flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      elseif (throughput_type == "pps") then
	 print("<span id=throughput>" .. pktsToSize(flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      end

      if (throughput_type == "bps") then
	 print(" / <span id=top_throughput>" .. bitsToSize(8*flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      elseif (throughput_type == "pps") then
	 print(" / <span id=top_throughput>" .. pktsToSize(flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      end

      print("</td><td><span id=thpt_load_chart>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>")
      print("</td></tr>\n")
   else
      if((flow.client_process ~= nil) or (flow.server_process ~= nil)) then
	 local epbf_utils = require "ebpf_utils"
	 print('<tr><th colspan=3><div id="sprobe"></div>')

	 local width  = 1024
	 local height = 200
	 local url = ntop.getHttpPrefix().."/lua/get_flow_process_tree.lua?flow_key="..flow_key
	 epbf_utils.draw_flow_processes_graph(width, height, url)

	 print('</th></tr>\n')
      end

      if(flow.client_process ~= nil) then
	 displayProc(flow.client_process,
	     "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.client_process_information").."</th></tr>\n")
      end
      if(flow.client_container ~= nil) then
	 displayContainer(flow.client_container,
			  "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.client_container_information").."</th></tr>\n")
      end
      if(flow.server_process ~= nil) then	 
	 displayProc(flow.server_process,
                     "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.server_process_information").."</th></tr>\n")
      end
      if(flow.server_container ~= nil) then	 
	 displayContainer(flow.server_container,
			  "<tr><th colspan=3 class=\"info\">"..i18n("flow_details.server_container_information").."</th></tr>\n")
      end      
   end

   if(flow["protos.dns.last_query"] ~= nil) then
      print("<tr><th width=30%>"..i18n("flow_details.dns_query").."</th><td colspan=2>")
      if(string.ends(flow["protos.dns.last_query"], "arpa")) then
	 print(flow["protos.dns.last_query"])
      else
	 print("<A HREF=\"http://"..flow["protos.dns.last_query"].."\">"..flow["protos.dns.last_query"].."</A> <i class='fa fa-external-link'></i>")
      end

      if(flow["category"] ~= nil) then
	 print(" "..getCategoryIcon(flow["protos.dns.last_query"], flow["category"]))
      end

      printAddCustomHostRule(flow["protos.dns.last_query"])

      print("</td></tr>\n")
   end

   if(not isEmptyString(flow["bittorrent_hash"])) then
      print("<tr><th>"..i18n("flow_details.bittorrent_hash").."</th><td colspan=4><A HREF=\"https://www.google.it/search?q="..flow["bittorrent_hash"].."\">".. flow["bittorrent_hash"].."</A></td></tr>\n")
   end

   if(not isEmptyString(flow["protos.ssh.client_signature"])) then
      print("<tr><th>"..i18n("flow_details.ssh_signature").."</th><td><b>"..i18n("client")..":</b> "..(flow["protos.ssh.client_signature"] or '').."</td><td><b>"..i18n("server")..":</b> "..(flow["protos.ssh.server_signature"] or '').."</td></tr>\n")
   end

   if(flow["protos.http.last_url"] ~= nil) then
      print("<tr><th width=30% rowspan=4>"..i18n("http").."</th>")
      print("<th>"..i18n("flow_details.http_method").."</th><td>"..(flow["protos.http.last_method"] or '').."</td>")
      print("</tr>")

      print("<tr><th>"..i18n("flow_details.server_name").."</th><td colspan=2>")
      local s = flowinfo2hostname(flow,"srv")
      if(not isEmptyString(flow["host_server_name"])) then
	 s = flow["host_server_name"]
      end
      print("<A HREF=\"http://"..s.."\">"..s.."</A> <i class=\"fa fa-external-link\"></i>")
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["host_server_name"], flow["category"])) end
      printAddCustomHostRule(s)
      print("</td></tr>\n")

      print("<tr><th>"..i18n("flow_details.url").."</th><td colspan=2>")
      print("<A HREF=\"http://")
      if(flow["srv.port"] ~= 80) then print(":"..flow["srv.port"]) end
      print(flow["protos.http.last_url"].."\">"..shortenString(flow["protos.http.last_url"] or '', 64).."</A> <i class=\"fa fa-external-link\">")
      print("</td></tr>\n")

      if not have_nedge then
        print("<tr><th>"..i18n("flow_details.response_code").."</th><td colspan=2>"..(flow["protos.http.last_return_code"] or '').."</td></tr>\n")
      end
   else
      if((flow["host_server_name"] ~= nil) and (flow["protos.dns.last_query"] == nil)) then
	 print("<tr><th width=30%>"..i18n("flow_details.server_name").."</th><td colspan=2><A HREF=\"http://"..flow["host_server_name"].."\">"..flow["host_server_name"].."</A> <i class=\"fa fa-external-link\"></i>")
	 if not isEmptyString(flow["protos.http.server_name"]) then
	    printAddCustomHostRule(flow["protos.http.server_name"])
	 end
	 print("</td></tr>\n")
      end
   end

   if(flow["profile"] ~= nil) then
      print("<tr><th width=30%><A HREF=\"".. ntop.getHttpPrefix() .."/lua/pro/admin/edit_profiles.lua\">"..i18n("flow_details.profile_name").."</A></th><td colspan=2><span class='label label-primary'>"..flow["profile"].."</span></td></tr>\n")
   end

   if (flow["moreinfo.json"] ~= nil) then
      local flow_field_value_maps = require "flow_field_value_maps"
      local info, pos, err = json.decode(flow["moreinfo.json"], 1, nil)
      local isThereSIP = 0
      local isThereRTP = 0

      -- Convert the array to symbolic identifiers if necessary
      local syminfo = {}
      for key, value in pairs(info) do
	 key, value = flow_field_value_maps.map_field_value(ifid, key, value)

	 local k = rtemplate[tonumber(key)]
	 if(k ~= nil) then
	    syminfo[k] = value
	 else
	    syminfo[key] = value
	 end
      end
      info = syminfo

      
      -- get SIP rows
      if(ntop.isPro() and (flow["proto.ndpi"] == "SIP")) then
        local sip_table_rows = getSIPTableRows(info)
        print(sip_table_rows)

        isThereSIP = isThereProtocol("SIP", info)
        if(isThereSIP == 1) then
	   isThereSIP = isThereSIPCall(info)
        end
      end
      info = removeProtocolFields("SIP",info)

      -- get RTP rows
      if(ntop.isPro() and (flow["proto.ndpi"] == "RTP")) then
        local rtp_table_rows = getRTPTableRows(info)
        print(rtp_table_rows)

	-- io.write(flow["proto.ndpi"].."\n")
	isThereRTP = isThereProtocol("RTP", info)
      end
      info = removeProtocolFields("RTP",info)

      local snmpdevice = nil
      if(ntop.isPro() and not isEmptyString(syminfo["EXPORTER_IPV4_ADDRESS"])) then
	 snmpdevice = syminfo["EXPORTER_IPV4_ADDRESS"]
      elseif(ntop.isPro() and not isEmptyString(syminfo["NPROBE_IPV4_ADDRESS"])) then
	 snmpdevice = syminfo["NPROBE_IPV4_ADDRESS"]
      end

      if not isEmptyString(snmpdevice) and syminfo["INPUT_SNMP"] and syminfo["OUTPUT_SNMP"] then
	 printFlowSNMPInfo(snmpdevice, syminfo["INPUT_SNMP"], syminfo["OUTPUT_SNMP"])
      end

      local num = 0
      for key,value in pairsByKeys(info) do
	 if(num == 0) then
	    print("<tr><th colspan=3 class=\"info\">"..i18n("flow_details.additional_flow_elements").."</th></tr>\n")
	 end
	 if(value ~= "") then
	    print("<tr><th width=30%>" .. getFlowKey(key) .. "</th><td colspan=2>" .. handleCustomFlowField(key, value, snmpdevice) .. "</td></tr>\n")
	 end

	 num = num + 1
      end
   end
   print("</table>\n")
end

print [[
<script>
/*
      $(document).ready(function() {
	      $('.progress .bar').progressbar({ use_percentage: true, display_text: 1 });
   });
*/


var thptChart = $("#thpt_load_chart").peity("line", { width: 64 });
]]

if(flow ~= nil) then
   if (flow["cli2srv.packets"] ~= nil ) then
      print("var cli2srv_packets = " .. flow["cli2srv.packets"] .. ";")
   end
   if (flow["srv2cli.packets"] ~= nil) then
      print("var srv2cli_packets = " .. flow["srv2cli.packets"] .. ";")
   end
   if (flow["throughput_"..throughput_type] ~= nil) then
      print("var throughput = " .. flow["throughput_"..throughput_type] .. ";")
   end
   print("var bytes = " .. flow["bytes"] .. ";")
   print("var goodput_bytes = " .. flow["goodput_bytes"] .. ";")
end

print [[
function update () {
	  $.ajax({
		    type: 'GET',
		    url: ']]
print (ntop.getHttpPrefix())
print [[/lua/flow_stats.lua',
		    data: { ifid: "]] print(tostring(ifid)) print [[", flow_key: "]] print(flow_key) print [[" },
		    success: function(content) {
                        if(content == "{}") {
   ]]

-- If the flow is already idle, another error message is already shown
if(flow ~= nil) then
   print[[
                          var e = document.getElementById('flow_purged');
                          e.style.display = "block";
   ]]
end

print[[
                        } else {
			var rsp = jQuery.parseJSON(content);
			$('#first_seen').html(rsp["seen.first"]);
			$('#last_seen').html(rsp["seen.last"]);
			$('#volume').html(bytesToVolume(rsp.bytes));
			$('#goodput_volume').html(bytesToVolume(rsp["goodput_bytes"]));
			pctg = ((rsp["goodput_bytes"]*100)/rsp["bytes"]).toFixed(1);

			/* 50 is the same threshold specified in FLOW_GOODPUT_THRESHOLD */
			if(pctg < 50) { pctg = "<font color=red>"+pctg+"</font>"; } else if(pctg < 60) { pctg = "<font color=orange>"+pctg+"</font>"; }

			$('#goodput_percentage').html(pctg);
			$('#cli2srv').html(addCommas(rsp["cli2srv.packets"])+" Pkts / "+bytesToVolume(rsp["cli2srv.bytes"]));
			$('#srv2cli').html(addCommas(rsp["srv2cli.packets"])+" Pkts / "+bytesToVolume(rsp["srv2cli.bytes"]));
			$('#throughput').html(rsp.throughput);

			if(typeof rsp["c2sOOO"] !== "undefined") {
			   $('#c2sOOO').html(formatPackets(rsp["c2sOOO"]));
			   $('#s2cOOO').html(formatPackets(rsp["s2cOOO"]));
			   $('#c2slost').html(formatPackets(rsp["c2slost"]));
			   $('#s2clost').html(formatPackets(rsp["s2clost"]));
			   $('#c2skeep_alive').html(formatPackets(rsp["c2skeep_alive"]));
			   $('#s2ckeep_alive').html(formatPackets(rsp["s2ckeep_alive"]));
			   $('#c2sretr').html(formatPackets(rsp["c2sretr"]));
			   $('#s2cretr').html(formatPackets(rsp["s2cretr"]));
			}
			if (rsp["cli2srv_quota"]) $('#cli2srv_quota').html(rsp["cli2srv_quota"]);
			if (rsp["srv2cli_quota"]) $('#srv2cli_quota').html(rsp["srv2cli_quota"]);

			/* **************************************** */

			if(cli2srv_packets == rsp["cli2srv.packets"]) {
			   $('#sent_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#sent_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(srv2cli_packets == rsp["srv2cli.packets"]) {
			   $('#rcvd_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#rcvd_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(bytes == rsp["bytes"]) {
			   $('#volume_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#volume_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(goodput_bytes == rsp["goodput_bytes"]) {
			   $('#goodput_volume_trend').html("<i class=\"fa fa-minus\"></i>");
			} else {
			   $('#goodput_volume_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			}

			if(throughput > rsp["throughput_raw"]) {
			   $('#throughput_trend').html("<i class=\"fa fa-arrow-down\"></i>");
			} else if(throughput < rsp["throughput_raw"]) {
			   $('#throughput_trend').html("<i class=\"fa fa-arrow-up\"></i>");
			   $('#top_throughput').html(rsp["top_throughput_display"]);
			} else {
			   $('#throughput_trend').html("<i class=\"fa fa-minus\"></i>");
			} ]]

      if(isThereSIP == 1) then
	updatePrintSip()
      end
      if(isThereRTP == 1) then
	updatePrintRtp()
      end
print [[			cli2srv_packets = rsp["cli2srv.packets"];
			srv2cli_packets = rsp["srv2cli.packets"];
			throughput = rsp["throughput_raw"];
			bytes = rsp["bytes"];

	 /* **************************************** */
	 // Processes information update, based on the pid

	 for (var pid in rsp["processes"]) {
	    var proc = rsp["processes"][pid]
	    // console.log(pid);
	    // console.log(proc);
	    if (proc["memory"])           $('#memory_'+pid).html(proc["memory"]);
	    if (proc["average_cpu_load"]) $('#average_cpu_load_'+pid).html(proc["average_cpu_load"]);
	    if (proc["percentage_iowait_time"]) $('#percentage_iowait_time_'+pid).html(proc["percentage_iowait_time"]);
	    if (proc["page_faults"])      $('#page_faults_'+pid).html(proc["page_faults"]);
	 }

			/* **************************************** */

			var values = thptChart.text().split(",");
			values.shift();
			values.push(rsp.throughput_raw);
			thptChart.text(values.join(",")).change();
		     } }
		   });
		 }

]]

print ("setInterval(update,3000);\n")

print [[
</script>
 ]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
