--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
require("flow_utils")
local json = require "dkjson"
local dscp_consts = require "dscp_consts"
local flow_risk_utils = require "flow_risk_utils"
local alert_utils = require "alert_utils"

local historical_flow_details_formatter = {}

-- ###############################################

local function empty_port(port)
   return port == '0'
end

-- ###############################################

local function empty_ip(ip)
   return ip == '0.0.0.0'
end

-- ###############################################

-- This function format info regarding pre/post nat ips and ports
local function format_post_nat_info(flow, info)
   local tmp = {}
   local nat_values = {}

   -- Checking empty values
   -- Checking IPs
   if (not isEmptyString(info["POST_NAT_IPV4_SRC_ADDR"]) and not empty_ip(info["POST_NAT_IPV4_SRC_ADDR"])) then
      nat_values.post_nat_src_ip = info["POST_NAT_IPV4_SRC_ADDR"]
   end
   if (not isEmptyString(info["POST_NAT_IPV4_DST_ADDR"]) and not empty_ip(info["POST_NAT_IPV4_DST_ADDR"])) then
      nat_values.post_nat_dst_ip = info["POST_NAT_IPV4_DST_ADDR"]
   end
   if (not isEmptyString(info["POST_NAT_SRC_PORT"]) and not empty_port(info["POST_NAT_SRC_PORT"])) then
      nat_values.post_nat_src_port = info["POST_NAT_SRC_PORT"]
   end
   if (not isEmptyString(info["POST_NAT_DST_PORT"]) and not empty_port(info["POST_NAT_DST_PORT"])) then
      nat_values.post_nat_dst_port = info["POST_NAT_DST_PORT"]
   end

   -- No Post-NAT values
   if not nat_values.post_nat_dst_port and not nat_values.post_nat_src_port and not nat_values.post_nat_dst_ip and
      not nat_values.post_nat_src_ip then
      return flow
   end

   -- Format all info
   local post_nat_flow = nat_values.post_nat_src_ip .. " : " .. nat_values.post_nat_src_port ..
                            ' <i class="fas fa-exchange-alt fa-lg"></i> ' .. nat_values.post_nat_dst_ip .. " : " ..
                            nat_values.post_nat_dst_port
   flow[#flow + 1] = {
      name = i18n('db_explorer.post_nat_info'),
      values = {post_nat_flow}
   }

   return flow
end

-- ###############################################

local function format_historical_flow_label(flow)
   local historical_flow_utils = require "historical_flow_utils"

   return {
      name = i18n("flow_details.flow_peers_client_server"),
      values = {historical_flow_utils.getHistoricalFlowLabel(flow, true)}
   }
end

-- ###############################################

local function format_historical_protocol_label(flow)
   local historical_flow_utils = require "historical_flow_utils"

   return {
      name = i18n("protocol") .. " / " .. i18n("application"),
      values = {historical_flow_utils.getHistoricalProtocolLabel(flow, true)}
   }
end

-- ###############################################

local function format_historical_verdict(flow, protocol_info_json, flow_details)
   if ntop.isnEdge() and protocol_info_json and protocol_info_json.verdict then
      require "flow_utils"
      local flow_consts = require "flow_consts"
      local shaper_utils = require("shaper_utils")
      local verdict = protocol_info_json.verdict

      if tonumber(verdict.pass) == 1 then -- Pass
         flow_details[#flow_details + 1] = {
            name = i18n("details.flow_verdict"),
            values = {i18n("policy.pass") .. " " .. shaper_utils.nedge_shapers[1].icon}
         }
      else -- Drop
         local drop_reason_label = ""
         if flow_consts.drop_reason[verdict.drop_reason] then
            drop_reason_label = " (" .. i18n(flow_consts.drop_reason[verdict.drop_reason].i18n_label) .. ")"
         end
         flow_details[#flow_details + 1] = {
            name = i18n("details.flow_verdict"),
            values = {i18n("policy.drop") .. " " .. shaper_utils.nedge_shapers[2].icon .. drop_reason_label}
         }
         -- Add strike to protocol
         flow_details[2].values[1] = '<strike>' .. flow_details[2].values[1] .. '</strike>'
      end
   end

   return flow_details
end

-- ###############################################

local function format_historical_last_first_seen(flow, info)
   return {
      name = i18n("db_explorer.date_time"),
      values = {
         [1] = info.first_seen.time,
         [2] = info.last_seen.time
      }
   }
end

-- ###############################################

function historical_flow_details_formatter.format_historical_total_traffic(flow)
   return {
      name = i18n("db_explorer.traffic_info"),
      values = {formatPackets(flow['PACKETS'] or flow["packets"]) .. ' / ' .. bytesToSize(flow['TOTAL_BYTES'] or flow["total_bytes"])}
   }
end

-- ###############################################

function historical_flow_details_formatter.format_qoe(flow)
   local json_info = flow["PROTOCOL_INFO_JSON"]
   if not isEmptyString(json_info) then
      json_info = json.decode(flow["PROTOCOL_INFO_JSON"])
   end

   if json_info and json_info.qoe and ntop.isEnterpriseL() and tonumber(flow.QOE_SCORE) <= 100 then
      qoe_utils = require "qoe_utils"

      return {
         name = i18n("flow_details.qoe_long"),
         values = {qoe_utils.formatQoE(json_info.qoe.c2s.score), qoe_utils.formatQoE(json_info.qoe.s2c.qoe_score)}
      }
   end
end

-- ###############################################

function historical_flow_details_formatter.format_historical_client_server_bytes(flow)
   return {
      name = "",
      values = {
         [1] = i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("server") .. ": " ..
            formatValue(flow['SRC2DST_PACKETS'] or flow["cli2srv_pkts"]) .. " " .. i18n("pkts") .. " / " ..
            bytesToSize(flow['SRC2DST_BYTES'] or flow["cli2srv_bytes"]),
         [2] = i18n("server") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("client") .. ": " ..
            formatValue(flow['DST2SRC_PACKETS'] or flow["srv2cli_pkts"]) .. " " .. i18n("pkts") .. " / " ..
            bytesToSize(flow['DST2SRC_BYTES'] or flow["srv2cli_bytes"])
      }
   }
end

-- ###############################################

function historical_flow_details_formatter.format_historical_bytes_progress_bar(flow, info)
   local cli2srv = round(((flow["SRC2DST_BYTES"] or flow["cli2srv_bytes"] or 0) * 100) / (flow["TOTAL_BYTES"] or flow["total_bytes"]), 0)

   return {
      name = "",
      values = {'<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. cli2srv .. '%;">' ..
         (info.cli_ip.label or '') .. '</div>' .. '<div class="progress-bar bg-success" style="width: ' .. (100 - cli2srv) .. '%;">' ..
         (info.srv_ip.label or '') .. '</div></div>'}
   }
end

-- formats asn peer or non peer. i18n_label is the string to identify the i18n
function historical_flow_details_formatter.format_asn(flow)
   local max_len = max_len

   local src_ip = flow["IPV4_SRC_ADDR"] or flow["IPV6_SRC_ADDR"]
   local dst_ip = flow["IPV4_DST_ADDR"] or flow["IPV6_DST_ADDR"]

   local src_asn = flow["SRC_ASN"]
   local dst_asn = flow["DST_ASN"]

   local src_as = ""
   if src_asn and src_asn ~= "0" then
      local src_as_name = shortenString(ntop.getASName(src_ip), max_len)
      local src_label = src_asn .. " (" .. (src_as_name or "") .. ")"
      src_as = "<A HREF=\"" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. src_asn .. "\">" .. src_label .. "</A>"
   end

   local dst_as = ""
   if dst_asn and dst_asn ~= "0" then
      local dst_as_name = shortenString(ntop.getASName(dst_ip), max_len)
      local dst_label = dst_asn .. " (" .. (dst_as_name or "") .. ")"
      dst_as = "<A HREF=\"" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. dst_asn .. "\">" .. dst_label .. "</A>"
   end

   return {
      name = i18n("flow_details.as_src_dst"),
      values = {
         [1] = src_as,
         [2] = dst_as
      }
   }
end

function historical_flow_details_formatter.format_asn_peer(flow, src_peer_asn, dst_peer_asn)
   local format_utils = require "format_utils"

   -- source asn
   local src_asn = flow.SRC_ASN or 0
   local src_ip = flow and flow.IPV4_SRC_ADDR or flow.IPV6_SRC_ADDR or 0

   -- destination asn
   local dst_asn = flow.DST_ASN or 0
   local dst_ip = flow and flow.IPV4_DST_ADDR or flow.IPV6_DST_ADDR or 0

   -- source asn formatting
   src_asn = format_utils.formatASN_transit(src_asn, src_peer_asn, src_ip, true)

   -- destination asn formatting
   dst_asn = format_utils.formatASN_transit(dst_asn, dst_peer_asn, dst_ip, false)

   return {
      name = i18n("flow_details.as_src_dst"),
      values = {
         [1] = src_asn,
         [2] = dst_asn
      }
   }
end

-- ###############################################

local function format_historical_wlan_ssid(flow, info)
   return {
      name = i18n("flow_fields_description.wlan_ssid"),
      values = {info.wlan_ssid.label}
   }
end

-- ###############################################

local function format_historical_wtp_mac_address(flow, info)
   return {
      name = i18n("flow_fields_description.wtp_mac_address"),
      values = {info.apn_mac.label}
   }
end

-- ###############################################

local function format_historical_tos(flow)
   return {
      name = i18n("db_explorer.tos"),
      values = {
         [1] = dscp_consts.dscp_descr(flow['SRC2DST_DSCP']),
         [2] = dscp_consts.dscp_descr(flow['DST2SRC_DSCP'])
      }
   }
end

-- ###############################################

local function format_historical_tcp_fingerprint(flow)
   return {
      name = i18n("details.tcp_fingerprint"),
      values = {{flow["TCP_FINGERPRINT"]}}
   }
end

-- ###############################################

local function format_historical_tcp_flags(flow, info)
   local client_to_server_flags = ""
   local server_to_client_flags = ""
   local proto_info = info.protocol_info_json
   if proto_info and proto_info.tcp_flags_analysis and proto_info.tcp_flags_analysis.cli2srv then
      client_to_server_flags = formatTCPStats(info.protocol_info_json.tcp_flags_analysis.cli2srv)
   end
   if proto_info and proto_info.tcp_flags_analysis and proto_info.tcp_flags_analysis.srv2cli then
      server_to_client_flags = formatTCPStats(info.protocol_info_json.tcp_flags_analysis.srv2cli)
   end
   return {
      name = i18n("tcp_flags"),
      values = {
         [1] = i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("server") .. ": " .. info.src2dst_tcp_flags.label ..
            client_to_server_flags,
         [2] = i18n("server") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("client") .. ": " .. info.dst2src_tcp_flags.label ..
            server_to_client_flags
      }
   }
end

-- ###############################################

local function format_historical_host_pool(flow, info)
   return {
      name = i18n("details.host_pool"),
      values = {
         [1] = i18n("client") .. " " .. i18n("pools.pool") .. ": " .. info.cli_host_pool_id.label,
         [2] = i18n("server") .. " " .. i18n("pools.pool") .. ": " .. info.srv_host_pool_id.label
      }
   }
end

-- a###############################################

local function format_historical_issue_description(alert, alert_id, score, title, msg, info, alert_scores, add_remediation, riskInfo,
   alert_info)
   local alert_consts = require "alert_consts"
   local alert_entities = require "alert_entities"

   if not alert_id or alert_id == "0" then
      return nil
   end

   if alert_scores and alert_scores[alert_id] then
      score = alert_scores[alert_id] or 0
   end
   -- If alert risk is 0 then it comes from ntonpg, else nDPI
   local alert_risk = ntop.getFlowAlertRisk(tonumber(alert_id))
   local check_risk = true
   local alert_src
   local riskLabel = ""

   if (tonumber(alert_risk) == 0) then
      alert_src = "ntopng"
      alert_risk = alert_id
      if isEmptyString(msg) and not isEmptyString(info) then
         msg = info
      end
      -- Adapting to the new alerts format
      if alert_info and alert then
         check_risk = false
         alert.alert_id = alert_id
         info = alert_utils.formatFlowAlertMessage(interface.getId(), alert, alert_info, false, true, true)
      end
   else
      alert_src = "nDPI"
   end

   if riskInfo and check_risk then
      if type(riskInfo) == "string" then -- backward compatibility
         riskInfo = json.decode(riskInfo)
      end

      if riskInfo and riskInfo[tostring(alert_risk)] then
         riskLabel = riskInfo[tostring(alert_risk)]
      end
   end

   local alert_source = " <span class='badge bg-info'>" .. alert_src .. "</span>"

   local severity_id = map_score_to_severity(score)
   local severity = alert_consts.alertSeverityById(severity_id)
   local remediation = flow_risk_utils.get_remediation_documentation_link(tostring(alert_risk), alert_src)

   local html = "<tr><td>" .. (msg or "") .. alert_source .. "</td>" .. '<td align=center><span style="color:' .. severity.color .. '">' ..
                   score .. '</span></td>'

   if not isEmptyString(riskLabel) then
      info = riskLabel
   end
   if (add_remediation) then
      html = html .. "<td>" .. info .. " " .. remediation .. "</td>"
   else
      html = html .. "<td>" .. info .. "</td>"
   end

   -- Add Mitre info
   local alert_key = alert_consts.getAlertType(alert_id, alert_entities.flow.entity_id)

   if alert_key then
      local mitre_info = alert_consts.getAlertMitreInfo(alert_key)

      if mitre_info and mitre_info.mitre_id then
         local keys = split(mitre_info.mitre_id, "%.")
         local url = "https://attack.mitre.org/techniques/" .. keys[1]:gsub("%%", "") .. "/"

         if keys[2] ~= nil then
            url = url .. keys[2]:gsub("%%", "") .. "/"
         end

         html = html .. '<td><a href="' .. url .. '">' .. mitre_info.mitre_id .. "</A>"

         if (mitre_info.mitre_tactic) and (mitre_info.mitre_tactic.i18n_label) then
            html = html .. '<br>' .. i18n(mitre_info.mitre_tactic.i18n_label) .. "</td>"
         end
      else
         html = html .. "<td>&nbsp;</td>"
      end
   else
      html = html .. "<td>&nbsp;</td>"
   end

   return html
end

-- ###############################################

function historical_flow_details_formatter.format_historical_issues(flow_details, flow, is_alert)
   local historical_flow_utils = require "historical_flow_utils"
   local alert_store_utils = require "alert_store_utils"
   local alert_entities = require "alert_entities"
   local format_utils = require "format_utils"
   local alert_consts = require "alert_consts"
   local alert_utils = require "alert_utils"
   local alert_store_instances = alert_store_utils.all_instances_factory()
   local alert_json = json.decode(flow["ALERT_JSON"] or flow["json"] or '') or {}
   local details = ""
   local alert
   local riskInfo = {}
   local alerts_map = flow['ALERTS_MAP'] or flow["alerts_map_l"] or ""
   local score = tonumber(flow["SCORE"]) or tonumber(flow["score"]) or 0
   local alert_scores = {}
   local alert_id = tonumber(flow["STATUS"] or flow["alert_id"] or 0)
   local html = "<table class=\"table table-bordered table-striped\" width=100%>\n" .. "<tr><th>" .. i18n("description") .. "</th><th>" ..
                   i18n("score") .. "</th><th>" .. i18n("info") .. " / " .. i18n("remediation") .. "</th><th>" .. i18n("mitre_id") ..
                   "</th></tr>\n"
   local alert_store_instance = alert_store_instances[alert_entities["flow"].alert_store_name]
   local main_alert_score

   if not is_alert then
      alert = historical_flow_utils.convertFlowToAlert(flow)
   else
      alert = flow
   end
   if score > 0 then
      details = alert_utils.formatFlowAlertMessage(interface.getId(), alert, nil, false, true, true)
   end

   if alert_json and alert_json.flow_risk_info then
      riskInfo = alert_json.flow_risk_info
   elseif alert_json and alert_json.alert_generation and alert_json.alert_generation.flow_risk_info then
      -- Keep the code divided due to optimizations
      riskInfo = alert_json.alert_generation.flow_risk_info
   end

   if alert_json and alert_json.alerts then
      for alert_id, values in pairs(alert_json.alerts or {}) do
         alert_scores[alert_id] = values.score
      end
   else
      local alert_label = i18n("flow_details.normal")
      alert_scores = alert_json.alert_score
      main_alert_score = ntop.getFlowAlertScore(tonumber(alert_id))

      -- No status set
      if (alert_id ~= 0) then
         alert_label = alert_consts.alertTypeLabel(alert_id, true)
         html = html ..
                   format_historical_issue_description(alert, tostring(alert_id), tonumber(main_alert_score), i18n("issues_score"),
               alert_label, details, alert_scores, true, riskInfo)
      end
   end

   -- Check if there is a custom score
   if alert_scores and alert_scores[tostring(alert_id)] then
      main_alert_score = alert_scores[tostring(alert_id)]
   end

   local severity_id = map_score_to_severity(main_alert_score)
   local severity = alert_consts.alertSeverityById(severity_id)
   local _, other_issues = alert_utils.format_other_alerts(alerts_map, alert_id, alert_json, false, nil, true)

   flow_details[#flow_details + 1] = {
      name = i18n('total_flow_score'),
      values = {'<span style="color:' .. severity.color .. '">' .. format_utils.formatValue(score) .. '</span>', ''}
   }

   if table.len(other_issues) > 0 then
      for _, issue in pairsByField(other_issues or {}, "score", rev) do
         local msg, info
         local pieces = string.split(issue.msg, "%[")

         if (pieces ~= nil) then
            msg = pieces[1]
            info = string.gsub(pieces[2], "%]", "")
         else
            msg = issue.msg
            info = ""
         end
         local alert_info = nil
         if alert_json and alert_json.alerts then
            alert_info = alert_json.alerts[tostring(issue.alert_id)]
         end
         html = html ..
                   format_historical_issue_description(alert, tostring(issue.alert_id), tonumber(issue.score), '', msg, info, alert_scores,
               true, riskInfo, alert_info)
      end
   end

   flow_details[#flow_details + 1] = {
      name = i18n('detected_issues'),
      values = {html}
   }

   return flow_details
end

-- ###############################################

local function format_tcp_connection_states(info)
   local conn_states = {}
   conn_states[#conn_states + 1] = string.format("%s: %s (%s)", i18n("flow_fields_description.major_connection_state"), i18n(
      string.format("flow_fields_description.major_connection_states.%s", info.major_connection_state.value)), i18n(
      string.format("flow_fields_description.minor_connection_states_info.%u", info.minor_connection_state.value)))
   conn_states[#conn_states + 1] = string.format("%s: %s (%s)", i18n("flow_fields_description.minor_connection_state"), i18n(
      string.format("flow_fields_description.minor_connection_states.%s", info.minor_connection_state.value)), i18n(
      string.format("flow_fields_description.minor_connection_states_info.%u", info.minor_connection_state.value)))
   return conn_states
end

-- ###############################################

local function format_historical_community_id(flow)
   return {
      name = "<A class='ntopng-external-link' href=\"https://github.com/corelight/community-id-spec\">" .. i18n("db_explorer.community_id") ..
         " <i class=\"fas fa-external-link-alt\"></i></A>",
      values = {flow["COMMUNITY_ID"] .. "<button style=\"\" class=\"btn btn-sm border ms-1\" data=\"" .. flow["COMMUNITY_ID"] ..
         "\" onclick=\"NtopUtils.copyToClipboard(this.getAttribute('data'), '" .. i18n('copied') .. "', '" .. i18n('request_failed_message') ..
         "', this)\">" .. "<i class=\"fas fa-copy\"></i></button>"}
   }
end

-- ###############################################

local function add_info_field(flow)
   local protocol_info_json = json.decode(flow["PROTOCOL_INFO_JSON"] or '') or {}
   local proto_details = {}
   local add_info = true
   if table.len(protocol_info_json) >= 1 then
      for proto, info in pairs(protocol_info_json["proto"] or {}) do
         if proto == "tls" then
            add_info = isEmptyString(info.client_requested_server_name)
            break
         elseif proto == "dns" then
            add_info = isEmptyString(info.last_query)
            break
         elseif proto == "http" then
            add_info = isEmptyString(info.last_url)
            break
         elseif proto == "icmp" then
            -- Alwais add for icmp
            break
         end
      end
   end

   return add_info
end

-- ###############################################

local function format_historical_info(flow)
   local historical_flow_utils = require "historical_flow_utils"
   local info_field = historical_flow_utils.get_historical_url(flow["INFO"], "info", flow["INFO"], true, flow["INFO"], true)

   return {
      name = i18n("db_explorer.info"),
      values = {info_field}
   }
end

-- ###############################################

local function format_historical_probe(flow_details, flow, info)
   local historical_flow_utils = require "historical_flow_utils"
   local format_utils = require "format_utils"

   local alias = getFlowDevAlias(info["probe_ip"]["value"], true)
   local name

   if alias == info["probe_ip"]["value"] then
      name = format_name_value(info["probe_ip"]["value"], info["probe_ip"]["label"], true)
   else
      name = alias
   end

   local info_field = {
      device_ip = historical_flow_utils.get_historical_url(name, "probe_ip", info["probe_ip"]["value"], true, info["probe_ip"]["title"])
   }

   if (flow["INPUT_SNMP"]) and (tonumber(flow["INPUT_SNMP"]) ~= 0) then
      info_field["input_interface"] = historical_flow_utils.get_historical_url(
         format_utils.formatSNMPInterface(flow["PROBE_IP"], flow["INPUT_SNMP"]), "input_snmp", info["input_snmp"]["value"], true,
         info["input_snmp"]["title"])
   end

   if (flow["OUTPUT_SNMP"]) and (tonumber(flow["OUTPUT_SNMP"]) ~= 0) then
      info_field["output_interface"] = historical_flow_utils.get_historical_url(
         format_utils.formatSNMPInterface(flow["PROBE_IP"], flow["OUTPUT_SNMP"]), "output_snmp", info["output_snmp"]["value"], true,
         info["output_snmp"]["title"])
   end

   if table.len(info_field) > 1 then
      flow_details[#flow_details + 1] = {
         name = i18n("details.flow_snmp_localization"),
         values = {""}
      }
      for field, value in pairs(info_field) do
         flow_details[#flow_details + 1] = {
            name = "",
            values = {i18n(field), value}
         }
      end
   end

   return flow_details
end

-- ###############################################

local function format_historical_latency(flow, value, cli_or_srv)
   return {
      name = i18n("db_explorer." .. cli_or_srv .. "_latency"),
      values = {(tonumber(flow[value]) / 1000) .. " msec"}
   }
end

-- ###############################################

local function format_historical_application_latency(latency)
   return {
      name = i18n("flow_details.application_latency"),
      values = {(tonumber(latency)) .. " ms"}
   }
end

-- ###############################################

local function format_historical_obs_point(flow)
   return {
      name = i18n("db_explorer.observation_point"),
      values = {getObsPointAlias(flow["OBSERVATION_POINT_ID"], true, true)}
   }
end

-- ###############################################

local function format_historical_proto_info(flow_details, proto_info)
   local info = format_proto_info(flow_details, proto_info)
   return info
end

-- ###############################################

local function format_historical_custom_fields(flow_details, custom_fields)
   if table.len(custom_fields) > 0 then
      require "flow_utils"
      local flow_field_value_maps = require "flow_field_value_maps"
      local ordered_fields = {}

      for key, value in pairs(custom_fields) do
         local nprobe_descr, value = flow_field_value_maps.map_field_value(interface.getId(), key, value)

         if not (nprobe_descr) then
            nprobe_descr = interface.getZMQFlowFieldDescr(key)
            if isEmptyString(nprobe_descr) then
               nprobe_descr = key
            end
         else
            nprobe_descr = getFlowKey(nprobe_descr)
         end

         if not isEmptyString(value) and value~=0 then
            ordered_fields[#ordered_fields + 1] = {
               name = "<b>" .. nprobe_descr .. "</b>",
               values = value
            }
         end
      end
      
      if table.len(ordered_fields) > 0 then

         flow_details[#flow_details + 1] = {
            name = i18n("flow_details.additional_flow_elements"),
            values = {""}
         }

         table.sort(ordered_fields, function(a, b)
            return a.name:lower() < b.name:lower()
         end)

         for _, field in ipairs(ordered_fields) do
            flow_details[#flow_details + 1] = {
               name = "",
               values = { field.name, field.values }
            }
         end
      
      end

   end

   return flow_details

end

-- ###############################################

local function format_historical_flow_traffic_stats(rowspan, cli2srv_retr, srv2cli_retr, cli2srv_ooo, srv2cli_ooo, cli2srv_lost,
   srv2cli_lost)
   local flow_details = {}

   if rowspan > 0 then
      flow_details[#flow_details + 1] = {
         name = i18n("flow_details.tcp_packet_analysis"),
         values = {"", i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\" ></i> " .. i18n("server") .. " / " .. i18n("client") ..
            " <i class=\"fas fa-long-arrow-alt-left\"></i> " .. i18n("server")}
      }

      if ((cli2srv_retr and (tonumber(cli2srv_retr) > 0)) or (srv2cli_retr and (tonumber(srv2cli_retr) > 0))) then
         flow_details[#flow_details + 1] = {
            name = "",
            values = {i18n("details.retransmissions"), formatPackets(cli2srv_retr) .. " / " .. formatPackets(srv2cli_retr)}
         }
      end
      if ((cli2srv_ooo and (tonumber(cli2srv_ooo) > 0)) or (srv2cli_ooo and (tonumber(srv2cli_ooo) > 0))) then
         flow_details[#flow_details + 1] = {
            name = "",
            values = {i18n("details.out_of_order"), formatPackets(cli2srv_ooo) .. " / " .. formatPackets(srv2cli_ooo)}
         }
      end
      if ((cli2srv_ooo and (tonumber(cli2srv_ooo) > 0)) or (srv2cli_ooo and (tonumber(srv2cli_ooo) > 0))) then
         flow_details[#flow_details + 1] = {
            name = "",
            values = {i18n("details.lost"), formatPackets(cli2srv_lost) .. " / " .. formatPackets(srv2cli_lost)}
         }
      end
   end

   return flow_details
end

-- ###############################################

-- If protocol JSON contains additional exporters information,
-- append their formatted representation to the flow details output.
-- This block extends the standard flow details with deduplicated/exporter-hop path data.
local function format_historical_flow_additional_exporter(exporters, cli_ip, srv_ip)
   local flow_details = {}

   -- Validate input: must be a table of exporters
   if not exporters or type(exporters) ~= "table" then
      return flow_details
   end

   -- Graph structures:
   -- flow_trajectory maps exporter_ip -> list of next hops
   -- nodes_names maps ip -> {label, site}
   local flow_trajectory = {}
   local nodes_names = {}

   -- Add header row for the exporters table
   flow_details[#flow_details + 1] = {
      name = i18n("exporters_info"),
      values = {
         "<b>" .. i18n("flow_exporter") .. " / " .. i18n("next_hop") .. "</b>",
         "<b>" .. i18n("flows_page.inIfIdx") .. " / ".. i18n("flows_page.outIfIdx") .. "</b>"
      }
   }

   -- Collect exporter indexes so they can be sorted numerically
   local ordered = {}
   for k in pairs(exporters) do
      ordered[#ordered + 1] = k
   end
   table.sort(ordered, function(a,b) return tonumber(a) < tonumber(b) end)

   -- Iterate exporters in sorted order
   for _, idx in ipairs(ordered) do
      local exp = exporters[idx]
      if exp then
         -- Resolve exporter and next hop display info
         local exporter_url, exporter_ip, exporter_name, site = formatExporter(exp.exporter_ip)
         local next_hop_label, next_hop_ip, next_hop_name, next_hop_site = formatNextHop(exp.next_hop)

         -- Add row to details table
         flow_details[#flow_details + 1] = {
            name = "",
            values = {
               tostring(exporter_url or "-") .. " / " .. tostring(next_hop_label or "-"),
               tostring(exp.input_idx or "-") .. " / " .. tostring(exp.output_idx or "-")
            }
         }
         -- Build graph edge: exporter -> next_hop 
         if exporter_ip then
            -- Initialize adjacency list for exporter if not present
            if not flow_trajectory[exporter_ip] then
               flow_trajectory[exporter_ip] = {}
            end

            -- Insert directed edge
            table.insert(flow_trajectory[exporter_ip], {
               next_hop = next_hop_ip,
               return_path = false
            })
            -- Register exporter node label
            nodes_names[exporter_ip] = { firstDottedElement(exporter_name), site }
         end
         -- Register next hop node label
         if next_hop_ip then
            nodes_names[next_hop_ip] = { firstDottedElement(next_hop_name), next_hop_site }
         end
      end
   end
   if table.len(flow_trajectory) > 0 then
      -- Build graph only if at least one exporter node exists
      local nodes, edges = buildExportersGraph(flow_trajectory, nodes_names, cli_ip, srv_ip)

      -- Add the graph
   end
   return flow_details
end

-- ###############################################


local function format_historical_flow_rtt(client_nw_latency, server_nw_latency)
   -- server_nw_latency and client_nw_latency are in us
   local client_nw_latency_ms = client_nw_latency / 1000
   local server_nw_latency_ms = server_nw_latency / 1000
   local rtt = client_nw_latency_ms + server_nw_latency_ms
   local cli2srv = round(client_nw_latency_ms, 3)
   local srv2cli = round(server_nw_latency_ms, 3)
   local values =
      '<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. (cli2srv * 100 / rtt) .. '%;">' .. cli2srv ..
         ' ms (client)</div>' .. '<div class="progress-bar bg-success" style="width: ' .. (srv2cli * 100 / rtt) .. '%;">' .. srv2cli ..
         ' ms (server)</div></div>'
   return {
      name = i18n("flow_details.rtt_breakdown"),
      values = {values}
   }
end

-- ###############################################

-- This function format the historical flow details page
function historical_flow_details_formatter.formatHistoricalFlowDetails(flow)
   local historical_flow_utils = require "historical_flow_utils"
   local flow_details = {}

   if flow then
      local protocol_info_json = json.decode(flow["PROTOCOL_INFO_JSON"] or '') or {}
      local info = historical_flow_utils.format_clickhouse_record(flow)
      flow_details[#flow_details + 1] = format_historical_flow_label(flow)
      flow_details = format_post_nat_info(flow_details, flow, info)
      flow_details[#flow_details + 1] = format_historical_protocol_label(flow)
      flow_details[#flow_details + 1] = format_historical_last_first_seen(flow, info)
      if protocol_info_json and protocol_info_json.verdict then
         flow_details = format_historical_verdict(flow, protocol_info_json, flow_details)
      end
      flow_details[#flow_details + 1] = historical_flow_details_formatter.format_historical_total_traffic(flow)
      flow_details[#flow_details + 1] = historical_flow_details_formatter.format_historical_client_server_bytes(flow)
      flow_details[#flow_details + 1] = historical_flow_details_formatter.format_historical_bytes_progress_bar(flow, info)

      -- Format ASN Peers if they are != 0
      local src_peer_asn = flow["SRC_PEER_ASN"]
      local dst_peer_asn = flow["DST_PEER_ASN"]
      local asn_data = historical_flow_details_formatter.format_asn_peer(flow, src_peer_asn, dst_peer_asn)

      if src_peer_asn ~= nil or dst_peer_asn ~= nil then
         flow_details[#flow_details + 1] = asn_data

      end

      if flow["QOE_SCORE"] and tonumber(flow["QOE_SCORE"]) > 0 then
         flow_details[#flow_details + 1] = historical_flow_details_formatter.format_qoe(flow, info)
      end

      if ((tonumber(flow["SERVER_NW_LATENCY_US"]) > 0) or (tonumber(flow["CLIENT_NW_LATENCY_US"]) > 0)) then
         flow_details[#flow_details + 1] = format_historical_flow_rtt(tonumber(flow["CLIENT_NW_LATENCY_US"]),
            tonumber(flow["SERVER_NW_LATENCY_US"]))
      end

      if (info['dst2src_dscp']) and (info['src2dst_dscp']) then
         flow_details[#flow_details + 1] = format_historical_tos(flow)
      end

      if (info["l4proto"]) and (info["l4proto"]["label"] == 'TCP') then
         flow_details[#flow_details + 1] = format_historical_tcp_fingerprint(flow, info)
         flow_details[#flow_details + 1] = format_historical_tcp_flags(flow, info)

         if (info["major_connection_state"] ~= 0 and info["minor_connection_state"] ~= 0) then
            local conn_states = format_tcp_connection_states(info)

            for _, state in pairs(conn_states or {}) do
               flow_details[#flow_details + 1] = {
                  name = '', -- Empty label
                  values = {state}
               }
            end
         end
      end

      if (info["cli_host_pool_id"]) and (info["cli_host_pool_id"]["value"] ~= '0') and (info["srv_host_pool_id"]["value"] ~= '0') then
         flow_details[#flow_details + 1] = format_historical_host_pool(flow, info)
      end

      if (info["score"]) and (info["score"]["value"] ~= 0) then
         flow_details = historical_flow_details_formatter.format_historical_issues(flow_details, flow)
      end

      if (info['community_id']) and (not isEmptyString(info['community_id'])) then
         flow_details[#flow_details + 1] = format_historical_community_id(flow)
      end

      if (info['info']) and (not isEmptyString(info['info']["title"])) then
         if add_info_field(flow) then
            flow_details[#flow_details + 1] = format_historical_info(flow)
         end
      end

      if tonumber(flow["CLIENT_NW_LATENCY_US"]) ~= 0 then
         flow_details[#flow_details + 1] = format_historical_latency(flow, "CLIENT_NW_LATENCY_US", "cli")
      end

      if tonumber(flow["SERVER_NW_LATENCY_US"]) ~= 0 then
         flow_details[#flow_details + 1] = format_historical_latency(flow, "SERVER_NW_LATENCY_US", "srv")
      end

      if (protocol_info_json["appl_latency"]) then
         flow_details[#flow_details + 1] = format_historical_application_latency(protocol_info_json["appl_latency"])
      end

      if (protocol_info_json["traffic_stats"] and table.len(protocol_info_json["traffic_stats"]) > 0) then
         local rowspan = 1;

         if (protocol_info_json["traffic_stats"]["cli2srv_retransmissions"] ~= 0 or
            protocol_info_json["traffic_stats"]["srv2cli_retransmissions"] ~= 0) then
            rowspan = rowspan + 1
         end

         if (protocol_info_json["traffic_stats"]["cli2srv_out_of_order"] ~= 0 or protocol_info_json["traffic_stats"]["srv2cli_out_of_order"] ~=
            0) then
            rowspan = rowspan + 1
         end

         if (protocol_info_json["traffic_stats"]["cli2srv_lost"] ~= 0 or protocol_info_json["traffic_stats"]["srv2cli_lost"] ~= 0) then
            rowspan = rowspan + 1
         end
         flow_details = table.merge(flow_details,
            format_historical_flow_traffic_stats(rowspan, protocol_info_json["traffic_stats"]["cli2srv_retransmissions"],
               protocol_info_json["traffic_stats"]["srv2cli_retransmissions"], protocol_info_json["traffic_stats"]["cli2srv_out_of_order"],
               protocol_info_json["traffic_stats"]["srv2cli_out_of_order"], protocol_info_json["traffic_stats"]["cli2srv_lost"],
               protocol_info_json["traffic_stats"]["srv2cli_lost"]))
      end

      if (protocol_info_json["exporters"] and table.len(protocol_info_json["exporters"]) > 0) then
         flow_details = table.merge(flow_details, 
               format_historical_flow_additional_exporter(protocol_info_json["exporters"], info.cli_ip.ip, info.srv_ip.ip))
      end

      if tonumber(flow["OBSERVATION_POINT_ID"]) ~= 0 then
         flow_details[#flow_details + 1] = format_historical_obs_point(flow)
      end

      if not isEmptyString(info.wlan_ssid) then
         flow_details[#flow_details + 1] = format_historical_wlan_ssid(flow, info)
      end

      if info.apn_mac and not isEmptyString(info.apn_mac.value) then
         flow_details[#flow_details + 1] = format_historical_wtp_mac_address(flow, info)
      end

      if table.len(protocol_info_json["proto"]) > 0 then
         flow_details = format_historical_proto_info(flow_details, protocol_info_json["proto"])

         if (type(flow_details[#flow_details]['values']) == 'table') and (table.len(flow_details[#flow_details]['values']) == 0) then
            table.remove(flow_details, #flow_details)
         end
      end

      if table.len(protocol_info_json["proto"]) > 0 then
         flow_details = format_historical_custom_fields(flow_details, protocol_info_json["custom_fields"])
      end
   end
   return flow_details
end

return historical_flow_details_formatter
