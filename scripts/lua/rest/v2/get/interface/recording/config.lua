--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Traffic recording (n2disk) of an interface (administrators, n2disk installed): what can be
-- done here and the settings, as shown by Interface details > Traffic Recording.
-- Sizes in bytes, disk spaces in GB (as the form), max_file_size in MB.
-- Saved by rest/v2/set/interface/recording/config.lua.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/interface/recording/config.lua?ifid=0"
--

-- No lua_utils: http_lint validates _GET, recording_utils loads what it needs
require "http_lint"
require "ntop_utils"
require "label_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"

-- isAvailable(): administrator and n2disk installed
if not recording_utils.isAvailable() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
ifid = interface.getId()

local is_view = interface.isView()
local master_ifid = interface.getMasterInterfaceId()
local provider = recording_utils.getCurrentTrafficRecordingProvider(master_ifid)
local is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false
local is_enterprise_xl = (ntop.isEnterpriseXL and ntop.isEnterpriseXL()) or false

local res = {
   ifid = ifid,
   is_view = is_view,
   provider = provider,
   -- The settings only when ntopng manages n2disk (else it is configured by hand)
   managed = (provider == "ntopng") and not is_view,
   enabled = recording_utils.isEnabled(master_ifid),
   jobs_available = is_enterprise_m,
   smart_available = is_enterprise_xl,
   -- Extracted PCAPs are split at this size (MB): the jobs download dialog says it
   -- The notes name the product (its configuration file sets the storage directory)
   product = ntop.getInfo().product,
   max_pcap_mb = math.floor((ntop.getPrefs().max_extracted_pcap_bytes or 0) / (1024 * 1024)),
}

if is_view then
   -- A view records nothing: the traffic of its viewed interfaces with recording is extracted
   local viewed = {}
   for _, iface in ipairs(recording_utils.getViewedInterfacesWithRecording(ifid)) do
      viewed[#viewed + 1] = { ifid = iface.ifid, name = getHumanReadableInterfaceName(iface.ifname) }
   end
   res.viewed_interfaces = viewed
   rest_utils.answer(rest_utils.consts.success.ok, res)
   return
end

res.reminder = not recording_utils.isExternalProvidersReminderDismissed(ifid)

if res.managed then
   local prefix = "ntopng.prefs.ifid_" .. master_ifid
   local get = function(k) return ntop.getCache(prefix .. k) end

   local storage = recording_utils.storageInfo(master_ifid)
   -- Suggested max disk space (MB, whole GB), as the old page
   local max_space = math.floor(recording_utils.recommendedSpace(master_ifid, storage) / (1024 * 1024 * 1024)) * 1024

   local disk_space = get(".traffic_recording.disk_space")
   local smart_disk_space = get(".smart_traffic_recording.disk_space")
   -- Not set yet: the suggested space (split with the smart recording when available)
   if is_enterprise_xl then
      if isEmptyString(disk_space) and isEmptyString(smart_disk_space) then
         disk_space, smart_disk_space = max_space / 2, max_space / 2
      elseif isEmptyString(disk_space) then
         disk_space = math.max(max_space - tonumber(smart_disk_space), 0)
      elseif isEmptyString(smart_disk_space) then
         smart_disk_space = math.max(max_space - tonumber(disk_space), 0)
      end
   elseif isEmptyString(disk_space) then
      disk_space = max_space
   end

   local snaplen = get(".traffic_recording.snaplen")
   local max_file_size = get(".traffic_recording.max_file_size")

   res.settings = {
      smart_enabled = is_enterprise_xl and get(".smart_traffic_recording.enabled") == "1",
      disk_space = math.floor(tonumber(disk_space) / 1024),
      smart_disk_space = is_enterprise_xl and math.floor(tonumber(smart_disk_space) / 1024) or nil,
      max_space = math.max(max_space / 1024, 1),
      bpf_filter = get(".traffic_recording.bpf_filter"),
      snaplen = tonumber(snaplen) or recording_utils.default_snaplen,
      -- Customized advanced settings: shown open
      advanced_customized = not isEmptyString(snaplen) or not isEmptyString(max_file_size),
      max_file_size = tonumber(max_file_size),
      max_file_size_auto = recording_utils.getDefaultMaxFileSize(master_ifid),
      pcap_path = recording_utils.getPcapPath(master_ifid),
      smart_pcap_path = is_enterprise_xl and recording_utils.getSmartPcapPath(master_ifid) or nil,
   }

   -- ZMQ collector: n2disk records an external interface, optionally exporting its flows here
   if recording_utils.isSupportedZMQInterface(master_ifid) then
      local ext_ifname = get(".traffic_recording.ext_ifname")
      local ext = {}
      for name, info in pairs(recording_utils.getExtInterfaces(master_ifid, true)) do
         ext[#ext + 1] = { name = name, label = info.ifdesc }
      end
      table.sort(ext, function(a, b) return a.name < b.name end)
      if isEmptyString(ext_ifname) and ext[1] then ext_ifname = ext[1].name end
      res.settings.ext_interfaces = ext
      res.settings.ext_ifname = ext_ifname
      res.settings.flow_export = get(".traffic_recording_flow_export.enabled") == "1"
   end

   res.storage = {
      total = storage.total,
      avail = storage.avail,
      system_used = math.max(storage.total - storage.avail - storage.if_used - storage.extraction_used, 0),
      if_used = storage.if_used,
      extraction_used = storage.extraction_used,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
