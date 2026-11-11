--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Overview of one live flow (Flow Details page and the side card of the live flows): the flow as
-- the engine exports it (raw keys, e.g. "cli2srv.bytes") in rsp.flow, plus in rsp.ext what only
-- the server resolves (names of hosts, AS, sites, exporters and observation points, VLAN alias,
-- tags, issues, VoIP rows, additional exported fields, protocol views of the flow). Raw values:
-- the page formats and translates them.
-- counters=true: only rsp.flow (polled for the live values). bgp=true: also ext.bgp_info.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/flow/live/overview.lua?ifid=0&flow_key=1&flow_hash_id=2"
--

-- http_lint (validates _GET, ntop_utils) + rest_utils: enough for the polled counters
require "http_lint"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]
local flow_key = tonumber(_GET["flow_key"])
local flow_hash_id = tonumber(_GET["flow_hash_id"])

if isEmptyString(ifid) or (flow_key == nil) or (flow_hash_id == nil) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- Hosts outside the allowed networks of the user are not found
local flow = interface.findFlowByKeyAndHashId(flow_key, flow_hash_id)

if flow == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- Internal alert serialization: the issues below carry what the page needs
local json_alert_str = flow["json_alert"]
flow["json_alert"] = nil

if _GET["counters"] == "true" then
   rest_utils.answer(rest_utils.consts.success.ok, { flow = flow, now = os.time() })
   return
end

require "lua_utils_gui"
local json = require "dkjson"
local ifstats = interface.getStats()
local is_pro = (ntop.isPro and ntop.isPro()) or false
local is_admin = isAdministrator()
local is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false

local ext = {
   ifid = interface.getId(),
   is_view = interface.isView(),
   -- Viewed interfaces have no hosts: no links to the host pages
   is_viewed = ifstats.isViewed or false,
   is_packet_interface = interface.isPacketInterface(),
   is_zmq = (ifstats.type == "zmq"),
   is_inline = ifstats.inline or false,
   is_pro = is_pro,
   is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false,
   is_enterprise_l = is_enterprise_l,
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false,
   is_admin = is_admin,
   score_enabled = ((ntop.isEnterpriseM and ntop.isEnterpriseM()) or (ntop.isnEdgeEnterprise and ntop.isnEdgeEnterprise())) or false,
   has_clickhouse = hasClickHouseSupport(),
   has_nanalyst = isnAnalystAvailable(),
   throughput_type = getThroughputType(),
   now = os.time(),
   cli_name = flowinfo2hostname(flow, "cli"),
   srv_name = flowinfo2hostname(flow, "srv"),
}

-- The interface of the view where the flow was seen
if ext.is_view and flow.iface_index then
   interface.select(tostring(flow.iface_index))
   ext.iface_name = getInterfaceName(flow.iface_index, true)
   ext.iface_type = interface.isPcapDumpInterface() and "pcap" or (interface.isPacketInterface() and "packet"
      or (interface.isZMQInterface() and "zmq" or nil))
   interface.select(tostring(ext.ifid))
end

if (flow.vlan or 0) > 0 then
   ext.vlan_name = getFullVlanName(flow.vlan)
end

-- Tags of the flow (bitmap of tag ids)
local flow_tags = flow["tags"] or 0
if flow_tags ~= 0 then
   local tag_badge_utils = require "tag_badge_utils"
   ext.tags = {}
   for _, tag in ipairs(tag_badge_utils.getTags()) do
      if math.floor(flow_tags / (2 ^ tag.id)) % 2 ~= 0 then
         ext.tags[#ext.tags + 1] = { id = tag.id, name = tag.name, color = tag.color }
      end
   end
end

if (flow["verdict.pass"] == false) and flow["verdict.reason"] then
   local flow_consts = require "flow_consts"
   local reason = flow_consts.drop_reason[flow["verdict.reason"]]
   ext.drop_reason_i18n = reason and reason.i18n_label
end

if (flow["protos.tls_version"] or 0) ~= 0 then
   ext.tls_version_name = ntop.getTLSVersionName(flow["protos.tls_version"])
end

-- Names of the AS of the flow (src/dst names are in the flow: peer and adjacent ones)
ext.as_names = {}
for _, k in ipairs({ "src_peer_as", "dst_peer_as", "prev_adjacent_as", "next_adjacent_as" }) do
   local asn = tonumber(flow[k])
   if asn and asn ~= 0 then
      local info = ntop.getASNameFromASN(asn)
      ext.as_names[tostring(asn)] = info and (info.description or info.handle) or nil
   end
end

-- Site names of the peers, the exporter, the next hop and the exporters
local site_ids = {}
for _, k in ipairs({ "cli.site_id", "srv.site_id", "exporter_site_id", "next_hop_site_id" }) do
   local id = flow[k]
   if id and id ~= 0 then site_ids[id] = true end
end
for _, e in pairs(flow.exporters or {}) do
   if (e.exporter_site_id or 0) ~= 0 then site_ids[e.exporter_site_id] = true end
   if (e.next_hop_site_id or 0) ~= 0 then site_ids[e.next_hop_site_id] = true end
end
if next(site_ids) then
   local site_utils = require "site_utils"
   ext.site_names = {}
   for id in pairs(site_ids) do
      ext.site_names[tostring(id)] = site_utils.getSiteName(id)
   end
end

if (flow.observation_point_id or 0) ~= 0 then
   ext.observation_point_name = getObsPointAlias(flow.observation_point_id, true, false)
end

if flow.igmp then
   ext.igmp_type = igmpType2String(flow.igmp.type)
end

-- ICMP unreachable: the flow it refers to, when still active
local unreach = flow.icmp and flow.icmp.unreach
if unreach then
   require "flow_utils" -- getFlowLabel
   local uf = interface.findFlowByTuple(flow["cli.ip"], flow["srv.ip"], flow["vlan"], unreach.dst_port, unreach.src_port, unreach.protocol)
   if uf then
      ext.icmp_unreach_flow = { flow_key = uf["ntopng.key"], flow_hash_id = uf["hash_entry_id"],
         label = getFlowLabel(uf, false, false, nil, nil, false, false, true) }
   end
end

-- IEC 60870-5-104 type ids labels
if flow.iec104 and next(flow.iec104.typeid or {}) then
   require "lua_utils" -- iec104_typeids2str
   ext.iec104_labels = {}
   local function add(id)
      id = tostring(id)
      if not ext.iec104_labels[id] then ext.iec104_labels[id] = iec104_typeids2str(tonumber(id)) end
   end
   for k in pairs(flow.iec104.typeid) do add(k) end
   for k in pairs(flow.iec104.typeid_transitions or {}) do
      local a, b = k:match("^(%d+),(%d+)$")
      if a then add(a); add(b) end
   end
end

-- Exporters (collected flows): names of exporter, next hop and SNMP interfaces (with their role)
if is_pro and flow.exporters and next(flow.exporters) then
   require "flow_utils" -- buildExportersGraph
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   local ok, snmp_utils = pcall(require, "snmp_utils")
   local function if_info(device_ip, idx)
      if (idx == nil) or (idx == 0) then return nil end
      local role = ok and snmp_utils.get_snmp_interface_role(device_ip, tostring(idx)) or nil
      return { index = idx, name = format_portidx_name(device_ip, tostring(idx), true), role = role and role.value or nil }
   end
   ext.exporters = {}
   local flow_trajectory, nodes_names = {}, {}
   for _, v in pairs(flow.exporters) do
      local has_next_hop = v.next_hop and v.next_hop ~= "0.0.0.0"
      ext.exporters[#ext.exporters + 1] = {
         exporter_ip = v.exporter_ip,
         exporter_name = getExporterName(v.exporter_ip, true, true, false),
         next_hop = has_next_hop and v.next_hop or nil,
         next_hop_name = has_next_hop and getExporterName(v.next_hop, true, true, false) or nil,
         input = if_info(v.exporter_ip, v.input_idx),
         output = if_info(v.exporter_ip, v.output_idx),
         exporter_site_id = v.exporter_site_id,
         next_hop_site_id = v.next_hop_site_id,
         return_path = v.return_path or false,
      }
      if has_next_hop then
         local site_utils = require "site_utils"
         nodes_names[v.exporter_ip] = { v.exporter_ip, site_utils.getSiteName(v.exporter_site_id) }
         nodes_names[v.next_hop] = { v.next_hop, site_utils.getSiteName(v.next_hop_site_id) }
         flow_trajectory[v.exporter_ip] = flow_trajectory[v.exporter_ip] or {}
         flow_trajectory[v.exporter_ip][#flow_trajectory[v.exporter_ip] + 1] = { next_hop = v.next_hop, return_path = v.return_path }
      end
   end
   -- The path of the flow across the exporters: drawn when it has at least 3 nodes
   if next(flow_trajectory) then
      local nodes, edges = buildExportersGraph(flow_trajectory, nodes_names, flow["cli.ip"], flow["srv.ip"])
      if table.len(nodes) >= 3 then
         ext.exporters_graph = { nodes = nodes, edges = edges }
      end
   end
end
if is_pro and not isEmptyString(flow.device_ip) and flow.device_ip ~= "0.0.0.0" then
   ext.device_name = getExporterName(flow.device_ip, true, true, false)
end

-- Fields exported by the probe (moreinfo.json): VoIP rows (SIP, RTP) and the additional fields
if flow["moreinfo.json"] then
   local info = json.decode(flow["moreinfo.json"], 1, nil)
   if type(info) == "table" and next(info) then
      -- flow_utils (getFlowValue, SIP/RTP helpers) loads lua_utils (~30 ms): only for these flows
      require "flow_utils"
      local flow_field_value_maps = require "flow_field_value_maps"
      local syminfo = {}
      for key, value in pairs(info) do
         local mkey, mvalue = flow_field_value_maps.map_field_value(ext.ifid, key, value)
         if mkey then
            syminfo[mkey] = mvalue
         else
            local descr = interface.getZMQFlowFieldDescr(key)
            syminfo[(not isEmptyString(descr) and descr ~= key) and descr or key] = value
         end
      end
      info = syminfo

      local function value_of(field)
         local _, v = getFlowValue(info, field)
         if (v == nil) or (v == "0") or (v == "") then return nil end
         return v
      end

      -- SIP call (Pro): the rows of the old page, as values
      if is_pro and (flow["proto.ndpi"] == "SIP") and (isThereProtocol("SIP", info) == 1) and (isThereSIPCall(info) == 1) then
         local function caller(field)
            local v = value_of(field)
            if v then v = extractSIPCaller(string.gsub(v, "\\\"", "\"")) end
            return v
         end
         local sip = {
            call_id = flow["protos.sip_call_id"] or value_of("SIP_CALL_ID"),
            call_state = value_of("SIP_CALL_STATE"),
            calling_party = caller("SIP_CALLING_PARTY"),
            called_party = caller("SIP_CALLED_PARTY"),
            rtp_codecs = value_of("SIP_RTP_CODECS"),
            reason_cause = value_of("SIP_REASON_CAUSE"),
            c_ip = value_of("SIP_C_IP"),
            rtp_src_ip = value_of("SIP_RTP_IPV4_SRC_ADDR"),
            rtp_src_port = tonumber(value_of("SIP_RTP_L4_SRC_PORT")),
            rtp_dst_ip = value_of("SIP_RTP_IPV4_DST_ADDR"),
            rtp_dst_port = tonumber(value_of("SIP_RTP_L4_DST_PORT")),
         }
         if sip.rtp_src_ip == "0.0.0.0" then sip.rtp_src_ip = nil end
         if sip.rtp_dst_ip == "0.0.0.0" then sip.rtp_dst_ip = nil end
         -- The RTP flow of the call, when active
         if sip.rtp_src_ip and sip.rtp_dst_ip then
            local key = interface.getFlowKey(sip.rtp_src_ip, sip.rtp_src_port or 0, sip.rtp_dst_ip, sip.rtp_dst_port or 0, 17 --[[ UDP ]])
            local rf = tonumber(key) and interface.findFlowByKeyAndHashId(tonumber(key), 0)
            if rf then sip.rtp_flow = { flow_key = rf["ntopng.key"], flow_hash_id = rf["hash_entry_id"] } end
         end
         ext.sip = sip
      end

      -- RTP stream (Pro): quality indicators per direction
      if is_pro and (flow["proto.ndpi"] == "RTP") and (isThereProtocol("RTP", info) == 1) then
         local voip_utils = require "voip_utils"
         local function num(field, div)
            local v = tonumber(value_of(field))
            return v and (div and (v / div) or v) or nil
         end
         local in_pt, out_pt = value_of("RTP_IN_PAYLOAD_TYPE"), value_of("RTP_OUT_PAYLOAD_TYPE")
         ext.rtp = {
            ssrc = value_of("RTP_SSRC"),
            rtt = num("RTP_RTT"),
            transit_in = num("RTP_IN_TRANSIT", 100),
            transit_out = num("RTP_OUT_TRANSIT", 100),
            dtmf_tones = value_of("RTP_DTMF_TONES"),
            first_seq = value_of("RTP_FIRST_SEQ"),
            sip_call_id = value_of("RTP_SIP_CALL_ID"),
            jitter_in = num("RTP_IN_JITTER", 100),
            jitter_out = num("RTP_OUT_JITTER", 100),
            lost_in = num("RTP_IN_PKT_LOST"),
            lost_out = num("RTP_OUT_PKT_LOST"),
            drop_in = num("RTP_IN_PKT_DROP"),
            drop_out = num("RTP_OUT_PKT_DROP"),
            max_delta_in = num("RTP_IN_MAX_DELTA"),
            max_delta_out = num("RTP_OUT_MAX_DELTA"),
            payload_in = in_pt and tostring(formatRtpPayloadType(in_pt)) or nil,
            payload_out = out_pt and tostring(formatRtpPayloadType(out_pt)) or nil,
            mos_in = num("RTP_IN_MOS", 100),
            mos_out = num("RTP_OUT_MOS", 100),
            r_factor_in = num("RTP_IN_R_FACTOR", 100),
            r_factor_out = num("RTP_OUT_R_FACTOR", 100),
         }
      end

      info = removeProtocolFields("SIP", info)
      info = removeProtocolFields("RTP", info)

      -- The other fields, with their description (not the ones already shown)
      require "flow_key_utils"
      local fields = {}
      for key, value in pairsByKeys(info) do
         if tonumber(key) then key = getFlowLabelFromId(key) end
         local lkey = string.lower(key)
         local dup = (flow[lkey] ~= nil) and not isEmptyString(flow[lkey])
         local empty = (type(value) == "table") and (next(value) == nil) or ((type(value) ~= "table") and isEmptyString(value))
         if not dup and not empty and key ~= "CLIENT_TCP_FLAGS" and key ~= "SERVER_TCP_FLAGS" and key ~= "L7_RISK_SCORE" then
            fields[#fields + 1] = { key = key, label = getFlowKey(key), value = value }
         end
      end
      ext.fields = fields
      ext.tcp_flags_json = { client = info["CLIENT_TCP_FLAGS"], server = info["SERVER_TCP_FLAGS"] }
   end
end

-- Descriptions of the exported fields shown in their own rows
if flow.wlan or flow.smtp_mail_from or flow.smtp_rcpt_to or flow.flow_end_reason then
   require "flow_key_utils"
   ext.field_labels = {}
   for _, k in ipairs({ "WLAN_SSID", "WTP_MAC_ADDRESS", "SMTP_MAIL_FROM", "SMTP_RCPT_TO", "FLOW_END_REASON" }) do
      ext.field_labels[k] = getFlowKey(k)
   end
end

-- Issues: the flow alerts (from a check) and the nDPI risks without a check (score 0)
local alerts_map = flow["alerts_map"] or {}
local unhandled = flow["unhandled_flow_risk"] or {}
if next(alerts_map) or next(unhandled) then
   local alert_consts = require "alert_consts"
   local alert_entities = require "alert_entities"
   local flow_entity = alert_entities.flow.entity_id
   local risk_info = {}
   if not isEmptyString(flow.riskInfo) then
      risk_info = json.decode(flow.riskInfo, 1, nil) or {}
   end
   local alert_json
   local issues = {}

   for id in pairs(alerts_map) do
      local alert_id = tonumber(id)
      local risk = ntop.getFlowAlertRisk(alert_id) or 0
      local alert_key = alert_consts.getAlertType(alert_id, flow_entity)
      local type_info = alert_key and alert_consts.alert_types[alert_key]
      local issue = {
         alert_id = alert_id,
         risk_id = risk,
         source = (risk == 0) and "ntopng" or "nDPI",
         score = (flow.score and flow.score.alert_score and flow.score.alert_score[tostring(id)]) or 0,
         title_i18n = type_info and ((type_info.meta and type_info.meta.i18n_title) or type_info.i18n_title),
         is_predominant = (alert_id == flow["predominant_alert"]),
         info = risk_info[tostring(risk)],
      }
      local mitre = alert_key and alert_consts.getAlertMitreInfo(alert_key)
      if mitre and mitre.mitre_id then
         issue.mitre_id = mitre.mitre_id
         issue.mitre_tactic_i18n = mitre.mitre_tactic and mitre.mitre_tactic.i18n_label
      end
      -- ntopng alerts: the message of the alert (text only), as the old page
      if (risk == 0) and not isEmptyString(json_alert_str) then
         if alert_json == nil then
            alert_json = json.decode(json_alert_str) or false
         end
         local this_json = alert_json and alert_json.alerts and alert_json.alerts[tostring(alert_id)]
         local alert_utils = require "alert_utils"
         flow["json_alert"] = json_alert_str
         flow.alert_id = alert_id
         local msg = alert_utils.formatFlowAlertMessage(ext.ifid, alert_utils.formatAlertFromFlow(flow), this_json, false, true, true)
         flow["json_alert"] = nil
         flow.alert_id = nil
         issue.info = (type(msg) == "string") and noHtml(msg) or nil
      end
      issues[#issues + 1] = issue
   end

   for risk_str, risk_id in pairs(unhandled) do
      issues[#issues + 1] = { risk_id = risk_id, source = "nDPI", score = 0, label = risk_str, unhandled = true,
         info = risk_info[tostring(risk_id)] }
   end

   ext.issues = issues
   local auth = require "auth"
   ext.can_disable_check = (auth.has_capability(auth.capabilities.checks) and ext.is_enterprise_m) or false
end

-- nEdge (inline): shapers and pools of the peers, marker, device protocol policies
if is_pro and ifstats.inline and (flow["shaper.cli"] ~= nil) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   local shaper_utils = require "shaper_utils"
   local nedge = { cli_shaper = noHtml(shaper_utils.nedge_shaper_id_to_shaper(flow["shaper.cli"]).text or ""),
      srv_shaper = noHtml(shaper_utils.nedge_shaper_id_to_shaper(flow["shaper.srv"]).text or "") }
   if ext.is_nedge then
      local host_pools_nedge = require "host_pools_nedge"
      if flow["cli.pool_id"] then nedge.cli_user = host_pools_nedge.poolIdToUsername(flow["cli.pool_id"]) end
      if flow["srv.pool_id"] then nedge.srv_user = host_pools_nedge.poolIdToUsername(flow["srv.pool_id"]) end
      local cli_mac = flow["cli.mac"] and interface.getMacInfo(flow["cli.mac"])
      nedge.invalid_src_location = cli_mac and (cli_mac.location ~= "lan") or false
      local nf_config_ok, nf_config = pcall(function()
         package.path = dirs.installdir .. "/scripts/lua/pro/nedge/modules/system_config/?.lua;" .. package.path
         return require("nf_config")
      end)
      if nf_config_ok then nedge.marker = noHtml(nf_config.formatMarker(flow["marker"]) or "") end
   end
   ext.nedge = nedge
end

-- Protocol views of the flow (tabs of the page), as the old navbar
ext.views = {}
if flow.modbus and is_enterprise_l then ext.views[#ext.views + 1] = "modbus" end
if flow.bgp and (flow.bgp.src or flow.bgp.dst) then ext.views[#ext.views + 1] = "bgp" end
if flow.s7comm and is_enterprise_l then ext.views[#ext.views + 1] = "s7comm" end
if flow.profinet and is_enterprise_l then ext.views[#ext.views + 1] = "profinet" end

if (_GET["bgp"] == "true") and flow.bgp then
   local bgp_utils = require "bgp_utils"
   ext.bgp_info = bgp_utils.formatFlowBgpBmpInfo(flow)
end

rest_utils.answer(rest_utils.consts.success.ok, { flow = flow, ext = ext })
