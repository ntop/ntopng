--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Context of the MAC details SPA page (page-mac-details-route.vue): whether the MAC is active and
-- which views it has (the old mac_details.lua navbar). Internal: only meaningful for the page.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/mac/page_context.lua?ifid=0&host=AA:BB:CC:DD:EE:FF"
--

require "http_lint"
require "lua_utils_get"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]
local mac = _GET["host"]

if isEmptyString(ifid) or isEmptyString(mac) or not isMacAddress(mac) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local mac_info = interface.getMacInfo(mac)
local has_snmp_location = false

if ntop.isEnterpriseM and ntop.isEnterpriseM() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   has_snmp_location = require("snmp_location").host_has_snmp_location(mac)
end

local serialize_by_mac = ntop.getPref("ntopng.prefs.ifid_" .. interface.getId() .. ".serialize_local_broadcast_hosts_as_macs") == "1"

rest_utils.answer(rest_utils.consts.success.ok, {
   ifid = interface.getId(),
   mac = mac,
   label = mac2label(mac),
   found = (mac_info ~= nil),
   has_packets = (mac_info ~= nil) and ((mac_info["packets.sent"] + mac_info["packets.rcvd"]) > 0),
   has_snmp_location = has_snmp_location,
   has_timeseries = areMacsTimeseriesEnabled(interface.getId()) or serialize_by_mac,
   has_clickhouse = ntop.isClickHouseEnabled(),
   -- The settings: administrators only, not on pcap files
   can_configure = isAdministrator() and not interface.isPcapDumpInterface(),
   is_admin = isAdministrator(),
   -- Refresh of the live charts (packets view), as the old page
   stats_update_freq = interface.getStatsUpdateFreq(interface.getId()),
})
