--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isEnterpriseM() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"

local json = require("dkjson")
local rrd_utils = require "rrd_utils"
local recording_utils = require "recording_utils"

local storage_utils = {}

-- #################################

-- Note: if refresh_cache is false, no disk access should be performed
-- @param timeout The maximum time available to call getFolderSize. See getFolderSize for additional comments.
function storage_utils.interfaceStorageInfo(ifid, separate_pcap_volume, refresh_cache, timeout)
  local info = { total = 0 }
  local key = "ntopng.cache."..ifid..".storage_info"

  local info_json = ntop.getCache(key)
  if refresh_cache then

    -- if ts_utils.getDriverName() == "rrd" then
      local rrd_storage_info = rrd_utils.storageInfo(ifid, timeout)
      info["rrd"] = rrd_storage_info.total
      info["total"] = info["total"] + rrd_storage_info.total
    -- end

    if interfaceHasNindexSupport() then
      local nindex_utils = require "nindex_utils"
      local flows_storage_info = nindex_utils.storageInfo(ifid, timeout)
      info["flows"] = flows_storage_info.total
      info["total"] = info["total"] + flows_storage_info.total
    end

    -- if recording_utils.isAvailable() then
    if not ntop.isWindows() then
      local pcap_storage_info = recording_utils.storageInfo(ifid, timeout)
      local total_pcap_dump_used = (pcap_storage_info.if_used + pcap_storage_info.extraction_used)
      info["pcap"] = total_pcap_dump_used
      if separate_pcap_volume then
        info["total"] = info["total"] + total_pcap_dump_used
      end
    end
    -- end

    ntop.setCache(key, json.encode(info))
  elseif not isEmptyString(info_json) then
    info = json.decode(info_json)
  else
    info = nil
  end

  return info
end

-- #################################

-- Note: if refresh_cache is false, no disk access should be performed
--! @param refresh_cache Whether cached values should be refreshed during the call
--! @param timeout The maximum time available to call getFolderSize. See getFolderSize for additional comments.
function storage_utils.storageInfo(refresh_cache, timeout)
  local ifnames = interface.getIfNames()
  local info = { total = 0, pcap_total = 0, interfaces = {} }
  local volume_info
  local pcap_volume_info
  local separate_pcap_volume = false
  local key = "ntopng.cache.system_storage_info"

  if(not refresh_cache) then
    local info_json = ntop.getCache(key)

    if not isEmptyString(info_json) then
      return json.decode(info_json)
    end

    return nil
  end

  volume_info = recording_utils.volumeInfo(dirs.workingdir)

  if dirs.pcapdir ~= dirs.workingdir then
    pcap_volume_info = recording_utils.volumeInfo(dirs.pcapdir)
    if pcap_volume_info.dev ~= volume_info.dev then
      separate_pcap_volume = true
    end
  end

  for id, name in pairs(ifnames) do
    local ifid = tonumber(id)
    local if_info = storage_utils.interfaceStorageInfo(ifid, separate_pcap_volume, refresh_cache, timeout)
    if if_info then
      info.interfaces[ifid] = if_info
      info.total = info.total + if_info.total
      if if_info.pcap ~= nil then
        info.pcap_total = info.pcap_total + if_info.pcap
      end
    end
  end

  info.other       = volume_info.used - info.total
  info.volume_size = volume_info.total
  info.volume_dev  = volume_info.dev

  if separate_pcap_volume then
    pcap_volume_info = recording_utils.volumeInfo(dirs.pcapdir)
    info.pcap_other = pcap_volume_info.used - info.pcap_total
    info.pcap_volume_size = pcap_volume_info.total
    info.pcap_volume_dev  = pcap_volume_info.dev
  end

  -- Note: do not serialize the interfaces data, its already cached
  ntop.setCache(key, json.encode(info))

  return info
end

-- #################################

return storage_utils

