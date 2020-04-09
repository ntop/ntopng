--
-- (C) 2019-20 - ntop.org
--

local rtt_utils = {}
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"
local json = require("dkjson")

rtt_utils.probe_types = {
   { title = "icmp",   value = "icmp"  },
   { title = "icmp6",  value = "icmp6" },
   { title = "http",   value = "http"  },
   { title = "https",  value = "https" }
}

rtt_utils.granularities = {
   { title = i18n("alerts_thresholds_config.every_minute"),     value = "min"   },
   { title = i18n("alerts_thresholds_config.every_5_minutes"),   value = "5mins" },
   { title = i18n("alerts_thresholds_config.hourly"),    value = "hour"  },
}

-- ##############################################

local rtt_hosts_key = string.format("ntopng.prefs.ifid_%d.system_rtt_hosts_v3", getSystemInterfaceId())

-- ##############################################

local function rtt_last_updates_key(key)
  return string.format("ntopng.cache.ifid_%d.system_rtt_hosts.last_update." .. key, getSystemInterfaceId())
end

-- ##############################################

function rtt_utils.setLastRttUpdate(key, when, rtt, ipaddress)
  ntop.setCache(rtt_last_updates_key(key), string.format("%u@%.2f@%s", when, rtt, ipaddress))
end

-- ##############################################

-- Note: alerts requires a unique key to be used in order to identity the
-- entity. This key is also used internally as a key into the lua tables.
function rtt_utils.getRttHostKey(host, measurement)
  return(string.format("%s@%s", measurement, host))
end

local function key2rtthost(host)
  local parts = string.split(host, "@")

  if(parts and (#parts == 2)) then
    return parts[2], parts[1]
  end
end

-- ##############################################

function rtt_utils.getLastRttUpdate(host, measurement)
  local key = rtt_utils.getRttHostKey(host, measurement)
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

-- Only used for the formatting, don't use as a key as the "/"
-- character is escaped in HTTP parameters
function rtt_utils.formatRttHost(host, measurement)
  return(string.format("%s://%s", measurement, host))
end

-- ##############################################

function rtt_utils.key2host(host_key)
  local host, measurement = key2rtthost(host_key)

  return {
    label = rtt_utils.formatRttHost(host, measurement),
    measurement = measurement,
    host = host,
  }
end

-- ##############################################

local function deserializeRttPrefs(host_key, val, config_only)
  local rv

  if config_only then
    rv = {}
  else
    rv = rtt_utils.key2host(host_key)
  end

  if(tonumber(val) ~= nil) then
    -- Old format is only a number
    rv.max_rtt = tonumber(val)
    rv.granularity = "min"
  else
    -- New format: json
    local v = json.decode(val)

    if v then
      rv.max_rtt = tonumber(v.max_rtt) or 500
      rv.granularity = v.granularity or "min"
    end
  end

  return(rv)
end

local function serializeRttPrefs(val)
  return json.encode(val)
end

-- ##############################################

function rtt_utils.hasHost(host, measurement)
  local host_key = rtt_utils.getRttHostKey(host, measurement)
  local res = ntop.getHashCache(rtt_hosts_key, host_key)

  return(not isEmptyString(res))
end

-- ##############################################

function rtt_utils.getHosts(config_only, granularity)
  local hosts = ntop.getHashAllCache(rtt_hosts_key) or {}
  local rv = {}

  for host_key, val in pairs(hosts) do
    local host = deserializeRttPrefs(host_key, val, config_only)

    if host and ((granularity == nil) or (host.granularity == granularity)) then
      rv[host_key] = host
    end
  end

  return rv
end

-- ##############################################

function rtt_utils.resetConfig()
  local hosts = rtt_utils.getHosts()

  for k,v in pairs(hosts) do
    rtt_utils.deleteHost(v.host, v.measurement)
  end

  ntop.delCache(rtt_hosts_key)
end

-- ##############################################

function rtt_utils.getHost(host, measurement)
  local host_key = rtt_utils.getRttHostKey(host, measurement)
  local val = ntop.getHashCache(rtt_hosts_key, host_key)

  if not isEmptyString(val) then
    return deserializeRttPrefs(host_key, val)
  end
end

-- ##############################################

function rtt_utils.addHost(host, measurement, rtt_value, granularity)
  local host_key = rtt_utils.getRttHostKey(host, measurement)

  ntop.setHashCache(rtt_hosts_key, host_key, serializeRttPrefs({
    max_rtt = tonumber(rtt_value) or 500,
    granularity = granularity or "min",
  }))
end

-- ##############################################

function rtt_utils.deleteHost(host, measurement)
  local ts_utils = require("ts_utils")
  local alerts_api = require("alerts_api")
  require("alert_utils")

  -- NOTE: system interface must be manually sected and then unselected
  local old_iface = tostring(interface.getId())
  interface.select(getSystemInterfaceId())

  local host_key = rtt_utils.getRttHostKey(host, measurement)
  local rtt_host_entity = alerts_api.pingedHostEntity(host_key)
  local old_ifname = ifname

  -- Release any engaged alerts of the host
  alerts_api.releaseEntityAlerts(rtt_host_entity)

  -- Delete the host RRDs
  ts_utils.delete("rtt_host", {ifid=getSystemInterfaceId(), host=host, measure=measurement})

  -- Remove the redis keys of the host
  ntop.delCache(rtt_last_updates_key(host_key))

  ntop.delHashCache(rtt_hosts_key, host_key)

  -- Select the old interface
  interface.select(old_iface)
end

-- ##############################################

return rtt_utils
