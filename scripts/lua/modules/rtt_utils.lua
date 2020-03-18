--
-- (C) 2019-20 - ntop.org
--

local rtt_utils = {}
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"

rtt_utils.probe_types = {
   { title = "icmp",   value = "icmp"  },
   { title = "icmp6",  value = "icmp6" },
   { title = "http",   value = "http"  },
   { title = "https",  value = "https" }
}

-- ##############################################

local rtt_hosts_key = string.format("ntopng.prefs.ifid_%d.system_rtt_hosts_v2", getSystemInterfaceId())

-- ##############################################

local function rtt_last_updates_key(key)
  return string.format("ntopng.cache.ifid_%d.system_rtt_hosts.last_update." .. key, getSystemInterfaceId())
end

-- ##############################################

function rtt_utils.setLastRttUpdate(key, when, rtt, ipaddress)
  ntop.setCache(rtt_last_updates_key(key), string.format("%u@%.2f@%s", when, rtt, ipaddress))
end

-- ##############################################

function rtt_utils.unescapeRttHost(host)
  -- This is necessary to uneascape http:__ into http:// and similars
  local parts = string.split(host, ":__")

  if(parts and (#parts == 2)) then
    host = string.format("%s://%s", parts[1], parts[2])
  end

  return(host)
end

-- ##############################################

local function rttHostSplitMeasurement(host)
  local parts = string.split(host, ":__")

  if(parts and (#parts == 2)) then
    return parts[1], parts[2]
  end
end

-- ##############################################

function rtt_utils.getLastRttUpdate(key)
  local val = ntop.getCache(rtt_last_updates_key(key))

  if(val ~= nil)then
    local parts = string.split(val, "@")

    if(parts and (#parts == 3)) then
      return {
        when = parts[1],
        value = parts[2],
        ip = parts[3],
      }
    end
  end
end

-- ##############################################

function rtt_utils.key2host(host)
  local measurement, target = rttHostSplitMeasurement(host)

  return {
    key = host,
    label = rtt_utils.unescapeRttHost(host),
    measurement = measurement,
    host = target,
  }
end

-- ##############################################

-- Host (de)serialization functions. For now, only the RTT is saved.
local function deserializeHost(host, val)
  local rv = rtt_utils.key2host(host)

  rv.max_rtt = tonumber(val)

  return(rv)
end

local function serializeHost(host, val)
  return string.format("%u", math.floor(tonumber(val)))
end

-- ##############################################

function rtt_utils.hasHost(host_key)
  local res = ntop.getHashCache(rtt_hosts_key, host_key)

  return(not isEmptyString(res))
end

-- ##############################################

function rtt_utils.getHosts()
  local hosts = ntop.getHashAllCache(rtt_hosts_key) or {}
  local rv = {}

  for host, val in pairs(hosts) do
    rv[host] = deserializeHost(host, val)
  end

  return rv
end

-- ##############################################

function rtt_utils.getHost(host_key)
  local val = ntop.getHashCache(rtt_hosts_key, host_key)

  if not isEmptyString(val) then
    return deserializeHost(host_key, val)
  end
end

-- ##############################################

function rtt_utils.addHost(host, rtt_value)
  ntop.setHashCache(rtt_hosts_key, host, serializeHost(host, rtt_value))
end

-- ##############################################

function rtt_utils.deleteHost(host)
  local alerts_api = require("alerts_api")
  require("alert_utils")
  local rtt_host_entity = alerts_api.pingedHostEntity(host)
  local old_ifname = ifname

  interface.select(getSystemInterfaceId())
  alerts_api.releaseEntityAlerts(rtt_host_entity)
  interface.select(old_ifname)

  ntop.delHashCache(rtt_hosts_key, host)
end

-- ##############################################

return rtt_utils
