--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Context of the interface details SPA page (if_stats.lua, router.js): the interface name
-- and the facts that decide which views (tabs) are available, as the old if_stats.lua
-- computed them. Only raw values: the page builds labels and reasons.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/interface/page_context.lua?ifid=0"
--

-- No lua_utils (hundreds of ms to load): http_lint validates _GET, the helpers come
-- from check_redis_prefs (timeseries/alerts prefs), label_utils (name), recording_utils
require "http_lint"
require "ntop_utils"
require "check_redis_prefs"
require "label_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"
local auth = require "auth"

-- Same access as if_stats.lua: any user, on the interfaces they are allowed to see
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(ifid)
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end
ifid = interface.getId()

local ifstats = interface.getStats()
local is_nedge = ntop.isnEdge and ntop.isnEdge() or false
local is_packet = interface.isPacketInterface()
local is_pcap_dump = interface.isPcapDumpInterface()
local is_view = interface.isView()
local is_light_view = isLightView()

-- As if_stats.lua: refreshed on every page load, n2disk may have been installed meanwhile
recording_utils.checkAvailable()
local recording_available = recording_utils.isAvailable()
local has_recording = false
if recording_available and not is_light_view then
   if is_view then
      has_recording = next(recording_utils.getViewedInterfacesWithRecording(ifid)) ~= nil
   else
      has_recording = is_packet
         or (recording_utils.isSupportedZMQInterface(ifid) and next(recording_utils.getExtInterfaces(ifid)) ~= nil)
         or (recording_utils.getCurrentTrafficRecordingProvider(ifid) ~= "ntopng")
   end
end

local stats = ifstats.stats or {}
local driver = ntop.getPref("ntopng.prefs.timeseries_driver")
local behaviour = interface.isBehaviourAnalysisAvailable()
local top_sites_pref = ntop.getPref("ntopng.prefs.host_top_sites_creation")

rest_utils.answer(rest_utils.consts.success.ok, {
   ifid = ifid,
   name = getHumanReadableInterfaceName(getInterfaceName(ifid)),
   is_pro = (ntop.isPro and ntop.isPro()) or false,
   is_nedge = is_nedge,
   is_packet_interface = is_packet,
   is_pcap_dump = is_pcap_dump,
   is_zmq = interface.isZMQInterface(),
   is_view = is_view,
   is_sub_interface = interface.isSubInterface(),
   is_syslog = ifstats.isSyslog or false,
   is_light_view = is_light_view,
   is_asn_mode = isASNModeEnabled(),
   has_macs = ifstats.has_macs or false,
   has_packets = (stats.packets or 0) > 0,
   has_profiles = next(ifstats.profiles or {}) ~= nil,
   -- The sites are collected only with the "Top Sites" preference
   top_sites_enabled = top_sites_pref ~= "" and top_sites_pref ~= "0",
   timeseries_enabled = areInterfaceTimeseriesEnabled(ifid),
   l7_timeseries_enabled = areInterfaceL7TimeseriesEnabled(ifid),
   categories_timeseries_enabled = areInterfaceCategoriesTimeseriesEnabled(ifid),
   iface_ts_id = getIfacenDPITsName(),
   has_recording = has_recording,
   recording_available = recording_available,
   alerts_enabled = areAlertsEnabled() and auth.has_capability(auth.capabilities.alerts),
   -- As hasTrafficReport(): RRD timeseries, Enterprise M, not a pcap file
   has_traffic_report = (not is_pcap_dump) and (driver == "" or driver == "rrd")
      and (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false,
   is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false,
   service_map_available = behaviour,
   periodicity_map_available = behaviour,
   uptime = ntop.getUptime(),
})
