--
-- (C) 2013-26 - ntop.org
--
-- Formats a historical flow record into a JSON structure
-- Returns plaintext labels for protocols, applications etc along with numeric id

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local json          = require "dkjson"
local dscp_consts   = require "dscp_consts"
local format_utils  = require "format_utils"
local alert_consts  = require "alert_consts"
local alert_entities = require "alert_entities"

local historical_flow_llm_formatter = {}

local function safe_tonumber(v)
   return tonumber(v) or 0
end

local function non_zero_string(s)
   if isEmptyString(s) or s == "0" or s == "0.0.0.0" or s == "::" then
      return nil
   end
   return s
end

local function bool_flag(v)
   return (tostring(v) == "1")
end

-- Resolve L4 protocol number to label
local l4_labels = {
   [1]  = "ICMP",
   [6]  = "TCP",
   [17] = "UDP",
   [47] = "GRE",
   [50] = "ESP",
   [58] = "ICMPv6",
   [132]= "SCTP",
}

local function l4_label(proto_id)
   return l4_labels[safe_tonumber(proto_id)] or ("L4_" .. tostring(proto_id))
end

-- Resolve alert type label (may return nil if unknown)
local function alert_label(alert_id)
   if not alert_id or safe_tonumber(alert_id) == 0 then return nil end
   local ok, label = pcall(function()
      return alert_consts.alertTypeLabel(alert_id, true)
   end)
   return ok and label or nil
end

local function build_context(flow)
   return {
      ifid            = safe_tonumber(flow["INTERFACE_ID"]),
      flow_id         = flow["FLOW_ID"],
      ntopng_instance = non_zero_string(flow["NTOPNG_INSTANCE_NAME"]),
      alert_id        = safe_tonumber(flow["STATUS"]),
      alert_label     = alert_label(flow["STATUS"]),
      alert_status    = safe_tonumber(flow["ALERT_STATUS"]),
      score           = safe_tonumber(flow["SCORE"]),
      severity        = safe_tonumber(flow["SEVERITY"]),
      observation_point_id = safe_tonumber(flow["OBSERVATION_POINT_ID"]),
   }
end

-- Build protocol 
local function build_protocol(flow, proto_info_json)
   local l4_id = safe_tonumber(flow["PROTOCOL"])
   return {
      l4_proto_id      = l4_id,
      l4_proto_label   = l4_label(l4_id),
      l7_proto_id      = safe_tonumber(flow["L7_PROTO"]),
      l7_proto_master_id = safe_tonumber(flow["L7_PROTO_MASTER"]),
      l7_category_id   = safe_tonumber(flow["L7_CATEGORY"]),
      ip_version       = safe_tonumber(flow["IP_PROTOCOL_VERSION"]),
      vlan_id          = safe_tonumber(flow["VLAN_ID"]),
      -- ICMPdetail if present
      icmp             = (proto_info_json.proto and proto_info_json.proto.icmp) and {
         type = proto_info_json.proto.icmp.type,
         code = proto_info_json.proto.icmp.code,
      } or nil,
   }
end

-- Build peers block (client / server)
local function build_peer(flow, side)
   -- side is "cli" or "srv", fields use SRC/DST prefix
   local is_cli = (side == "cli")
   local ip4    = is_cli and flow["IPV4_SRC_ADDR"] or flow["IPV4_DST_ADDR"]
   local ip6    = is_cli and flow["IPV6_SRC_ADDR"] or flow["IPV6_DST_ADDR"]
   local port   = is_cli and flow["IP_SRC_PORT"]   or flow["IP_DST_PORT"]
   local mac    = is_cli and flow["SRC_MAC"]        or flow["DST_MAC"]
   local asn    = is_cli and flow["SRC_ASN"]        or flow["DST_ASN"]
   local peer_asn = is_cli and flow["SRC_PEER_ASN"] or flow["DST_PEER_ASN"]
   local pool   = is_cli and flow["SRC_HOST_POOL_ID"] or flow["DST_HOST_POOL_ID"]
   local cc     = is_cli and flow["SRC_COUNTRY_CODE"] or flow["DST_COUNTRY_CODE"]
   local lbl    = is_cli and flow["SRC_LABEL"]      or flow["DST_LABEL"]
   local loc    = is_cli and flow["CLIENT_LOCATION"] or flow["SERVER_LOCATION"]
   local bl     = is_cli and flow["IS_CLI_BLACKLISTED"] or flow["IS_SRV_BLACKLISTED"]
   local attk   = is_cli and flow["IS_CLI_ATTACKER"]    or flow["IS_SRV_ATTACKER"]
   local vctm   = is_cli and flow["IS_CLI_VICTIM"]      or flow["IS_SRV_VICTIM"]

   return {
      ip              = non_zero_string(ip4) or non_zero_string(ip6),
      ip4             = non_zero_string(ip4),
      ip6             = non_zero_string(ip6),
      port            = (safe_tonumber(port) ~= 0) and safe_tonumber(port) or nil,
      mac             = non_zero_string(mac),
      label           = non_zero_string(lbl),
      asn             = safe_tonumber(asn),
      peer_asn        = safe_tonumber(peer_asn),
      host_pool_id    = safe_tonumber(pool),
      country_code    = non_zero_string(cc),
      location        = (safe_tonumber(loc) == 1) and "local" or "remote",
      is_blacklisted  = bool_flag(bl),
      is_attacker     = bool_flag(attk),
      is_victim       = bool_flag(vctm),
   }
end

-- Build traffic block
local function build_traffic(flow)
   local total    = safe_tonumber(flow["TOTAL_BYTES"])
   local cli2srv  = safe_tonumber(flow["SRC2DST_BYTES"])
   local srv2cli  = safe_tonumber(flow["DST2SRC_BYTES"])
   local pkt_tot  = safe_tonumber(flow["PACKETS"])
   local pkt_c2s  = safe_tonumber(flow["SRC2DST_PACKETS"])
   local pkt_s2c  = safe_tonumber(flow["DST2SRC_PACKETS"])

   local cli_pct  = (total > 0) and math.floor(cli2srv * 100 / total) or 0

   return {
      total_bytes         = total,
      total_packets       = pkt_tot,
      cli2srv_bytes       = cli2srv,
      cli2srv_packets     = pkt_c2s,
      srv2cli_bytes       = srv2cli,
      srv2cli_packets     = pkt_s2c,
      cli2srv_pct         = cli_pct,
      srv2cli_pct         = 100 - cli_pct,
   }
end

-- Build timing block
local function build_timing(flow)
   local first = safe_tonumber(flow["FIRST_SEEN"])
   local last  = safe_tonumber(flow["LAST_SEEN"])
   return {
      first_seen_epoch  = first,
      last_seen_epoch   = last,
      first_seen_human  = os.date("!%Y-%m-%dT%H:%M:%SZ", first),
      last_seen_human   = os.date("!%Y-%m-%dT%H:%M:%SZ", last),
      duration_sec      = last - first,
   }
end

-- Build latency block
local function build_latency(flow)
   local cli_us = safe_tonumber(flow["CLIENT_NW_LATENCY_US"])
   local srv_us = safe_tonumber(flow["SERVER_NW_LATENCY_US"])
   if cli_us == 0 and srv_us == 0 then return nil end
   return {
      client_nw_latency_ms = cli_us / 1000,
      server_nw_latency_ms = srv_us / 1000,
      rtt_ms               = (cli_us + srv_us) / 1000,
   }
end

-- Build TCP block (only for TCP flows)
local function build_tcp(flow, proto_info_json)
   if safe_tonumber(flow["PROTOCOL"]) ~= 6 then return nil end

   local tcp_flags = proto_info_json and proto_info_json.tcp_flags_analysis
   return {
      src2dst_flags     = safe_tonumber(flow["SRC2DST_TCP_FLAGS"]),
      dst2src_flags     = safe_tonumber(flow["DST2SRC_TCP_FLAGS"]),
      fingerprint       = non_zero_string(flow["TCP_FINGERPRINT"]),
      major_conn_state  = safe_tonumber(flow["MAJOR_CONNECTION_STATE"]),
      minor_conn_state  = safe_tonumber(flow["MINOR_CONNECTION_STATE"]),
      flags_analysis    = tcp_flags or nil,
   }
end

-- Build QoE block
local function build_qoe(flow, proto_info_json)
   local qoe_score = safe_tonumber(flow["QOE_SCORE"])
   if qoe_score == 0 then return nil end

   local qoe = proto_info_json and proto_info_json.qoe
   return {
      qoe_score       = qoe_score,
      c2s_score       = qoe and qoe.c2s and qoe.c2s.score or nil,
      s2c_score       = qoe and qoe.s2c and qoe.s2c.qoe_score or nil,
   }
end

-- Build issues / alerts block
local function build_issues(flow, alert_json)
   local score     = safe_tonumber(flow["SCORE"])
   local alert_id  = safe_tonumber(flow["STATUS"])
   local alerts_map = flow["ALERTS_MAP"] or ""

   local issues = {
      total_score  = score,
      main_alert   = {
         id    = alert_id,
         label = alert_label(tostring(alert_id)),
      },
      flow_risks   = {},
      per_alert_scores = {},
   }

   -- Flow risk info (human-readable reasons)
   local risk_info = (alert_json and alert_json.flow_risk_info) or {}
   for risk_id, description in pairs(risk_info) do
      issues.flow_risks[#issues.flow_risks + 1] = {
         risk_id     = tonumber(risk_id),
         description = description,
      }
   end

   -- Per-alert scores from ALERT_JSON.alerts
   if alert_json and alert_json.alerts then
      for aid, data in pairs(alert_json.alerts) do
         issues.per_alert_scores[#issues.per_alert_scores + 1] = {
            alert_id    = tonumber(aid),
            alert_label = alert_label(aid),
            score       = data.score,
         }
      end
   end

   -- Per-alert scores from alert_score flat map (older format)
   if alert_json and alert_json.alert_score then
      for aid, sc in pairs(alert_json.alert_score) do
         -- avoid duplicates already captured above
         if not (alert_json.alerts and alert_json.alerts[aid]) then
            issues.per_alert_scores[#issues.per_alert_scores + 1] = {
               alert_id    = tonumber(aid),
               alert_label = alert_label(aid),
               score       = sc,
            }
         end
      end
   end

   return issues
end

-- Build probe / SNMP block
local function build_probe(flow)
   local probe_ip   = non_zero_string(flow["PROBE_IP"])
   local input_snmp = safe_tonumber(flow["INPUT_SNMP"])
   local output_snmp= safe_tonumber(flow["OUTPUT_SNMP"])
   if not probe_ip and input_snmp == 0 and output_snmp == 0 then return nil end
   return {
      probe_ip     = probe_ip,
      input_snmp   = (input_snmp  ~= 0) and input_snmp  or nil,
      output_snmp  = (output_snmp ~= 0) and output_snmp or nil,
   }
end

-- Main public function
function historical_flow_llm_formatter.formatFlowForLLM(flow)
   if not flow then return nil end

   -- Decode embedded JSON blobs
   local proto_info_json = json.decode(flow["PROTOCOL_INFO_JSON"] or "") or {}
   local alert_json      = json.decode(flow["ALERT_JSON"]          or "") or {}

   local result = {
      context  = build_context(flow),
      protocol = build_protocol(flow, proto_info_json),
      client   = build_peer(flow, "cli"),
      server   = build_peer(flow, "srv"),
      timing   = build_timing(flow),

      -- Bytes / packets
      traffic  = build_traffic(flow),
      latency  = build_latency(flow),
      tcp      = build_tcp(flow, proto_info_json),
      qoe      = build_qoe(flow, proto_info_json),

      -- Security issues and scored alerts
      issues   = build_issues(flow, alert_json),
      probe    = build_probe(flow),
      info     = non_zero_string(flow["INFO"]),

   }

   return result
end

-- Convenience: return JSON string directly
function historical_flow_llm_formatter.flowToJSONString(flow, pretty)
   local result = historical_flow_llm_formatter.formatFlowForLLM(flow)
   if not result then return "{}" end
   return result
end

return historical_flow_llm_formatter