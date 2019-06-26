--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isEnterprise() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"

local json = require("dkjson")
local rrd_utils = require "rrd_utils"
local recording_utils = require "recording_utils"

local storage_utils = {}

-- #################################

function storage_utils.interfaceStorageInfo(ifid)
  local info = { total = 0 }
  local key = "ntopng.cache."..ifid..".storage_info"

  local info_json = ntop.getCache(key)

  if not isEmptyString(info_json) then
    info = json.decode(info_json)
  else
    -- if ts_utils.getDriverName() == "rrd" then
      local rrd_storage_info = rrd_utils.storageInfo(ifid)
      info["rrd"] = rrd_storage_info.total
      info["total"] = info["total"] + rrd_storage_info.total
    -- end

    if ntop.isEnterprise() and hasNindexSupport() then
      local nindex_utils = require "nindex_utils"
      local flows_storage_info = nindex_utils.storageInfo(ifid)
      info["flows"] = flows_storage_info.total
      info["total"] = info["total"] + flows_storage_info.total
    end

    -- if recording_utils.isAvailable() then
    if not ntop.isWindows() then
      local pcap_storage_info = recording_utils.storageInfo(ifid)
      local total_pcap_dump_used = (pcap_storage_info.if_used + pcap_storage_info.extraction_used)
      info["pcap"] = total_pcap_dump_used
      if dirs.pcapdir == dirs.workingdir then
        info["total"] = info["total"] + total_pcap_dump_used
      end
    end
    -- end

    ntop.setCache(key, json.encode(info), 60)
  end

  return info
end

-- #################################

function storage_utils.storageInfo()
  local ifnames = interface.getIfNames()
  local info = { total = 0, pcap_total = 0, interfaces = {} }

  for id, name in pairs(ifnames) do
    local ifid = tonumber(id)
    local if_info = storage_utils.interfaceStorageInfo(ifid)
    info.interfaces[ifid] = if_info
    info.total = info.total + if_info.total
    if if_info.pcap ~= nil then
      info.pcap_total = info.pcap_total + if_info.pcap
    end
  end

  local volume_info = recording_utils.volumeInfo(dirs.workingdir)
  info.system       = volume_info.used - info.total
  info.avail        = volume_info.avail
  info.volume_size  = volume_info.total
  info.volume_mount = volume_info.mount
  info.volume_dev   = volume_info.dev

  return info
end

-- #################################

return storage_utils

