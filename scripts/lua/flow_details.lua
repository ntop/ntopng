--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "voip_utils"

local shaper_utils

local format_utils = require "format_utils"
local have_nedge = ntop.isnEdge()
local nf_config = nil
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local dscp_consts = require "dscp_consts"
local tag_utils = require "tag_utils"
local flow_risk_utils = require "flow_risk_utils"
local flow_consts = require "flow_consts"
local template = require "template_utils"
local categories_utils = require "categories_utils"
local protos_utils = require("protos_utils")
local discover = require("discover_utils")
local http_utils = require("http_utils")
local json = require ("dkjson")
local page_utils = require("page_utils")
local icmp_utils = require("icmp_utils")

if ntop.isPro() then
  package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
  shaper_utils = require("shaper_utils")

  if ntop.isnEdge() then
    package.path = dirs.installdir .. "/scripts/lua/pro/nedge/modules/system_config/?.lua;" .. package.path
    nf_config = require("nf_config")
  end
end

function formatASN(v)
   local asn

   if(v == 0) then
      asn = "&nbsp;"
   else
      asn = "<A HREF=\"".. ntop.getHttpPrefix() .."/lua/hosts_stats.lua?asn=" .. v .. "\">".. v .."</A>"
   end

   print("<td>"..asn.."</td>\n")
end

local function colorNotZero(v)
   if(v == 0) then
      return("0")
   else
      return('<span style="color: red">'..formatValue(v).."</span>")
   end
end

local function drawiecgraph(iec, total)
   local nodes = {}
   local nodes_id = {}

   -- tprint(iec)

   for k,v in pairs(iec) do
      local keys = split(k, ",")

      nodes[keys[1]] = true
      nodes[keys[2]] = true
   end

   print[[
      <div style="width:100%; height:30vh; " id="myiecflow"></div>

  <script type="application/javascript">
      var nodes = null;
      var edges = null;
      var network = null;

      function draw() {
        // create people.
        // value corresponds with the age of the person
        nodes = [
]]
      local i = 1
   for k,_ in pairs(nodes) do
      local label = iec104_typeids2str(tonumber(k))

      print("{ id: "..i..", label: \""..label.."\" },\n")
      nodes_id[k] = i
      i = i + 1
   end

   print [[
   ];

        // create connections between people
        // value corresponds with the amount of contact between two people
        edges = [
]]

   local uni = {}
   local bi = {}

   for k,v in pairs(iec) do
      local keys = split(k, ",")

      if(iec[keys[2]..","..keys[1]] == nil) then
         uni[k] = v
      else
         if(keys[2] < keys[1]) then
            bi[keys[2]..","..keys[1]] = v
         else
            bi[keys[1]..","..keys[2]] = v
         end
      end
   end

   for k,v in pairs(uni) do
      local keys = split(k, ",")
      local label = string.format("%.3f %%", (v*100)/total)

      nodes[keys[1]] = true
      nodes[keys[2]] = true

      print("{ from: "..nodes_id[keys[1]]..", to: "..nodes_id[keys[2]]..", value: "..v..", title: \""..label.."\", arrows: \"to\" },\n")
   end

   for k,v in pairs(bi) do
      local keys = split(k, ",")
      local label = string.format("%.3f %%", (v*100)/total)

      nodes[keys[1]] = true
      nodes[keys[2]] = true

      print("{ from: "..nodes_id[keys[1]]..", to: "..nodes_id[keys[2]]..", value: "..v..", title: \""..label.."\", arrows: \"to,from\" },\n")
   end

   print [[
        ];

        // Instantiate our network object.
        var container = document.getElementById("myiecflow");
        var data = {
          nodes: nodes,
          edges: edges,
        };
        var options = {
          autoResize: true,
          nodes: {
            shape: "dot",
            scaling: {
              label: {
                min: 2,
                max: 80,
              },
            },
          },
          edges: {
              width: 0.15,
              color: { inherit: "from" },
              smooth: {
                  type: "continuous",
                  roundness: 0
              },
          },
          physics: {
              barnesHut: {
                  springConstant: 0,
                  avoidOverlap: 0.3,
                  gravitationalConstant: -1000,
                  damping: 0.65,
                  centralGravity: 0
              },
              stabilization: {
                  onlyDynamicEdges: false
              }
          },
        };
        network = new vis.Network(container, data, options);
      }

draw();


    </script>
       ]]
end


local function ja3url(what, safety, label)
   if(what == nil) then
      print("&nbsp;")
   else
      print(format_external_link("sslbl.abuse.ch/ja3-fingerprints/".. what .."/", what, false, "https"))

      if((safety ~= nil) and (safety ~= "safe")) then
         print(' [ <i class="fas fa-exclamation-triangle" aria-hidden=true style="color: orange;"></i> <A HREF=https://en.wikipedia.org/wiki/Cipher_suite>'..capitalize(safety)..' Cipher</A> ]')
      end
   end
end


sendHTTPContentTypeHeader('text/html')


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
         local label = interface.getnDPICategoryName(category_id)

         alert_banners[#alert_banners + 1] = {
            type="success",
            text=i18n("flow_details.host_successfully_added_to_category",
               {host=_POST["custom_hosts"], category=(i18n("ndpi_categories." .. label) or label),
               url = ntop.getHttpPrefix() .. "/lua/admin/edit_categories.lua?l7proto=" .. category_id})
         }
      else
         local label = interface.getnDPICategoryName(category_id)

         alert_banners[#alert_banners + 1] = {
            type="danger",
            text=i18n("flow_details.could_not_add_host_to_category",
               {host=_POST["custom_hosts"], category=(i18n("ndpi_categories." .. label) or label)})
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
   local cat_select_dropdown = '<select id="flow_target_category" class="form-select">'

   for cat_name, cat_id in pairsByKeys(categories, asc_insensitive) do
      cat_select_dropdown = cat_select_dropdown .. [[<option value="cat_]] ..cat_id .. [[">]] .. (i18n("ndpi_categories." .. cat_name) or cat_name) .. [[</option>]]
   end
   cat_select_dropdown = cat_select_dropdown .. "</select>"

   -- Fill the application dropdown
   local app_select_dropdown = '<select id="flow_target_app" class="form-select" style="display:none">'

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
      local cat_name = interface.getnDPICategoryName(matched_category)

      existing_note = existing_note .. "<br><br>" .. i18n("details.note") .. ": " ..
         i18n("custom_categories.similar_host_found", {host=page_utils.safe_html(full_url), category=(i18n("ndpi_categories." .. cat_name) or cat_name)}) ..
         "<br><br>"
   end

   local rule_type_selection = ""
   if protos_utils.hasProtosFile() then
      rule_type_selection = i18n("flow_details.rule_type")..":"..[[<br><select id="new_rule_type" onchange="new_rule_dropdown_select(this)" class="form-select">
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

   print(' <a href="#" onclick="$(\'#add_to_customized_categories\').modal(\'show\'); return false;"><i title="'.. i18n("custom_categories.add_to_categories") ..'" class="fas fa-plus"></i></a>')

   print[[<script>
   function addToCustomizedCategories() {
      var is_category = ($("#new_rule_type").val() == "category");
      var target_value = is_category ? $("#flow_target_category").val() : $("#flow_target_app").val();;
      var target_url = NtopUtils.cleanCustomHostUrl($("#categories_url_add").val());

      if(!target_value || !target_url)
         return;

      var params = {};
      params.custom_hosts = target_url;
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
      if(is_category)
         params.category = target_value;
      else
         params.l7proto = target_value;

      NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
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

   print("<tr><th width=30%>"..i18n("flow_details.process_pid_name").."</th><td colspan=2><A HREF=\""..ntop.getHttpPrefix().."/lua/process_details.lua?pid=".. proc.pid .."&pid_name=".. proc.name .. "&" .. hostinfo2url(flow,"srv").. "\">".. proc.name .. "</a> ")
   if proc.pid then
     print("["..i18n("flow_details.process_pid") .. ": "..proc.pid.."]")
   end
   if not isEmptyString(proc.pkg_name) then
     print("  ["..i18n("flow_details.process_package") .. ": " .. proc.pkg_name.."] ")
   end

   if not isEmptyString(proc.father_name) then
      print(" "..i18n("flow_details.son_of_father_process") .. " <a href ='"..ntop.getHttpPrefix().."/lua/process_details.lua?pid="..proc.father_pid .. "&pid_name=".. proc.father_name .. "&" .. hostinfo2url(flow,"srv") .. "'>"..proc.father_name.."</a> ")
     if proc.father_pid then
       print(i18n("flow_details.process_pid")..": ".. proc.father_pid)
     end
     if not isEmptyString(proc.father_pkg_name) then
       print(" "..i18n("flow_details.process_package") .. ": " .. proc.father_pkg_name)
     end
   end
   print("</td></tr>")

   if((proc.actual_memory ~= nil) and (proc.actual_memory > 0)) then
      print("<tr><th width=30%>"..i18n("graphs.actual_memory").."</th><td colspan=2>".. bytesToSize(proc.actual_memory * 1024) .. "</td></tr>\n")
      print("<tr><th width=30%>"..i18n("graphs.peak_memory").."</th><td colspan=2>".. bytesToSize(proc.peak_memory * 1024) .. "</td></tr>\n")
   end
end

page_utils.set_active_menu_entry(page_utils.menu_entries.flow_details)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

printMessageBanners(alert_banners)

if not table.empty(alert_banners) then
   print("<br>")
end

print('<div style=\"display:none;\" id=\"flow_purged\" class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle fa-lg"></i>&nbsp;'..i18n("flow_details.now_purged")..'</div>')

throughput_type = getThroughputType()

local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]

flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))

local ifid = interface.name2id(ifname)
local label = getFlowLabel(flow, nil, nil, nil, nil, nil, false)
local title = i18n("flow")..": "..label
local url = ntop.getHttpPrefix().."/lua/flow_details.lua"

page_utils.print_navbar(title, url,
                        {
                           {
                              active = true,
                              page_name = "overview",
                              label = i18n("overview"),
                           },
                        }
)

if(flow == nil) then
   print('<div class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle fa-lg"></i> '..i18n("flow_details.flow_cannot_be_found_message")..' '.. purgedErrorString()..'</div>')
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
      print("</th><td colspan=2>" .. getFullVlanName(flow["vlan"]) .. "</td></tr>\n")
   end

   print("<tr><th width=30%>"..i18n("flow_details.flow_peers_client_server").."</th><td colspan=2>"..getFlowLabel(flow, true, not ifstats.isViewed --[[ don't add hyperlinks, viewed interface don't have hosts --]], nil, nil, false --[[ add flags ]]))

   if(flow.periodic_flow) then
      print(" <span class='badge bg-warning text-dark'>"..i18n("periodic_flow").."</span>")
   end

   print("</td></tr>\n")

   print("<tr><th width=30%>"..i18n("protocol").." / "..i18n("application").."</th>")
   if((ifstats.inline and flow["verdict.pass"]) or (flow.vrfId ~= nil)) then
      print("<td>")
   else
      print("<td colspan=2>")
   end

   if(flow["verdict.pass"] == false) then print("<strike>") end
   print(flow["proto.l4"].." / ")

   if(flow["proto.ndpi_id"] == -1) then
      print(flow["proto.ndpi"])
   else
      print("<A HREF=\""..ntop.getHttpPrefix().."/lua/")
      if((flow.client_process ~= nil) or (flow.server_process ~= nil))then        print("s") end
      print("flows_stats.lua?application=" .. flow["proto.ndpi"] .. "\">")
      print(getApplicationLabel(flow["proto.ndpi"],32).."</A> ")

      print("(<A HREF=\""..ntop.getHttpPrefix().."/lua/")
      print("flows_stats.lua?category=" .. flow["proto.ndpi_cat"] .. "\">")
      print(getCategoryLabel(flow["proto.ndpi_cat"], interface.getnDPICategoryId(flow["proto.ndpi_cat"])).."</A>")
      if(flow["proto.ndpi_cat_file"]) then
         print(" @ " ..flow["proto.ndpi_cat_file"])
      end
      print(") ".. formatBreed(flow["proto.ndpi_breed"], flow["proto.is_encrypted"]))

      if(flow["proto.ndpi_address_family"] ~= nil) then
         print(" [".. i18n("network") ..": "..flow["proto.ndpi_address_family"].."]")
      end
      
      if(flow.confidence) and (not isEmptyString(flow.confidence)) then
        print(" ["..i18n("ndpi_confidence")..": "..format_confidence_badge(flow.confidence).."]")
      end

      if(flow.rtp_stream_type ~= nil) then
	 print(" [ ")
	 if(flow.rtp_stream_type == "screen_share") then
	    print('<i class="fas fa-desktop"></i> <span class="badge bg-secondary">'.. i18n("rtp.screen_share")..'</span>')
	 elseif(flow.rtp_stream_type == "audio") then
	    print('<i class="fas fa-volume-up"></i> <span class="badge bg-secondary">'.. i18n("rtp.audio")..'</span>')
	 elseif(flow.rtp_stream_type == "video") then
	    print('<i class="fas fa-desktop"></i> <span class="badge bg-secondary">'.. i18n("rtp.video")..'</span>')
	 elseif(flow.rtp_stream_type == "audio_video") then
	    print('<i class="fas fa-video"></i> <span class="badge bg-secondary">'.. i18n("rtp.audio_video")..'</span>')
	 end
	 print(" ]")
      end
    end

   if(flow["verdict.pass"] == false) then print("</strike>") end
   historicalProtoHostHref(ifid, flow["cli.ip"], flow["proto.l4"], flow["proto.ndpi_id"], page_utils.safe_html(flow["protos.tls.certificate"] or ''))

   if((flow["protos.tls_version"] ~= nil)
      and (flow["protos.tls_version"] ~= 0)) then
      local tls_version_name = ntop.getTLSVersionName(flow["protos.tls_version"])

      if isEmptyString(tls_version_name) then
         print(" [ TLS"..flow["protos.tls_version"].." ]")
      else
         print(" [ "..tls_version_name.." ]")
      end
      if(tonumber(flow["protos.tls_version"]) < 771) then
         print(' <i class="fas fa-exclamation-triangle" aria-hidden=true style="color: orange;"></i> ')
         print(i18n("flow_details.tls_old_protocol_version"))
      end
   end

   if(ifstats.inline) then
      if(flow["verdict.pass"]) then
         print('<form class="form-inline float-right" style="margin-bottom: 0px;" method="post">')
         print('<input type="hidden" name="drop_flow_policy" value="true">')
         print('<button type="submit" class="btn btn-secondary btn-sm"><i class="fas fa-ban"></i> '..i18n("flow_details.drop_flow_traffic_btn")..'</button>')
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
      local host_pools_nedge = require("host_pools_nedge")
      print("<tr><th width=30% rowspan=2>"..i18n("flow_details.flow_shapers").."</th>")
      c = flowinfo2hostname(flow,"cli")
      s = flowinfo2hostname(flow,"srv")

      if flow["cli.pool_id"] ~= nil then
        c = c .. " (<a href='".. host_pools_nedge.getUserUrl(flow["cli.pool_id"]) .."'>".. host_pools_nedge.poolIdToUsername(flow["cli.pool_id"]) .."</a>)"
      end

      if flow["srv.pool_id"] ~= nil then
        s = s .. " (<a href='".. host_pools_nedge.getUserUrl(flow["srv.pool_id"]) .."'>".. host_pools_nedge.poolIdToUsername(flow["srv.pool_id"]) .."</a>)"
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
        print("<td colspan=2>".. nf_config.formatMarker(flow["marker"]) .."</td>")
        print("</tr>")
      end

      local alert_info = flow2alertinfo(flow)
      local forbidden_proto = flow["proto.ndpi_id"]
      local forbidden_peer = nil

      if alert_info then
         forbidden_proto = alert_info["devproto_forbidden_id"] or forbidden_proto
         forbidden_peer = alert_info["devproto_forbidden_peer"]
      end

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

      if(num_rows > 0) then
        print("<tr><th width=30% rowspan=".. num_rows ..">"..i18n("device_protocols.device_protocol_policy").."</th>")

        if(cli_show) then
          print("<td>"..i18n("device_protocols.devtype_as_proto_client", {devtype=discover.devtype2string(flow["cli.devtype"]), proto=interface.getnDPIProtoName(forbidden_proto)}).."</td>")
          print("<td><a href=\"".. getDeviceProtocolPoliciesUrl("device_type=" .. flow["cli.devtype"]) .."&l7proto=".. forbidden_proto .."\">")
          print(i18n(ternary(forbidden_peer ~= "cli", "allowed", "forbidden")))
          print("</a></td></tr><tr>")
        end

        if(srv_show) then
          print("<td>"..i18n("device_protocols.devtype_as_proto_server", {devtype=discover.devtype2string(flow["srv.devtype"]), proto=interface.getnDPIProtoName(forbidden_proto)}).."</td>")
          print("<td><a href=\"".. getDeviceProtocolPoliciesUrl("device_type=" .. flow["srv.devtype"]) .."&l7proto=".. forbidden_proto .."\">")
          print(i18n(ternary(forbidden_peer ~= "srv", "allowed", "forbidden")))
          print("</a></td></tr><tr>")
        end
      end
   end

   print("<tr><th width=33%>"..i18n("details.first_last_seen").."</th><td nowrap width=33%><div id=first_seen>"
	 .. formatEpoch(flow["seen.first"]) ..  " [" .. secondsToTime(os.time()-flow["seen.first"]) .. " "..i18n("details.ago").."]" .. "</div></td>\n")
   print("<td nowrap><div id=last_seen>" .. formatEpoch(flow["seen.last"]) .. " [" .. secondsToTime(os.time()-flow["seen.last"]) .. " "..i18n("details.ago").."]" .. "</div></td></tr>\n")

   if flow["bytes"] > 0 then
      print("<tr><th width=30% rowspan=3>"..i18n("details.total_traffic").."</th><td>"..i18n("total")..": <span id=volume>" .. bytesToSize(flow["bytes"]) .. "</span> <span id=volume_trend></span></td>")
      if((ifstats.type ~= "zmq") and ((flow["proto.l4"] == "TCP") or (flow["proto.l4"] == "UDP")) and (flow["goodput_bytes"] > 0)) then
         print("<td><A class=\"ntopng-external-link\" HREF=\"https://en.wikipedia.org/wiki/Goodput\">"..i18n("details.goodput").."</A> <i class=\"fas fa-external-link-alt\"></i> : <span id=goodput_volume>" .. bytesToSize(flow["goodput_bytes"]) .. "</span> (<span id=goodput_percentage>")
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

      print("<tr><td nowrap>" .. i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("server") .. ": <span id=cli2srv>" .. formatPackets(flow["cli2srv.packets"]) .. " / ".. bytesToSize(flow["cli2srv.bytes"]) .. "</span> <span id=sent_trend></span></td><td nowrap>" .. i18n("client") .. " <i class=\"fas fa-long-arrow-alt-left\"></i> " .. i18n("server") .. ": <span id=srv2cli>" .. formatPackets(flow["srv2cli.packets"]) .. " / ".. bytesToSize(flow["srv2cli.bytes"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

      print("<tr><td colspan=2>")
      cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)

      local cli_name = shortHostName(flowinfo2hostname(flow, "cli"))
      local srv_name = shortHostName(flowinfo2hostname(flow, "srv"))

      if(flow["cli.port"] > 0) then
         cli_name = cli_name .. ":" .. flow["cli.port"]
         srv_name = srv_name .. ":" .. flow["srv.port"]
      end
      print('<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. cli2srv.. '%;">'.. cli_name..'</div><div class="progress-bar bg-success" style="width: ' .. (100-cli2srv) .. '%;">' .. srv_name .. '</div></div>')
      print("</td></tr>\n")
   end

   if(flow.iec104 and (table.len(flow.iec104.typeid) > 0)) then
      print("<tr><th rowspan=6 width=30%><A class='ntopng-external-link' href='https://en.wikipedia.org/wiki/IEC_60870-5'>IEC 60870-5-104  <i class='fas fa-external-link-alt'></i></A></th><th>"..i18n("flow_details.iec104_mask").."</th><td>")

      total = 0
      for k,v in pairsByKeys(flow.iec104.typeid, rev) do
         total = total + v
      end

      print("<table border width=100%>")
      for k,v in pairsByValues(flow.iec104.typeid, rev) do
         local pctg = (v*100)/total
         local key = iec104_typeids2str(tonumber(k))

         print(string.format("<th>%s</th><td align=right>%.3f %%</td></tr>\n", key, pctg))
      end

      print("</table>\n")
      print("</td></tr>\n")

      -- #########################

      total = 0
      for k,v in pairsByValues(flow.iec104.typeid_transitions, rev) do
         total = total+v
      end

      print("<tr><th>".. i18n("flow_details.iec104_transitions"))
      drawiecgraph(flow.iec104.typeid_transitions, total)
      print("</th><td>")

      print("<table border width=100%>")
      for k,v in pairsByValues(flow.iec104.typeid_transitions, rev) do
         local pctg = (v*100)/total
         local keys = split(k, ",")
         local key = iec104_typeids2str(tonumber(keys[1]))

         if(keys[1] == keys[2]) then
            key = key ..' <i class="fas fa-exchange-alt"></i> '
         else
            key = key ..' <i class="fas fa-long-arrow-alt-right"></i> '
         end

         key = key .. iec104_typeids2str(tonumber(keys[2]))

         print(string.format("<tr><th>%s</th><td align=right>%.3f %%</td></tr>\n", key, pctg))
      end

      print("</table>\n")
      print("</td></tr>\n")

      -- #########################

      print("<tr><th>"..i18n("flow_details.iec104_latency").."</th><td>")
      if(flow.iec104.ack_time.stddev > flow.iec104.ack_time.average) then
         on = "<font color=red>"
         off = "</font>"
      else
         on = ""
         off = ""
      end
      if((flow.iec104.ack_time.average > 1000) or (flow.iec104.ack_time.stddev > 1000)) then
         print(string.format("%.3f sec (%s%.3f sec%s)", flow.iec104.ack_time.average/1000, on, (flow.iec104.ack_time.stddev/1000), off))
      else
         print(string.format("%.3f ms (%s%.3f msec%s)", flow.iec104.ack_time.average, on, flow.iec104.ack_time.stddev, off))
      end
      print("</td></tr>\n")

      print("<tr><th>"..i18n("flow_details.iec104_msg_breakdown").."</th><td>")
      local total = flow.iec104.stats.forward_msgs + flow.iec104.stats.reverse_msgs
      local pctg = string.format("%.1f", (flow.iec104.stats.forward_msgs * 100) / total)

      if(flow["srv.port"] == 2404) then
         -- we need to swap directions
         pctg = 100-pctg
      end

      print('<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. pctg .. '%;">'..pctg..'% </div>')
      pctg = 100-pctg
      print('<div class="progress-bar bg-success" style="width: ' .. pctg .. '%;">'..pctg..'% </div></div>')
      -- print(formatValue(flow.iec104.stats.forward_msgs).." RX / "..formatValue(flow.iec104.stats.reverse_msgs).." TX")
      print("</td></tr>\n")

      print("<tr><th>"..i18n("flow_details.iec104_msg_loss").."</th><td>")
      print("<i class=\"fas fa-long-arrow-alt-left\"></i> "..colorNotZero(flow.iec104.pkt_lost.rx)..", <i class=\"fas fa-long-arrow-alt-right\"></i> "..colorNotZero(flow.iec104.pkt_lost.tx).." / ")

      if(flow.iec104.stats.retransmitted_msgs == 0) then
         print("0")
      else
         print(colorNotZero(flow.iec104.stats.retransmitted_msgs))
      end
      
      print(" Retransmitted")
      print("</td></tr>\n")

      local url = "/lua/rest/v2/get/flow/l7/iec104.lua?flow_key="..flow_key.."&flow_hash_id="..flow_hash_id.."&ifid="..ifid
      print("<tr><th>"..i18n("download").."&nbsp;<i class=\"fas fa-download fa-lg\"></i></th><td><A HREF=\""..url.."\" download=\"iec104-".. flow_key ..".json\">JSON</A></td></tr>")
   end

   if((flow.tos.client.ECN ~= 0) or (flow.tos.server.DSCP ~= 0)) then
      print("<tr><th width=30%>"..i18n("flow_details.tos").."</th>")
      print("<td>"..(dscp_consts.dscp_descr(flow.tos.client.DSCP)) .." / ".. (dscp_consts.ecn_descr(flow.tos.client.ECN)) .."</td>")
      print("<td>"..(dscp_consts.dscp_descr(flow.tos.server.DSCP)) .." / ".. (dscp_consts.ecn_descr(flow.tos.server.ECN)) .."</td>")
      print("</tr>")
   end

   if(flow["tcp.nw_latency.client"] ~= nil) then
      local rtt = flow["tcp.nw_latency.client"] + flow["tcp.nw_latency.server"]

      if(rtt > 0) then
         local cli2srv = round(flow["tcp.nw_latency.client"], 3)
         local srv2cli = round(flow["tcp.nw_latency.server"], 3)

         print("<tr><th width=30%>"..i18n("flow_details.rtt_breakdown").."</th><td colspan=2>")
         print('<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. (cli2srv * 100 / rtt) .. '%;">'.. cli2srv ..' ms (client)</div>')
         print('<div class="progress-bar bg-success" style="width: ' .. (srv2cli * 100 / rtt) .. '%;">' .. srv2cli .. ' ms (server)</div></div>')
         print("</td></tr>\n")

         c = interface.getAddressInfo(flow["cli.ip"])
         s = interface.getAddressInfo(flow["srv.ip"])

         if(not(c.is_private and s.is_private)) then
            -- Inspired by https://gist.github.com/geraldcombs/d38ed62650b1730fb4e90e2462f16125
            print("<tr><th width=30%><A class='ntopng-external-link' href=\"https://en.wikipedia.org/wiki/Velocity_factor\">"..i18n("flow_details.rtt_distance").." <i class=\"fas fa-external-link-alt\"></i></A></th><td>")
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
   end

   if(flow["tcp.appl_latency"] ~= nil and flow["tcp.appl_latency"] > 0) then
      print("<tr><th width=30%>"..i18n("flow_details.application_latency").."</th><td colspan=2>"..msToTime(flow["tcp.appl_latency"]).."</td></tr>\n")
   end

   if not ntop.isnEdge() then
      if flow["cli2srv.packets"] > 1 and flow["interarrival.cli2srv"] and flow["interarrival.cli2srv"]["max"] > 0 then
         print("<tr><th width=30%")
         if(flow["flow.idle"] == true) then print(" rowspan=2") end
         print(">"..i18n("flow_details.packet_inter_arrival_time").."</th><td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ")
         print(msToTime(flow["interarrival.cli2srv"]["min"]).." / "..msToTime(flow["interarrival.cli2srv"]["avg"]).." / "..msToTime(flow["interarrival.cli2srv"]["max"]))
         print("</td>\n")
         if(flow["srv2cli.packets"] < 2) then
            print("<td>&nbsp;")
         else
            print("<td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ")
            print(msToTime(flow["interarrival.srv2cli"]["min"]).." / "..msToTime(flow["interarrival.srv2cli"]["avg"]).." / "..msToTime(flow["interarrival.srv2cli"]["max"]))
         end
         print("</td></tr>\n")
         if(flow["flow.idle"] == true) then print("<tr><td colspan=2><i class='fas fa-clock-o'></i> <small>"..i18n("flow_details.looks_like_idle_flow_message").."</small></td></tr>") end
      end

      if((flow["cli2srv.fragments"] + flow["srv2cli.fragments"]) > 0) then
         rowspan = 2
         print("<tr><th width=30% rowspan="..rowspan..">"..i18n("flow_details.ip_packet_analysis").."</th>")
         print("<th>&nbsp;</th><th>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server").." / "..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server").."</th></tr>\n")
         print("<tr><th>"..i18n("details.fragments").."</th><td align=right><span id=c2sFrag>".. formatPackets(flow["cli2srv.fragments"]) .."</span> / <span id=s2cFrag>".. formatPackets(flow["srv2cli.fragments"]) .."</span></td></tr>\n")
      end

      if flow["tcp.seq_problems"] then
         rowspan = 1
         if((flow["cli2srv.retransmissions"] + flow["srv2cli.retransmissions"]) > 0) then rowspan = rowspan + 1 end
         if((flow["cli2srv.out_of_order"] + flow["srv2cli.out_of_order"]) > 0)       then rowspan = rowspan + 1 end
         if((flow["cli2srv.lost"] + flow["srv2cli.lost"]) > 0)                       then rowspan = rowspan + 1 end
         if((flow["cli2srv.keep_alive"] + flow["srv2cli.keep_alive"]) > 0)           then rowspan = rowspan + 1 end

         if rowspan > 1 then
            print("<tr><th width=30% rowspan="..rowspan..">"..i18n("flow_details.tcp_packet_analysis").."</th>")
            print("<th></th><th>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server").." / "..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server").."</th></tr>\n")

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

   if(flow["protos.tls.client_requested_server_name"] ~= nil) then
      print("<tr><th width=30%><i class='fas fa-lock'></i> "..i18n("flow_details.tls_certificate").."</th><td>")
      print(i18n("flow_details.client_requested")..":<br>")
      -- TLS, so use https
      print(format_external_link(page_utils.safe_html(flow["protos.tls.client_requested_server_name"]), page_utils.safe_html(flow["protos.tls.client_requested_server_name"]), false, "https"))
      if(flow["category"] ~= nil) then print(" "..getCategoryIcon(flow["protos.tls.client_requested_server_name"], flow["category"])) end
      historicalProtoHostHref(ifid, flow["cli.ip"], nil, flow["proto.ndpi_id"], page_utils.safe_html(flow["protos.tls.client_requested_server_name"] or ''), flow["vlan"])
      printAddCustomHostRule(flow["protos.tls.client_requested_server_name"])
      print("</td>")

      print("<td>")
      if(flow["protos.tls.server_names"] ~= nil) then
         local servers = string.split(flow["protos.tls.server_names"], ",") or {flow["protos.tls.server_names"]}

         print(i18n("flow_details.tls_server_names")..":<br>")
         for i, server in ipairs(servers) do
            if i > 1 then
               print("<br>")
            end

            if starts(server, '*') then
               print(server)
            else
               -- TLS, so use https
               print(format_external_link(server, server, false, "https"))
            end
         end
      end
      print("</td>")
      print("</tr>\n")
   end

   if((flow["protos.tls.notBefore"] ~= nil) or (flow["protos.tls.notAfter"] ~= nil)) then
      local now = os.time()
      print('<tr><th width=30%>'..i18n("flow_details.tls_certificate_validity").."</th><td colspan=2>")

      if((flow["protos.tls.notBefore"] > now) or (flow["protos.tls.notAfter"] < now)) then
         print(" <i class=\"fas fa-exclamation-triangle fa-lg\" style=\"color: #f0ad4e;\"></i>")
      end

      print(formatEpoch(flow["protos.tls.notBefore"]))
      print(" - ")
      print(formatEpoch(flow["protos.tls.notAfter"]))
      print("</td></tr>\n")
   end

   if(flow["protos.tls.issuerDN"] ~= nil) then
      print('<tr><th width=30%>TLS issuerDN</A></th><td colspan=2>'..flow["protos.tls.issuerDN"]..'</td></tr>\n')
   end

   if(flow["protos.tls.subjectDN"] ~= nil) then
      print('<tr><th width=30%>TLS subjectDN</A></th><td colspan=2>'..flow["protos.tls.subjectDN"]..'</td></tr>\n')
   end

   if((flow["protos.tls.ja3.client_hash"] ~= nil) or (flow["protos.tls.ja3.server_hash"] ~= nil)) then
      print('<tr><th width=30%><A HREF="https://github.com/salesforce/ja3">JA3C / JA3S</A></th><td>')
      if(flow["protos.tls.ja3.client_malicious"]) then
         print('<font color=red><i class="fas fa-ban" title="'.. i18n("alerts_dashboard.malicious_signature_detected") ..'"></i></font> ')
      end

      ja3url(flow["protos.tls.ja3.client_hash"], nil, 'ja3c')
      print("</td><td>")
      if(flow["protos.tls.ja3.server_malicious"]) then
        print('<font color=red><i class="fas fa-ban" title="'.. i18n("alerts_dashboard.malicious_signature_detected") ..'"></i></font> ')
      end

      ja3url(flow["protos.tls.ja3.server_hash"], flow["protos.tls.ja3.server_unsafe_cipher"], 'ja3s')
      --print(tls_consts.cipher2str(flow["protos.tls.ja3.server_cipher"]))
      print("</td></tr>")
   end

   if(flow["protos.tls.client_alpn"] ~= nil) then
      print('<tr><th width=30%><a href="https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation" data-bs-toggle="tooltip" title="ALPN">TLS ALPN</A></th><td colspan=2>'..page_utils.safe_html(flow["protos.tls.client_alpn"])..'</td></tr>\n')
   end

   if(flow["protos.tls.client_tls_supported_versions"] ~= nil) then
      print('<tr><th width=30%><a href="https://tools.ietf.org/html/rfc7301" data-bs-toggle="tooltip">'.. i18n("flow_details.client_tls_supported_versions") ..'</A></th><td colspan=2>'..page_utils.safe_html(flow["protos.tls.client_tls_supported_versions"])..'</td></tr>\n')
   end

   if((flow["tcp.max_thpt.cli2srv"] ~= nil) and (flow["tcp.max_thpt.cli2srv"] > 0)) then
     print("<tr><th width=30%>"..
     '<a class="ntopng-external-link"  data-bs-toggle="tooltip" href="https://en.wikipedia.org/wiki/TCP_tuning">'..
     i18n("flow_details.max_estimated_tcp_throughput").." <i class=\"fas fa-external-link-alt\"></i></a><td nowrap> "..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ")
     print(bitsToSize(flow["tcp.max_thpt.cli2srv"]))
     print("</td><td> "..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ")
     print(bitsToSize(flow["tcp.max_thpt.srv2cli"]))
     print("</td></tr>\n")
   end

   if((flow["cli2srv.trend"] ~= nil) and false) then
     print("<tr><th width=30%>"..i18n("flow_details.throughput_trend").."</th><td nowrap>"..flow["cli.ip"].." <i class=\"fas fa-long-arrow-alt-right\"></i> "..flow["srv.ip"]..": ")
     print(flow["cli2srv.trend"])
     print("</td><td>"..flow["cli.ip"].." <i class=\"fas fa-long-arrow-alt-left\"></i> "..flow["srv.ip"]..": ")
     print(flow["srv2cli.trend"])
     print("</td></tr>\n")
    end

   local flags = flow["cli2srv.tcp_flags"] or flow["srv2cli.tcp_flags"]
   
   local json_flags = nil
   if(flags ~= nil and flags == 0) then
      json_flags = json.decode(flow["moreinfo.json"])
      flags = json_flags["CLIENT_TCP_FLAGS"] or json_flags["SERVER_TCP_FLAGS"]
   end

   if((flags ~= nil) and (flags > 0)) then
      print("<tr><th width=30% rowspan=2>"..i18n("tcp_flags").."</th><td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ")
      if (json_flags ~= nil) then
         printTCPFlags(json_flags["CLIENT_TCP_FLAGS"])
      else
         printTCPFlags(flow["cli2srv.tcp_flags"])
      end
      print("</td><td nowrap>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ")
      if(json_flags ~= nil) then
         printTCPFlags(json_flags["SERVER_TCP_FLAGS"])
      else
         printTCPFlags(flow["srv2cli.tcp_flags"])
      end
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
      local icmp_utils = require "icmp_utils"
      local icmp_label = icmp_utils.get_icmp_label(flow["icmp"]["type"], flow["icmp"]["code"])

      print("<tr><th width=30%>"..i18n("flow_details.icmp_info").."</th><td colspan=2>"..icmp_label)

      if icmp["unreach"] then
         local unreachable_flow = interface.findFlowByTuple(flow["cli.ip"], flow["srv.ip"], flow["vlan"], icmp["unreach"]["dst_port"], icmp["unreach"]["src_port"], icmp["unreach"]["protocol"])

         print("<br>"..i18n("flow")..": ")
         if unreachable_flow then
            print(" <a class='btn btn-sm border ms-1 btn-info' HREF='"..ntop.getHttpPrefix().."/lua/flow_details.lua?flow_key="..unreachable_flow["ntopng.key"].."&flow_hash_id="..unreachable_flow["hash_entry_id"].."'><i class='fas fa-search-plus'></i></a>")
            print(" "..getFlowLabel(unreachable_flow, true, true))
         else
            -- The flow hasn't been found so very likely it is no longer active or it hasn't been seen.
            -- Still print the flow using data found in the original datagram found in the icmp packet
            print(getFlowLabel({
                        ["cli.ip"] = icmp["unreach"]["src_ip"], ["srv.ip"] = icmp["unreach"]["dst_ip"],
                        ["cli.port"] = icmp["unreach"]["src_port"], ["srv.port"] = icmp["unreach"]["dst_port"]},
                     false, false))
         end
         print("")
      end

      print("</td></tr>")
   end

   -- ######################################

   if(isScoreEnabled() and (flow.score.flow_score > 0)) then
      print("\n<tr><th width=30%>"..i18n("flow_details.flow_score").. " / "..i18n("flow_details.flow_score_breakdown").."</th><td>"..format_utils.formatValue(flow.score.flow_score).."</td>\n")

      local score_category_network  = flow.score.host_categories_total["0"]
      local score_category_security = flow.score.host_categories_total["1"]
      local tot                     = score_category_network + score_category_security

      score_category_network  = (score_category_network*100)/tot
      score_category_security = 100 - score_category_network

      print('<td><div class="progress"><div class="progress-bar bg-warning" style="width: '..score_category_network..'%;">'.. i18n("flow_details.score_category_network"))
      print('</div><div class="progress-bar bg-success" style="width: ' .. score_category_security .. '%;">' .. i18n("flow_details.score_category_security") .. '</div></div></td>\n')
      print("</tr>\n")
   end

   -- ######################################

   local alerts_by_score = {} -- Table used to keep messages ordered by score
   local num_statuses = 0
   local first = true

   for id, _ in pairs(flow["alerts_map"] or {}) do
      local is_predominant = id == flow["predominant_alert"]
      local alert_label = alert_consts.alertTypeLabel(id, true, alert_entities.flow.entity_id)
      local message = alert_label
      local alert_score = ntop.getFlowAlertScore(id)
      local alert_risk = ntop.getFlowAlertRisk(id)

      if alert_score > 0 then
         message = message .. string.format(" [%s: %s]",
                                            i18n("score"),
                                            format_utils.formatValue(alert_score))
      end

      if not alerts_by_score[alert_score] then
         alerts_by_score[alert_score] = {}
      end
      alerts_by_score[alert_score][#alerts_by_score[alert_score] + 1] = {message = message, is_predominant = is_predominant, alert_id = id, alert_label = alert_label, alert_risk = alert_risk}
      num_statuses = num_statuses + 1
   end
   -- ######################################

   -- Unhandled flow risk as 'fake' alerts with a 'fake' score of zero
   if flow["unhandled_flow_risk"] and table.len(flow["unhandled_flow_risk"]) > 0 then
      local unhandled_risk_score = 0
      local risk = flow["unhandled_flow_risk"]

      for risk_str,risk_id in pairs(risk) do
         if not alerts_by_score[unhandled_risk_score] then
            alerts_by_score[unhandled_risk_score] = {}
         end

         local message =  string.format("%s [%s: %s]",
                                        risk_str,
                                        i18n("score"),
                                        i18n("score_not_accounted"))

         alerts_by_score[unhandled_risk_score][#alerts_by_score[unhandled_risk_score] + 1] = {message = message, is_predominant = false, alert_risk = risk_id}
         num_statuses = num_statuses + 1
      end
   end

   -- ######################################

   -- Print flow alerts (ordered by score and then alphabetically)
   if num_statuses > 0 then
      -- Prepare a mapping between alert id and check
      local alert_id_to_flow_check = {}
      local checks = require "checks"
      local riskInfo = {}
      
      local flow_checks = checks.load(ifId, checks.script_types.flow, "flow")
      for flow_check_name, flow_check in pairs(flow_checks.modules) do
        if flow_check.alert_id then
          alert_id_to_flow_check[flow_check.alert_id] = flow_check_name
        end
      end

      if not isEmptyString(flow.riskInfo) then
        riskInfo = json.decode(flow.riskInfo, 1, nil)
      end

      if(riskInfo ~= nil) then
	 for _, score_alerts in pairsByKeys(alerts_by_score, rev) do
          for _, score_alert in pairsByField(score_alerts, "message", asc) do
            if first then
              print("<tr><th width=30% rowspan="..(num_statuses+1)..">"..i18n("flow_details.flow_issues").."</th><th>"..i18n("description").."</th><th>"..i18n("actions").."</th></tr>")
              first = false
            end

            local status_icon = ""

            local riskLabel = riskInfo[tostring(score_alert.alert_risk)]

            if(riskLabel ~= nil) then
              riskLabel = "[" .. shortenString(riskLabel,64) .. "]"
            else
              riskLabel = ""
            end
      
            if score_alert.alert_id then 
              alert_consts.alertTypeIcon(score_alert.alert_id, map_score_to_severity(score_alert.alert_id), 'fa-lg')
            end

            print(string.format('<tr>'))
            
            local msg = string.format('<td>%s %s %s %s</td>',
              score_alert.message,
              riskLabel,
              (score_alert.alert_risk > 0 and flow_risk_utils.get_documentation_link(score_alert.alert_risk)) or '',
              status_icon or '')
            print(msg)
      
            if score_alert.alert_id then
              print('<td>')
              
              -- Add rules to disable the check
              print(string.format('<a href="#alerts_filter_dialog" alert_id=%u alert_label="%s" class="btn btn-sm btn-warning" role="button"><i class="fas fa-bell-slash"></i></a>', score_alert.alert_id, score_alert.alert_label))
              
              -- If available, add a cog to configure the check
              if alert_id_to_flow_check[score_alert.alert_id] then
                  print(string.format('&nbsp;<a href="%s" class="btn btn-sm btn-info" role="button"><i class="fas fa-cog"></i></a>', alert_utils.getConfigsetURL(alert_id_to_flow_check[score_alert.alert_id], "flow")))
              end
         
              -- Add an anchor to the historical alert
              if not ifstats.isViewed 
                 -- and score_alert.is_predominant 
              then
                  -- Prepare bounds for the historical alert search.
                  local epoch_begin = flow["seen.first"]
                  -- As this is the page of active flows, it is meaningful to use the current time for the epoch end.
                  -- This will also enable multiple flows with the same tuple to be shown.
                  local epoch_end = os.time()
                  local l7_proto = flow["proto.ndpi_id"] .. tag_utils.SEPARATOR .. "eq"
                  local cli_ip = flow["cli.ip"]  .. tag_utils.SEPARATOR .. "eq"
                  local srv_ip = flow["srv.ip"]  .. tag_utils.SEPARATOR .. "eq"
                  local cli_port = flow["cli.port"]  .. tag_utils.SEPARATOR .. "eq"
                  local srv_port = flow["srv.port"]  .. tag_utils.SEPARATOR .. "eq"
                  
                  print(string.format('&nbsp;<a href="%s/lua/alert_stats.lua?status=historical&page=flow&epoch_begin=%u&epoch_end=%u&l7_proto=%s&cli_ip=%s&cli_port=%s&srv_ip=%s&srv_port=%s" class="btn btn-sm btn-info" role="button"><i class="fas fa-exclamation-triangle"></i></a>',
                    ntop.getHttpPrefix(),
                    epoch_begin,
                    epoch_end,
                    l7_proto,
                    cli_ip, cli_port,
                    srv_ip, srv_port))
              end
         
              print('</td>')
            else -- These are unhandled alerts, e.g., flow risks for which a check doesn't exist
              print(string.format('<td></td>'))
            end
      
            print('</tr>')
                end
        end
      end
    end

   -- ######################################

   if(flow.entropy and flow.entropy.client and flow.entropy.server) then
      print("<tr><th width=30%><A class='ntopng-external-link' href=\"https://en.wikipedia.org/wiki/Entropy_(information_theory)\">"..i18n("flow_details.entropy").." <i class=\"fas fa-external-link-alt\"></i></A></th>")
      print("<td>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-right\"></i> "..i18n("server")..": ".. string.format("%.3f", flow.entropy.client) .. "</td>")
      print("<td>"..i18n("client").." <i class=\"fas fa-long-arrow-alt-left\"></i> "..i18n("server")..": ".. string.format("%.3f", flow.entropy.server) .. "</td>")
      print("</tr>\n")

      if(flow.entropy.icmp ~= nil) then
	 print("<tr><th width=30%>" .. i18n("flow_details.icmp_entropy") .. "</th>")
	 print("<td colspan=2>"..i18n("flow_details.icmp_entropy_min_max")..": ".. string.format("%.3f", flow.entropy.icmp.min) .. " - " .. string.format("%.3f", flow.entropy.icmp.max) .." [")
	 print(i18n("flow_details.icmp_entropy_diff")..": ".. string.format("%.3f", flow.entropy.icmp.max - flow.entropy.icmp.min) .. "]")

	 if(icmp_utils.is_suspicious_entropy(flow.entropy.icmp.min, flow.entropy.icmp.max)) then
	    print(" <span class=\"badge bg-warning\">".. i18n("suspicious_payload") .."</span>")
	 end
	 
	 print("</td></tr>\n")
      end
   end

   if((flow.community_id ~= nil) and (flow.community_id ~= "")) then
      print("<tr><th width=30%><A class='ntopng-external-link' href=\"https://github.com/corelight/community-id-spec\">CommunityId <i class=\"fas fa-external-link-alt\"></i></A></th><td colspan=2>".. flow.community_id)
      print_copy_button('community_id', flow.community_id)
      print("</td></tr>\n")
   end

   if((flow["protos.http.last_url"] ~= nil) and (flow.l7_error_code ~= 0)) then
      print("<tr><th width=30%>"..i18n("l7_error_code").."</th>")
      print("<td colspan=2><span class=\"badge ")

      if((flow["protos.http.last_url"] ~= nil) and (tonumber(flow.l7_error_code) >= 400)) then
         print("bg-danger")
      else
         print("bg-success")
      end
      
      print("\">".. http_utils.getResponseStatusCode(flow.l7_error_code) .. "</td>")
      print("</tr>\n")
   end

   if((flow.client_process == nil) and (flow.server_process == nil)) then
      print("<tr><th width=30%>"..i18n("flow_details.actual_peak_throughput").."</th><td width=20%>")
      if(throughput_type == "bps") then
         print("<span id='flow-throughput' class='peity'>" .. bitsToSize(8*flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      elseif(throughput_type == "pps") then
         print("<span id='flow-throughput' class='peity'>" .. pktsToSize(flow["throughput_bps"]) .. "</span> <span id=throughput_trend></span>")
      end

      if(throughput_type == "bps") then
         print(" / <span id=top-flow-throughput>" .. bitsToSize(8*flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      elseif(throughput_type == "pps") then
         print(" / <span id=top-flow-throughput>" .. pktsToSize(flow["top_throughput_bps"]) .. "</span> <span id=top_throughput_trend></span>")
      end

      print("</td><td><span id=thpt-load-chart>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>")
      print("</td></tr>\n")
   end

   if((flow.client_process ~= nil) or (flow.server_process ~= nil)) then
      local epbf_utils = require "ebpf_utils"
      print('<tr><th colspan=3><div id="sprobe"></div>')

      local width  = 1024
      local height = 200
      local url = ntop.getHttpPrefix().."/lua/get_flow_process_tree.lua?flow_key="..flow_key.."&flow_hash_id="..flow_hash_id
      epbf_utils.draw_flow_processes_graph(width, height, url)

      print('</th></tr>\n')

      if(flow.client_process ~= nil) then
         displayProc(flow.client_process,
                     "<tr><th colspan=3>"..i18n("flow_details.client_process_information").."</th></tr>\n")
      end
      if(flow.client_container ~= nil) then
         displayContainer(flow.client_container,
                          "<tr><th colspan=3>"..i18n("flow_details.client_container_information").."</th></tr>\n")
      end
      if(flow.server_process ~= nil) then
         displayProc(flow.server_process,
                     "<tr><th colspan=3>"..i18n("flow_details.server_process_information").."</th></tr>\n")
      end
      if(flow.server_container ~= nil) then
         displayContainer(flow.server_container,
                          "<tr><th colspan=3>"..i18n("flow_details.server_container_information").."</th></tr>\n")
      end
   end

   if(flow["protos.dns.last_query"] ~= nil) then
      local dns_utils = require "dns_utils"

      print("<tr><th width=30%>"..i18n("flow_details.dns_query").."</th><td colspan=2>")

      local dns_info = format_dns_query_info({ last_query_type = flow["protos.dns.last_query_type"], last_return_code = flow["protos.dns.last_return_code"]})

      if dns_info["last_query_type"] ~= 0 then
        print(dns_info["last_query_type"] .. " ")
      end

      if dns_info["last_return_code"] ~= 0 then
        print(dns_info["last_return_code"] .. " ")
      end

      if(string.ends(flow["protos.dns.last_query"], "arpa")) then
         print(shortHostName(flow["protos.dns.last_query"]))
      else
         print(format_external_link(page_utils.safe_html(flow["protos.dns.last_query"]), page_utils.safe_html(shortHostName(flow["protos.dns.last_query"])), false, "dns"))
      end

      historicalProtoHostHref(ifid, flow["cli.ip"], flow["proto.l4"], flow["proto.ndpi_id"], page_utils.safe_html(flow["protos.dns.last_query"] or ''))


      if(flow["category"] ~= nil) then
         print(" "..getCategoryIcon(flow["protos.dns.last_query"], flow["category"]))
      end

      printAddCustomHostRule(flow["protos.dns.last_query"])

      print("</td></tr>\n")
   end

   if not isEmptyString(flow["protos.ssh.hassh.client_hash"]) or not isEmptyString(flow["protos.ssh.hassh.server_hash"]) then
      print("<tr><th><A HREF='https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c'>HASSH</A></th><td>")
      print("<b>"..i18n("client")..":</b> "..hostinfo2detailshref(flow2hostinfo(flow, "cli"), {page = "ssh"}, flow["protos.ssh.hassh.client_hash"]).."</td>")
      print("<td><b>"..i18n("server")..":</b> "..hostinfo2detailshref(flow2hostinfo(flow, "srv"), {page = "ssh"}, flow["protos.ssh.hassh.server_hash"]).."</a></td>")
      print("</td>")
   end

   if(not isEmptyString(flow["protos.ssh.client_signature"])) then
      print("<tr><th>"..i18n("flow_details.ssh_signature").."</th><td><b>"..i18n("client")..":</b> "..(flow["protos.ssh.client_signature"] or '').."</td><td><b>"..i18n("server")..":</b> "..(flow["protos.ssh.server_signature"] or '').."</td></tr>\n")
   end

   if(not isEmptyString(flow["bittorrent_hash"])) then
      print("<tr><th>"..i18n("flow_details.bittorrent_hash").."</th><td colspan=4><A HREF=\"https://www.google.it/search?q="..flow["bittorrent_hash"].."\">".. flow["bittorrent_hash"].."</A></td></tr>\n")
   end

   if(flow["protos.http.last_url"] ~= nil) then
      local rowspan = 2
      if(not isEmptyString(flow["protos.http.last_method"])) then rowspan = rowspan + 1 end
      if not have_nedge and flow["protos.http.last_return_code"] and flow["protos.http.last_return_code"] ~= 0 then rowspan = rowspan + 1 end
      if(not isEmptyString(flow["protos.http.last_user_agent"])) then rowspan = rowspan + 1 end
      if(not isEmptyString(flow["protos.http.last_server"])) then rowspan = rowspan + 1 end
      if(not isEmptyString(flow["protos.http.last_return_code"])) then rowspan = rowspan + 1 end

      print("<tr><th width=30% rowspan="..rowspan..">"..i18n("http").."</th>")
      if(not isEmptyString(flow["protos.http.last_method"])) then
        print("<th>"..i18n("flow_details.http_method").."</th><td>"..(flow["protos.http.last_method"] or '').."</td>")
        print("</tr>")
        print("<tr>")
      end

      -- Adding server name column
      print("<tr><th>"..i18n("flow_details.server_name").."</th><td colspan=2>")
      local s = flowinfo2hostname(flow,"srv")
      if(not isEmptyString(flow["host_server_name"])) then
         s = flow["host_server_name"]
      end

      print(format_external_link(page_utils.safe_html(s), page_utils.safe_html(s), false, "http"))

      if(flow["category"] ~= nil) then
         print(" "..getCategoryIcon(flow["host_server_name"], flow["category"]))
      end
      -- Adding + with custom host rules next to the server name
      printAddCustomHostRule(s)
      print("</td></tr>\n")

      if(not isEmptyString(flow["protos.http.last_user_agent"])) then
        print("<tr><th>"..i18n("flow_details.user_agent").."</th><td colspan=2>"..flow["protos.http.last_user_agent"].."</td></tr>")
      end

      if(not isEmptyString(flow["protos.http.last_server"])) then
        print("<tr><th>"..i18n("flow_details.server").."</th><td colspan=2>"..flow["protos.http.last_server"].."</td></tr>")
      end

      print("<tr><th>"..i18n("flow_details.url").."</th><td colspan=2>")
      -- if(flow["srv.port"] ~= 80) then print(":"..flow["srv.port"]) end

      local last_url = page_utils.safe_html(flow["protos.http.last_url"])
      local last_url_short = shortenString(last_url, 64)
      local proto = "https"
      
      if(starts(last_url, "http:") == false) then
        -- Now we need to check if nttp or https is needed
        if(not string.contains(last_url, ":443")) then
          proto = "http"
        end
      end

      print(format_external_link(last_url, last_url_short, false, proto))
      print("</td></tr>\n")

      if not have_nedge and flow["protos.http.last_return_code"] and flow["protos.http.last_return_code"] ~= 0 then
        if(flow["protos.http.last_return_code"] < 400) then
            color = "badge bg-success"
        else
            color = "badge bg-warning"
        end
        print("<tr><th>"..i18n("flow_details.response_code").."</th><td colspan=2><span class='"..color.."'>"..(http_utils.getResponseStatusCode(flow["protos.http.last_return_code"]) or '').."</span></td></tr>\n")
      end
   else
      if((flow["host_server_name"] ~= nil) and (flow["protos.dns.last_query"] == nil)) then
         print("<tr><th width=30%>"..i18n("flow_details.server_name").."</th><td colspan=2>")
         local proto = "http"
         if(starts(flow["proto.ndpi"], "TLS")) then
            proto = "https"
         end
         print(format_external_link(page_utils.safe_html(flow["host_server_name"]), page_utils.safe_html(flow["host_server_name"]), false, proto))
         if not isEmptyString(flow["protos.http.server_name"]) then
            printAddCustomHostRule(flow["protos.http.server_name"])
         end
         print("</td></tr>\n")
      end
   end

   if(flow["profile"] ~= nil) then
      print("<tr><th width=30%><A HREF=\"".. ntop.getHttpPrefix() .."/lua/pro/admin/edit_profiles.lua\">"..i18n("flow_details.profile_name").."</A></th><td colspan=2><span class='badge bg-primary'>"..flow["profile"].."</span></td></tr>\n")
   end

   if(flow.src_as and flow.src_as ~= 0) or (flow.dst_as and flow.dst_as ~= 0) then
      local asn

      print("<tr>")
      print("<th width=30%>"..i18n("flow_details.as_src_dst").."</th>")

      formatASN(flow.src_as)
      formatASN(flow.dst_as)

      print("</tr>\n")
   end

   if(flow.prev_adjacent_as or flow.next_adjacent_as) then
      print("<tr>")
      print("<th width=30%>"..i18n("flow_details.as_prev_next").."</th>")

      formatASN(flow.prev_adjacent_as)
      formatASN(flow.next_adjacent_as)

      print("</tr>\n")
   end

   if(not interface.isPacketInterface()) and (flow["flow_verdict"]) and (tonumber(flow["flow_verdict"]) ~= 0) then
      local flow_verdict_badge = addFlowVerdictBadge(flow["flow_verdict"], true)
      print("<tr><th width=30%>" .. i18n("details.flow_verdict") .. "</th><td colspan=2>" .. flow_verdict_badge .. "</td></tr>\n")
   end

   if(flow["moreinfo.json"] ~= nil) then
      local flow_field_value_maps = require "flow_field_value_maps"
      local info, pos, err = json.decode(flow["moreinfo.json"], 1, nil)
      local isThereSIP = 0
      local isThereRTP = 0

      -- Convert the array to symbolic identifiers if necessary
      local syminfo = {}
      for key, value in pairs(info) do
         key, value = flow_field_value_maps.map_field_value(ifid, key, value)

         local k = rtemplate[tonumber(key)]

         if(k == nil) then
            k = flow_consts.flow_fields_description[tostring(key)]
         end

         if(k ~= nil) then
            syminfo[k] = value
         else
            local nprobe_description = interface.getZMQFlowFieldDescr(key)

            if not isEmptyString(nprobe_description) and nprobe_description ~= key then
               syminfo[nprobe_description] = value
            else
               syminfo[key] = value
            end
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

      if(ntop.isPro() and not isEmptyString(flow["device_ip"])) then
        snmpdevice = flow["device_ip"]
      end

      if((flow["observation_point_id"] ~= nil) and (flow["observation_point_id"] ~= 0)) then
         local custom_name = getObsPointAlias(flow["observation_point_id"], true, true)

         print("<tr><th>"..i18n("details.observation_point_id").."</th>")
         print("<td colspan=\"2\">"..custom_name.."</td></tr>")
      end

      if(snmpdevice ~= nil) then
         local exporter_info_url = ntop.getHttpPrefix().."/lua/pro/enterprise/flowdevice_details.lua?ip="..snmpdevice
         print("<tr><th>"..i18n("details.flow_exporter").."</th>")
         print("<td colspan=\"2\">".."<a href="..exporter_info_url..">"..snmpdevice.."</a></td></tr>")

         if(flow["in_index"] or flow["out_index"]) then
            if((flow["in_index"] == flow["out_index"]) and (flow["in_index"] == 0)) then
               -- nothing to do (they are likely to be not initialized)
            else
               printFlowSNMPInfo(snmpdevice, flow["in_index"], flow["out_index"])
            end
         end
      end

      local function format_custom_field(key, value, snmpdevice) 
        local formatted_value = handleCustomFlowField(key, value, snmpdevice)
        
        if((tonumber(formatted_value)) and (math.floor(tonumber(formatted_value)) == 0)) then
          formatted_value = ''
        end

        return formatted_value
      end
      
      local num = 0      
      for key,value in pairsByKeys(info) do
        if tonumber(key) then
          key = getFlowLabelFromId(key)
        end

        if fieldAlreadyPresent(key, flow) then
          goto continue
        end

        if(num == 0) then
          print("<tr><th colspan=3>"..i18n("flow_details.additional_flow_elements").."</th></tr>\n")
        end

        if(value ~= "" and key ~= "CLIENT_TCP_FLAGS" and key ~= "SERVER_TCP_FLAGS") then
          if type(value) == "table" then
            print("<tr><th width=30%>" .. getFlowKey(key) .. "</th>")
            for _, value in pairs(value or {}) do
              print("<td colspan=1>" .. format_custom_field(key, value, snmpdevice) .. "</td>")
            end
            print("</tr>\n")
          else
            print("<tr><th width=30%>" .. getFlowKey(key) .. "</th><td colspan=2>" .. format_custom_field(key, value, snmpdevice) .. "</td></tr>\n")
          end

        end
        
        num = num + 1

        ::continue::
      end
   end

   if(flow.flow_payload ~= nil) then
      local idx

      -- Check for HTTP (remove data past response)
      payload = string.reverse(flow.flow_payload)
      
      idx = string.find(payload, "\n\r\n\r")

      if(idx == nil) then
         payload = flow.flow_payload
      else
         payload = string.reverse(string.sub(payload, idx))
      end         

      print("<tr><th width=30%>Payload</th><td colspan=2 style='max-width: 200px; white-space: pre-wrap; word-break: keep-all; font-family: \"courier new\", courier, monospace;font-size: 13px;'>" .. payload .. "</td></tr>\n")
   end


print("</table>\n")
end

local traffic_peity_width = "64"
print [[
<div id="vue-modals">
  <modal-alerts-filter
    :alert="current_alert"
    :page="page"
    @exclude="add_exclude"
    ref="modal_alerts_filter">
  </modal-alerts-filter>
</div>
]]

local cliLabel = ''
local cliValue = ''
local srvLabel = ''
local srvValue = ''
local vlan = 0
local infoDomain = ''
local infoIssuerDN = ''

if flow ~= nil then
  cliLabel = flowinfo2hostname(flow, "cli"); 

  if cliLabel ~= flow["cli.ip"] then
    cliValue = flow["cli.ip"]
  else
    cliValue = cliLabel
  end

  srvLabel = flowinfo2hostname(flow,"srv"); 

  if srvLabel ~= flow["srv.ip"] then
    srvValue = flow["srv.ip"]
  else
    srvValue = srvLabel
  end

  if flow["vlan"] and flow["vlan"] > 0 then
    vlan = flow["vlan"]
  end

  if not isEmptyString(flow["suspicious_dga_domain"]) then
    infoDomain = flow["suspicious_dga_domain"]
  elseif not isEmptyString(flow["protos.tls.client_requested_server_name"]) then
    infoDomain = flow["protos.tls.client_requested_server_name"]
  elseif not isEmptyString(flow["host_server_name"]) and hostnameIsDomain(flow["host_server_name"]) then
    infoDomain = flow["host_server_name"]
  end

  if flow["protos.tls.issuerDN"] ~= nil then
    infoIssuerDN = flow["protos.tls.issuerDN"]
  end
end

print [[
<script>
  let VUE_MODALS;
  const pageCsrf = "]] print(ntop.getRandomCSRFValue()) print[[";

  const cliLabel = "]] print(cliLabel) print[[";
  const cliValue = "]] print(cliValue) print[["; 
  const srvLabel = "]] print(srvLabel) print[[";
  const srvValue = "]] print(srvValue) print[[";
  const vlan = ]] print(vlan) print[[;
  const infoDomain = "]] print(infoDomain) print[[";
  const infoIssuerDN = "]] print(infoIssuerDN) print[[";
]]

print [[
  const thptChart = $("#thpt-load-chart").show().peity("line", { width: ]] print(traffic_peity_width) print[[, max: null })

        $(`a[href='#alerts_filter_dialog']`).click( function (e) {
            const alert_id = e.target.closest('a').attributes.alert_id.value;
            const alert_label = e.target.closest('a').attributes.alert_label.value;
            const alert = {
              alert_id: { value: alert_id },
              alert_name: alert_label,
              flow: {
                cli_ip: {
                  value: cliValue,
                  label: cliLabel,
                },
                srv_ip: {
                  value: srvValue,
                  label: srvLabel,
                },
                vlan: { value: vlan },
              },
              info: {
                value: infoDomain,
                issuerdn: infoIssuerDN,
              },
            };
            VUE_MODALS.show_modal_alerts_filter(alert);
        });

  function start_modals_vue() {
    let page = 'flow';

    let vue_options = {
            components: {
              'modal-alerts-filter': ntopVue.ModalAlertsFilter,
          },
          /**
           * First method called when the component is created.
           */
          created() {},
          mounted() {},
          data() {
              return {
                  page: page,
                  current_alert: null,
                  i18n: (t) => { return i18n(t); },
              };
          },
          methods: {
            show_modal_alerts_filter: function(alert) {
              this.current_alert = alert;
              this.$refs["modal_alerts_filter"].show();
            },
            add_exclude: async function(params) {
              params.csrf = pageCsrf;
//{"delete_alerts":true,"type":"host","alert_addr": null,"flow_alert_key":"46","csrf":"bd493658564ff3ddcf7d08e9552358df"}
              let url = `${http_prefix}/lua/pro/rest/v2/add/alert/exclusion.lua`;
              try {
                let headers = {
                  'Content-Type': 'application/json'
                };
                await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
                $('a[alert_id=' +  params.flow_alert_key+']').hide();
              } catch(err) {
                console.error(err);
              }
            }
          },
      }; 
      const vue = ntopVue.Vue.createApp(vue_options);
      const vue_app = vue.mount("#vue-modals");
      return vue_app;
  }
  VUE_MODALS = start_modals_vue();
]]

if(flow ~= nil) then
   if(flow["cli2srv.packets"] ~= nil ) then
      print("var cli2srv_packets = " .. flow["cli2srv.packets"] .. ";")
   end
   if(flow["srv2cli.packets"] ~= nil) then
      print("var srv2cli_packets = " .. flow["srv2cli.packets"] .. ";")
   end
   if(flow["throughput_"..throughput_type] ~= nil) then
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
                    data: { ifid: "]] print(tostring(ifid)) print [[", ]]
   if(flow_key ~= nil) then
      print [[flow_key: "]] print(string.format("%u", flow_key)) print [[", ]]
   end
print [[flow_hash_id: "]] print(string.format("%u", flow_hash_id)) print [[", ]]
print[[ },
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
                        $('#volume').html(NtopUtils.bytesToVolume(rsp.bytes));
                        $('#goodput_volume').html(NtopUtils.bytesToVolume(rsp["goodput_bytes"]));
                        pctg = ((rsp["goodput_bytes"]*100)/rsp["bytes"]).toFixed(1);

                        /* 50 is the same threshold specified in FLOW_GOODPUT_THRESHOLD */
                        if(pctg < 50) { pctg = "<font color=red>"+pctg+"</font>"; } else if(pctg < 60) { pctg = "<font color=orange>"+pctg+"</font>"; }

                        $('#goodput_percentage').html(pctg);
                        $('#cli2srv').html(NtopUtils.addCommas(rsp["cli2srv.packets"])+" Pkts / " + NtopUtils.addCommas(NtopUtils.bytesToVolume(rsp["cli2srv.bytes"])));
                        $('#srv2cli').html(NtopUtils.addCommas(rsp["srv2cli.packets"])+" Pkts / " + NtopUtils.addCommas(NtopUtils.bytesToVolume(rsp["srv2cli.bytes"])));
                        $('#flow-throughput').html(rsp.throughput);

                        if(typeof rsp["c2sOOO"] !== "undefined") {
                           $('#c2sOOO').html(NtopUtils.formatPackets(rsp["c2sOOO"]));
                           $('#s2cOOO').html(NtopUtils.formatPackets(rsp["s2cOOO"]));
                           $('#c2slost').html(NtopUtils.formatPackets(rsp["c2slost"]));
                           $('#s2clost').html(NtopUtils.formatPackets(rsp["s2clost"]));
                           $('#c2skeep_alive').html(NtopUtils.formatPackets(rsp["c2skeep_alive"]));
                           $('#s2ckeep_alive').html(NtopUtils.formatPackets(rsp["s2ckeep_alive"]));
                           $('#c2sretr').html(NtopUtils.formatPackets(rsp["c2sretr"]));
                           $('#s2cretr').html(NtopUtils.formatPackets(rsp["s2cretr"]));
                        }
                        if(rsp["cli2srv_quota"]) $('#cli2srv_quota').html(rsp["cli2srv_quota"]);
                        if(rsp["srv2cli_quota"]) $('#srv2cli_quota').html(rsp["srv2cli_quota"]);

                        /* **************************************** */

                        if(cli2srv_packets == rsp["cli2srv.packets"]) {
                           $('#sent_trend').html("<i class=\"fas fa-minus\"></i>");
                        } else {
                           $('#sent_trend').html("<i class=\"fas fa-arrow-up\"></i>");
                        }

                        if(srv2cli_packets == rsp["srv2cli.packets"]) {
                           $('#rcvd_trend').html("<i class=\"fas fa-minus\"></i>");
                        } else {
                           $('#rcvd_trend').html("<i class=\"fas fa-arrow-up\"></i>");
                        }

                        if(bytes == rsp["bytes"]) {
                           $('#volume_trend').html("<i class=\"fas fa-minus\"></i>");
                        } else {
                           $('#volume_trend').html("<i class=\"fas fa-arrow-up\"></i>");
                        }

                        if(goodput_bytes == rsp["goodput_bytes"]) {
                           $('#goodput_volume_trend').html("<i class=\"fas fa-minus\"></i>");
                        } else {
                           $('#goodput_volume_trend').html("<i class=\"fas fa-arrow-up\"></i>");
                        }

                        if(throughput > rsp["throughput_raw"]) {
                           $('#throughput_trend').html("<i class=\"fas fa-arrow-down\"></i>");
                        } else if(throughput < rsp["throughput_raw"]) {
                           $('#throughput_trend').html("<i class=\"fas fa-arrow-up\"></i>");
                           $('#top-flow-throughput').html(rsp["top_throughput_display"]);
                        } else {
                           $('#throughput_trend').html("<i class=\"fas fa-minus\"></i>");
                        } ]]

if(isThereSIP == 1) then
   updatePrintSip()
end
if(isThereRTP == 1) then
   updatePrintRtp()
end
print [[                        cli2srv_packets = rsp["cli2srv.packets"];
                        srv2cli_packets = rsp["srv2cli.packets"];
                        throughput = rsp["throughput_raw"];
                        bytes = rsp["bytes"];

         /* **************************************** */
         // Processes information update, based on the pid

         for (var pid in rsp["processes"]) {
            var proc = rsp["processes"][pid]
            // console.log(pid);
            // console.log(proc);
            if(proc["memory"])           $('#memory_'+pid).html(proc["memory"]);
            if(proc["average_cpu_load"]) $('#average_cpu_load_'+pid).html(proc["average_cpu_load"]);
            if(proc["percentage_iowait_time"]) $('#percentage_iowait_time_'+pid).html(proc["percentage_iowait_time"]);
            if(proc["page_faults"])      $('#page_faults_'+pid).html(proc["page_faults"]);
         }

                        /* **************************************** */

                        let values = thptChart.text().split(",");
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
