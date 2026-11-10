--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Static part of the interface Overview (page-interface-overview.vue): identity,
-- configuration, flow export backends, traffic recording and storage. The live counters
-- come from rest/v2/get/interface/data.lua. Only raw values: the page builds the labels.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/interface/overview.lua?ifid=0"
--

-- No lua_utils (hundreds of ms to load): http_lint validates _GET
require "http_lint"
require "ntop_utils"
require "check_redis_prefs"
require "label_utils"
local rest_utils = require "rest_utils"
local json = require "dkjson"

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

local is_admin = isAdministrator()

-- The engaged/dropped alerts counters are not scoped to the allowed networks of the user
local nets = ntop.getAllowedNetworks() or ""
local has_allowed_networks = false
for net in nets:gmatch("[^,]+") do
   if net ~= "0.0.0.0/0" and net ~= "::/0" then has_allowed_networks = true break end
end
local is_light_view = isLightView()
local prefs = ntop.getPrefs()

-- Flow export backends (counters in data.lua / lightview/data.lua under the same id)
local function export_backends()
   local exports = {}
   if ntop.isClickHouseEnabled() then exports[#exports + 1] = { id = "db", label = "ClickHouse" } end
   if prefs.is_dump_flows_to_es_enabled then exports[#exports + 1] = { id = "es", label = "ElasticSearch" } end
   if prefs.is_dump_flows_to_kafka_enabled then exports[#exports + 1] = { id = "kafka", label = "Kafka" } end
   if prefs.is_dump_flows_to_syslog_enabled then exports[#exports + 1] = { id = "syslog", label = "Syslog" } end
   return exports
end
local dedup_enabled = ntop.isFlowDedupEnabled() and (ntop.isEnterpriseXL and ntop.isEnterpriseXL()) or false
local nprobe_page = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false

-- All the interfaces together: the page reads the counters from lightview/data.lua
-- (also db_stats, has_traffic_directions, num_probes: none of the properties below belongs to one interface)
if is_light_view then
   rest_utils.answer(rest_utils.consts.success.ok, {
      is_light_view = true,
      can_reset = is_admin,
      -- Alwais disabled
      show_alerts = false, -- not has_allowed_networks,
      timeseries_enabled = areInterfaceTimeseriesEnabled(ifid),
      exports = export_backends(),
      export_enabled = prefs.is_dump_flows_runtime_enabled or false,
      dedup_enabled = dedup_enabled,
      nprobe_page = nprobe_page,
   })
   return
end

local ifstats = interface.getStats()
local exports = ifstats.isViewed and {} or export_backends()
local is_view = interface.isView()
local is_packet = interface.isPacketInterface()
local is_pcap_dump = interface.isPcapDumpInterface()
local is_sub_interface = interface.isSubInterface()

-- Remote probes (nProbe) sending flows: of this interface or, for a view, of its viewed ones
local probes = {}
local function add_probes(stats)
   for _, list in pairs(stats.probes or {}) do
      for k, _ in pairs(list or {}) do probes[k] = true end
   end
end
if is_view then
   for id, _ in pairs(interface.getIfNames() or {}) do
      interface.select(id)
      if interface.viewedBy() == ifid then add_probes(interface.getStats()) end
   end
   interface.select(tostring(ifid))
else
   add_probes(ifstats)
end
local num_probes = 0
for _ in pairs(probes) do num_probes = num_probes + 1 end

-- Speed in Mbit/s: the one set in the interface settings, else the detected one
local speed = tonumber(ntop.getCache("ntopng.prefs.ifid_" .. ifid .. ".speed")) or ifstats.speed


-- Administrators: traffic recording windows and disk usage (cached, no disk access here)
local recording, storage = nil, nil
if is_admin and not is_view then
   local recording_utils = require "recording_utils"
   if recording_utils.isAvailable() then
      local s = recording_utils.stats(ifid) or {}
      local smart = recording_utils.smartStats(ifid) or {}
      recording = {
         first_epoch = s["FirstDumpedEpoch"], last_epoch = s["LastDumpedEpoch"], start_epoch = s["StartEpoch"],
         smart_first_epoch = smart["FirstDumpedEpoch"], smart_last_epoch = smart["LastDumpedEpoch"],
      }
   end
   local storage_utils = require "storage_utils"
   local info = storage_utils.interfaceStorageInfo(ifid)
   if info then
      local driver = ntop.getPref("ntopng.prefs.timeseries_driver")
      storage = {
         total = info.total,
         rrd = (driver == "" or driver == "rrd") and info.rrd or nil,
         flows = info.flows,
         pcap = info.pcap,
      }
   end
end

-- Additional counters of a syslog source (e.g. Suricata), as stored by its parser
local external_stats = nil
if ifstats.isSyslog then
   local s = ntop.getCache("ntopng.prefs.ifid_" .. ifid .. ".external_stats")
   if not isEmptyString(s) then external_stats = json.decode(s) end
end


local encryption_key = is_admin and ifstats.encryption and ifstats.encryption.public_key or nil

rest_utils.answer(rest_utils.consts.success.ok, {
   ifid = ifid,
   name = ifstats.name,
   label = getHumanReadableInterfaceName(ifstats.name),
   description = (ifstats.description ~= ifstats.name) and ifstats.description or nil,
   mac = (ifstats.mac and ifstats.mac ~= "00:00:00:00:00:00") and ifstats.mac or nil,
   type = ifstats.type,
   inline = ifstats.inline or false,
   has_traffic_directions = ifstats.has_traffic_directions or false,
   -- MTU and speed only belong to a physical interface
   mtu = (is_packet and not is_pcap_dump and not is_view) and ifstats.mtu or nil,
   speed_mbps = (is_packet and not is_pcap_dump and not is_view) and speed or nil,
   is_view = is_view,
   is_sub_interface = is_sub_interface,
   is_packet_interface = is_packet,
   is_pcap_dump = is_pcap_dump,
   is_syslog = ifstats.isSyslog or false,
   is_netfilter = ifstats.type == "netfilter",
   is_paused = interface.isIdle(),
   can_pause = is_admin and not is_pcap_dump and ifstats.type ~= "netfilter",
   can_reset = is_admin,
   can_live_capture = ntop.isPcapDownloadAllowed() and not is_view and not is_sub_interface and is_packet,
   num_probes = num_probes,
   nprobe_page = nprobe_page,
   show_alerts = not has_allowed_networks,
   timeseries_enabled = areInterfaceTimeseriesEnabled(ifid),
   has_role_traffic = ifstats.iface_role_traffic ~= nil,
   has_flow_collection = ifstats.zmqRecvStats ~= nil and next(ifstats.zmqRecvStats) ~= nil,
   db_stats = ifstats.dbStats,
   dedup_enabled = dedup_enabled,
   exports = exports,
   export_enabled = prefs.is_dump_flows_runtime_enabled or false,
   export_direct = (not is_packet) and (prefs.is_dump_flows_direct_enabled or false) or nil,
   zmq_encryption_key = encryption_key,
   recording = recording,
   storage = storage,
   external_stats = external_stats,
   -- Service and periodicity maps (Enterprise): not in ASN mode (the periodicity one)
   maps_available = interface.isBehaviourAnalysisAvailable(),
   is_asn_mode = isASNModeEnabled(),
})
