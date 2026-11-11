--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Context of the host details SPA page (page-host-details-route.vue): whether the host is active
-- and which views it has (the old host_details.lua navbar). Internal: only meaningful for the page.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/host/page_context.lua?ifid=0&host=192.168.1.1@0"
--

require "http_lint"
-- lua_utils: host_sites_update and fingerprint_utils require it anyway
require "lua_utils"
local rest_utils = require "rest_utils"
local auth = require "auth"

local ifid = _GET["ifid"]
local host_key = _GET["host"]

if isEmptyString(ifid) or isEmptyString(host_key) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local host_info = hostkey2hostinfo(host_key)
local host_ip = host_info["host"]
local host_vlan = host_info["vlan"] or 0
local h = interface.getHostInfo(host_ip, host_vlan)
local is_admin = isAdministrator()
local is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false
local is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false
local service_map, periodicity_map = require("behavior_utils").mapsAvailable()

local res = {
   ifid = interface.getId(),
   host = host_ip,
   vlan = host_vlan,
   found = (h ~= nil),
   is_admin = is_admin,
   is_nedge = is_nedge,
   is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false,
   is_enterprise_m = is_enterprise_m,
   has_clickhouse = ntop.isClickHouseEnabled(),
   is_pro = ntop.isPro() or false,
   alerts_enabled = areAlertsEnabled(),
   alerts_capability = auth.has_capability(auth.capabilities.alerts),
   service_map = service_map,
   periodicity_map = periodicity_map,
   is_pcap_dump = interface.isPcapDumpInterface(),
   has_ebpf = interface.hasEBPF(),
   has_geoip = ntop.hasGeoIP(),
}

if h then
   local fingerprint_utils = require "fingerprint_utils"
   local is_localhost = h["localhost"] or false

   res.label = hostinfo2label(h, true)
   res.is_localhost = is_localhost
   res.is_broadcast = h["is_broadcast"] or false
   res.is_multicast = h["is_multicast"] or false
   res.num_alerts = h["num_alerts"] or 0
   res.charts_available = areHostTimeseriesEnabled() and is_localhost and not h["is_multicast"] or false
   res.traffic_report = hasTrafficReport()

   -- Applications view: the application/category charts need their timeseries
   if res.charts_available then
      local ts_utils = require "ts_utils_core"
      -- The host:ndpi / host:ndpi_categories schemas (listSeries needs them defined)
      package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/schemas/?.lua;" .. package.path
      require "ts_5min"
      local tags = { host = host_ip, ifid = interface.getId() }
      local now = os.time()
      res.ts_l7_enabled = areHostL7TimeseriesEnabled(interface.getId()) and not table.empty(ts_utils.listSeries("host:ndpi", tags, now) or {})
      res.ts_cat_enabled = areHostCategoriesTimeseriesEnabled(interface.getId()) and not table.empty(ts_utils.listSeries("host:ndpi_categories", tags, now) or {})
   end

   -- Packets view: the size/TCP flags distributions of the host or the ARP counters of its MAC
   local pkts = 0
   for _, dir in ipairs({ "pktStats.sent", "pktStats.recv" }) do
      for _, distr in ipairs({ "size", "tcp_flags" }) do
         for _, v in pairs((h[dir] or {})[distr] or {}) do pkts = pkts + v end
      end
   end
   local mac_info = h["mac"] and interface.getMacInfo(h["mac"])
   if mac_info then
      pkts = pkts + mac_info["arp_requests.sent"] + mac_info["arp_replies.sent"] + mac_info["arp_requests.rcvd"] + mac_info["arp_replies.rcvd"]
   end
   res.has_packets = pkts > 0

   res.has_icmp = (table.len(h["ICMPv4"]) + table.len(h["ICMPv6"])) > 0
   res.has_ja4 = fingerprint_utils.has_fingerprint_stats(h, "ja4")
   res.has_hassh = fingerprint_utils.has_fingerprint_stats(h, "hassh")
   local http = h["http"]
   res.has_http = http ~= nil and ((http["sender"]["query"]["total"] > 0) or (http["receiver"]["response"]["total"] > 0)
      or table.len(http["virtual_hosts"] or {}) > 0)
   res.active_http_hosts = h["active_http_hosts"]
   res.has_listening_ports = table.len(h.listening_ports or {}) > 0

   if ntop.isPro() then
      package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
      res.sites_enabled = (ntop.getPref("ntopng.prefs.host_top_sites_creation") or "0") ~= "0"
      if res.sites_enabled and is_localhost then
         -- The time ranges with sites of the host (Sites view), i18n keys only
         local granularities = {}
         for id, g in pairs(require("host_sites_update").getGranularitySites(host_ip, host_vlan, interface.getId(), false, true) or {}) do
            granularities[#granularities + 1] = { id = tostring(id), label_i18n = g.label_i18n, order = g.order }
         end
         table.sort(granularities, function(a, b) return a.order > b.order end)
         res.sites_granularities = granularities
         res.has_sites = #granularities > 0
      end
   end

   if is_enterprise_m then
      package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
      res.has_snmp_location = h["mac"] and require("snmp_location").host_has_snmp_location(h["mac"]) or false
      res.mac = h["mac"]
      -- The host is a monitored SNMP device (its system group in the SNMP view)
      if res.has_snmp_location then
         res.is_snmp_device = require("snmp_config").get_device_config(host_ip) ~= nil
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
