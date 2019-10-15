--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "flow_utils"
local json = require ("dkjson")

local syslog_module = {
  key = "suricata",
  hooks = {},
}

-- #################################################################

-- The function below ia called once (#pragma once)
function syslog_module.setup()
   return true
end

-- #################################################################

local function parseFiveTuple(event, flow)
   flow.vlan_id = tonumber(event.vlan)
   flow.src_ip = event.src_ip
   flow.dst_ip = event.dest_ip
   flow.src_port = tonumber(event.src_port)
   flow.dst_port = tonumber(event.dest_port)
   flow.l4_proto = event.proto
end

-- #################################################################

local function parseFlowMetadata(event_flow, flow)
   flow.first_switched_iso8601 = event_flow.start
   flow.last_switched_iso8601 = event_flow['end']
   flow.in_pkts = tonumber(event_flow.pkts_toserver)
   flow.out_pkts = tonumber(event_flow.pkts_toclient)
   flow.in_bytes = tonumber(event_flow.bytes_toserver)
   flow.out_bytes = tonumber(event_flow.bytes_toclient)
end

-- #################################################################

local function parseAlertMetadata(event_alert, flow)
   flow.external_alert_severity = tonumber(event_alert.severity)
   flow.external_alert = json.encode(event_alert)
end

-- #################################################################

local function parseNetflowMetadata(event_flow, flow)
   flow.first_switched_iso8601 = event_flow.start
   flow.last_switched_iso8601 = event_flow['end']
   flow.in_pkts = tonumber(event_flow.pkts)
   flow.in_bytes = tonumber(event_flow.bytes)
end

-- #################################################################

local function parseHTTPMetadata(event_http, flow)
   flow.http_method = event_http.http_method
   flow.http_ret_code = tonumber(event_http.status)
   flow.http_site = event_http.hostname
   if event_http.hostname ~= nil and event_http.url ~= nil then
      flow.http_url = event_http.hostname..event_http.url
   end

   -- Additional fields
   flow.HTTP_PROTOCOL = event_http.protocol
   flow.HTTP_REFERER = event_http.http_refer
   flow.HTTP_MIME = event_http.http_content_type
   flow.HTTP_LENGTH = event_http.length
end

-- #################################################################

local function parseDNSMetadata(event_dns, flow)

   if event_dns.type == "query" then
      flow.dns_query = event_dns.rrname
      flow.dns_query_type = get_dns_type(event_dns.rrtype)
   end

   -- Additional fields
   flow.DNS_QUERY_ID = event_dns.id
   flow.DNS_TX_ID = event_dns.tx_id
end

-- #################################################################

local function parseTLSMetadata(event_tls, flow)

   flow.ssl_server_name = event_tls.sni
   -- flow.ja3c_hash = event_tls.ja3
   -- flow.ja3s_hash = event_tls.ja3s

   -- Additional fields
   flow.TLS_VERSION = event_tls.version
   flow.TLS_SESSION_RESUMED = event_tls.session_resumed
end

-- #################################################################

-- The function below is called for each received alert
function syslog_module.hooks.handleEvent(message)
   local event = json.decode(message)
   if event == nil then
      return
   end

   local flow = {}
   parseFiveTuple(event, flow)

   -- Additional (common) fields
   flow.SURICATA_FLOW_ID = event.flow_id
   flow.SURICATA_APP_PROTO = event.app_proto
   flow.COMMUNITY_ID = event.community_id

   if event.event_type == "alert" then

      if event.flow ~= nil then
         parseFlowMetadata(event.flow, flow)
         if flow.last_switched_iso8601 == nil then
            flow.last_switched_iso8601 = event.timestamp
         end
         parseAlertMetadata(event.alert, flow)
      else
         flow = nil
      end
 
   elseif event.event_type == "netflow" then
      parseNetflowMetadata(event.netflow, flow)

   elseif event.event_type == "http" then
      parseHTTPMetadata(event.http, flow)

   elseif event.event_type == "dns" then
      parseDNSMetadata(event.dns, flow) 

   elseif event.event_type == "tls" then
      parseTLSMetadata(event.tls, flow) 

   else
      -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "Unsupported Suricata event '"..event.event_type.."'")
      flow = nil
   end

   if flow ~= nil then
      interface.processFlow(flow)
   end
end 

-- #################################################################

-- The function below ia called once (#pragma once)
function syslog_module.teardown()
   return true
end

-- #################################################################

return syslog_module
