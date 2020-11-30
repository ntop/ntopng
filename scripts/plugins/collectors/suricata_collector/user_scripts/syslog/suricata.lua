--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "flow_utils"
local json = require ("dkjson")
local alert_severities = require "alert_severities"
local user_scripts = require("user_scripts")

local syslog_module = {
  -- Script category
  category = user_scripts.script_categories.security,

  nedge_exclude = true,

  key = "suricata",

  -- See below
  hooks = {},

  gui = {
    i18n_title = "suricata_collector.title",
    i18n_description = "suricata_collector.description",
  },
}

local external_stats_key = "ntopng.prefs.ifid_"..tostring(interface.getId())..'.external_stats'

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.setup()
   -- Cleanup old stats, if any
   ntop.delCache(external_stats_key)

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
   local severity = alert_severities.error

   if event_alert.severity ~= nil and event_alert.severity > 1 then
      severity = alert_severities.warning
   end

   local external_alert = {
      source = "suricata",
      severity_id = severity.severity_id,
      alert = event_alert,
   }

   flow.external_alert = json.encode(external_alert)
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

local function parseFileInfoMetadata(event_fileinfo, flow)
   -- Additional fields
   flow.FILE_NAME = event_fileinfo.filename
   flow.FILE_SIZE = event_fileinfo.size
   flow.FILE_STATE = event_fileinfo.state
   flow.FILE_GAPS = event_fileinfo.gaps
   flow.FILE_STORED = event_fileinfo.stored
   flow.FILE_ID = event_fileinfo.file_id
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
   flow.tls_server_name = event_tls.sni

   if event_tls.ja3  ~= nil then flow.ja3c_hash = event_tls.ja3.hash  end
   if event_tls.ja3s ~= nil then flow.ja3s_hash = event_tls.ja3s.hash end

   -- Additional fields
   flow.TLS_VERSION = event_tls.version
   flow.TLS_CERT_NOT_BEFORE = event_tls.notbefore
   flow.TLS_CERT_AFTER = event_tls.notafter
   flow.TLS_CERT_SHA1 = event_tls.fingerprint
   flow.TLS_CERT_SUBJECT = event_tls.subject
   flow.TLS_CERT_DN = event_tls.issuerdn
   flow.TLS_CERT_SN = event_tls.serial
end

-- #################################################################

local function parseStats(event_stats)
   local external_stats = {}

   external_stats.capture_packets = (event_stats.capture.kernel_packets - event_stats.capture.kernel_drops)
   external_stats.capture_drops = event_stats.capture.kernel_drops

   external_stats.signatures_loaded = 0
   external_stats.signatures_failed = 0
   for _, engine in ipairs(event_stats.detect.engines) do
     external_stats.signatures_loaded = external_stats.signatures_loaded + engine.rules_loaded
     external_stats.signatures_failed = external_stats.signatures_failed + engine.rules_failed
   end

   external_stats.i18n_title = "suricata_collector.statistics"

   local external_json_stats = json.encode(external_stats)
   ntop.setCache(external_stats_key, external_json_stats)
end

-- #################################################################

-- The function below is called for each received alert
function syslog_module.hooks.handleEvent(syslog_conf, message, host, priority)
   local handled = false
   local num_unhandled = 0
   local num_alerts = 0
   local num_collected_flows = 0

   local event = json.decode(message)
   if event == nil or type(event) ~= "table" then
      num_unhandled = num_unhandled + 1
      interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, num_collected_flows)
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
         if event.alert ~= nil then
            parseAlertMetadata(event.alert, flow)
            num_alerts = num_alerts + 1
         else
            num_unhandled = num_unhandled + 1
            flow = nil
         end
      else
         num_unhandled = num_unhandled + 1
         flow = nil
      end
 
   elseif event.event_type == "netflow" and event.netflow ~= nil then
      parseNetflowMetadata(event.netflow, flow)
      num_collected_flows = num_collected_flows + 1

   elseif event.event_type == "http" and event.http ~= nil then
      parseHTTPMetadata(event.http, flow)
      num_collected_flows = num_collected_flows + 1

   elseif event.event_type == "fileinfo" then
      if event.app_proto == "http" and event.http ~= nil then
         parseHTTPMetadata(event.http, flow)
      end
      parseFileInfoMetadata(event.fileinfo, flow)
      num_collected_flows = num_collected_flows + 1

   elseif event.event_type == "dns" and event.dns ~= nil then
      parseDNSMetadata(event.dns, flow) 
      num_collected_flows = num_collected_flows + 1

   elseif event.event_type == "tls" and event.tls ~= nil then
      parseTLSMetadata(event.tls, flow) 
      num_collected_flows = num_collected_flows + 1

   elseif event.event_type == "stats" and event.stats ~= nil then
      parseStats(event.stats)
      flow = nil

   else
      -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "Unsupported Suricata event '"..event.event_type.."'")
      num_unhandled = num_unhandled + 1
      flow = nil
   end

   if flow ~= nil then
      -- If first/last ts is not available, use the event timestamp as last resort
      if flow.first_switched_iso8601 == nil then
         flow.first_switched_iso8601 = event.timestamp
      end
      if flow.last_switched_iso8601 == nil then
         flow.last_switched_iso8601 = event.timestamp
      end

      -- Processing flow or alert
      interface.processFlow(flow)
   end

   interface.incSyslogStats(1, 0, num_unhandled, num_alerts, 0, num_collected_flows)
end 

-- #################################################################

-- The function below is called once (#pragma once)
function syslog_module.teardown()
   return true
end

-- #################################################################

return syslog_module
