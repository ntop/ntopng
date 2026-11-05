--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Save the traffic recording settings of an interface (administrators, n2disk installed, ntopng
-- managing n2disk) and start, restart or stop n2disk. All the fields are sent (a missing toggle
-- is off), with the names of the old form: record_traffic, disk_space (GB), bpf_filter, snaplen
-- (bytes), max_file_size (MB, empty: auto), smart_record_traffic, smart_disk_space (GB,
-- Enterprise XL), custom_name (the external interface) and flow_export (ZMQ collectors).
-- An invalid value answers INVALID_ARGUMENTS with the field name.
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "record_traffic": "1", "disk_space": "10"}' http://localhost:3000/lua/rest/v2/set/interface/recording/config.lua
--

-- http_lint: validates the JSON body (CSRF included) into _POST
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local recording_utils = require "recording_utils"

if not recording_utils.isAvailable() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) or interface.isView() then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local master_ifid = interface.getMasterInterfaceId()
-- Recorded by an external n2disk: nothing to configure here
if recording_utils.getCurrentTrafficRecordingProvider(master_ifid) ~= "ntopng" then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local is_enterprise_xl = (ntop.isEnterpriseXL and ntop.isEnterpriseXL()) or false
local is_zmq = recording_utils.isSupportedZMQInterface(master_ifid)
local on = function(k) return _POST[k] == "1" or _POST[k] == "true" end
local invalid = function(field) rest_utils.answer(rest_utils.consts.err.invalid_args, { field = field }) end

-- Integer in [min, max], or the default when empty
local function int(k, min, max, default)
   local v = _POST[k]
   if isEmptyString(v) then return default, true end
   v = tonumber(v)
   if not v or v ~= math.floor(v) or v < min or (max and v > max) then return nil, false end
   return v, true
end

local record_traffic = on("record_traffic")
local disk_space, ok = int("disk_space", 1, nil, recording_utils.default_disk_space / 1024)
if not ok then return invalid("disk_space") end
local snaplen
snaplen, ok = int("snaplen", 14, 16384, recording_utils.default_snaplen)
if not ok then return invalid("snaplen") end
local max_file_size
max_file_size, ok = int("max_file_size", 1, nil, nil)
if not ok then return invalid("max_file_size") end

-- Written as an n2disk option line: no control characters (a newline would add options)
local bpf_filter = _POST["bpf_filter"] or ""
if bpf_filter:find("%c") or (bpf_filter ~= "" and not ntop.checkFilterSyntax(bpf_filter)) then
   return invalid("bpf_filter")
end

local smart_record_traffic, smart_disk_space = false, nil
if is_enterprise_xl then
   smart_record_traffic = record_traffic and on("smart_record_traffic")
   smart_disk_space, ok = int("smart_disk_space", 1, nil, recording_utils.default_disk_space / 1024)
   if not ok then return invalid("smart_disk_space") end
end

local ext_ifname, flow_export = nil, false
if is_zmq then
   local name = _POST["custom_name"]
   if not isEmptyString(name) then
      if not recording_utils.getExtInterfaces(master_ifid, true)[name] then return invalid("custom_name") end
      ext_ifname = name
   end
   flow_export = on("flow_export")
end

-- Store the settings (MB on disk, as the old page)
local prefix = "ntopng.prefs.ifid_" .. master_ifid
local function set_or_del(k, cond, v)
   if cond then ntop.setCache(prefix .. k, v) else ntop.delCache(prefix .. k) end
end

set_or_del(".traffic_recording.enabled", record_traffic, "1")
ntop.setCache(prefix .. ".traffic_recording.bpf_filter", bpf_filter)
ntop.setCache(prefix .. ".traffic_recording.snaplen", tostring(snaplen))
ntop.setCache(prefix .. ".traffic_recording.disk_space", tostring(disk_space * 1024))
set_or_del(".traffic_recording.max_file_size", max_file_size ~= nil, tostring(max_file_size))

if is_enterprise_xl then
   set_or_del(".smart_traffic_recording.enabled", smart_record_traffic, "1")
   set_or_del(".smart_traffic_recording.instance", smart_record_traffic, recording_utils.getN2diskInstanceName(master_ifid))
   interface.updateSmartRecording()
   ntop.setCache(prefix .. ".smart_traffic_recording.disk_space", tostring(smart_disk_space * 1024))
end

if is_zmq then
   if ext_ifname then ntop.setCache(prefix .. ".traffic_recording.ext_ifname", ext_ifname) end
   set_or_del(".traffic_recording_flow_export.enabled", flow_export, "1")
end

-- Configure and (re)start n2disk, or stop it
local started = false
if record_traffic then
   local config = {
      snaplen = snaplen,
      max_disk_space = disk_space * 1024,
      bpf_filter = bpf_filter,
      max_file_size = max_file_size,
   }
   if smart_record_traffic then
      config.enable_smart_recording = true
      config.max_smart_disk_space = smart_disk_space * 1024
   end
   if is_zmq and flow_export then
      config.zmq_endpoint = recording_utils.getZMQProbeAddr(master_ifid)
      recording_utils.stop(master_ifid) -- the interface may have changed
   end
   if recording_utils.createConfig(master_ifid, config) then
      recording_utils.restart(master_ifid, config)
      started = true
   end
else
   recording_utils.stop(master_ifid)
end

rest_utils.answer(rest_utils.consts.success.ok, { enabled = record_traffic, started = started })
