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

local rtt_hosts_key = string.format("ntopng.prefs.ifid_%d.system_rtt_hosts", getSystemInterfaceId())

-- ##############################################

local function rtt_last_updates_key(key)
  return string.format("ntopng.cache.ifid_%d.system_rtt_hosts.last_update." .. key, getSystemInterfaceId())
end

-- ##############################################

function rtt_utils.host2key(host, iptype, probetype)
  return table.concat({host, iptype, probetype}, "@")
end

-- ##############################################

function rtt_utils.setLastRttUpdate(key, when, rtt, ipaddress)
  ntop.setCache(rtt_last_updates_key(key), string.format("%u@%.2f@%s", when, rtt, ipaddress))
end

-- ##############################################

function rtt_utils.getLastRttUpdate(key)
  local val = ntop.getCache(rtt_last_updates_key(key))

  if(val ~= nil)then
    local parts = string.split(val, "@")

    if((parts ~= nil) and (#parts == 3)) then
      return {
        when = parts[1],
        value = parts[2],
        ip = parts[3],
      }
    end
  end
end

-- ##############################################

function rtt_utils.probetype2label(probe_type)
  if(probe_type == "icmp") then
    return(i18n("icmp"))
  elseif(probe_type == "http_get") then
    return(i18n("http_s"))
  else
    return(probe_type)
  end
end

-- ##############################################

function rtt_utils.iptype2label(ip_type)
  if(ip_type == "ipv6") then
    return(i18n("ipv6"))
  elseif(ip_type == "ipv4") then
    return(i18n("ipv4"))
  else
    return(ip_type)
  end
end

-- ##############################################

function rtt_utils.key2label(key)
  local parts = string.split(key, "@")

  if((parts ~= nil) and (#parts == 3)) then
    local probe_type = parts[3]
    local iplabel = rtt_utils.iptype2label(parts[2])

    if(probe_type == "icmp") then
      return string.format("%s [%s] (%s)", parts[1], iplabel, i18n("icmp"))
    elseif (probe_type == "http_get") then
      return string.format("%s [%s] (%s)", unescapeHttpHost(parts[1]), iplabel, i18n("http_s"))
    end
  end

  return key
end

-- ##############################################

function rtt_utils.key2host(key)
  local parts = string.split(key, "@")

  if((parts ~= nil) and (#parts == 3)) then
    return {
      host = unescapeHttpHost(parts[1]),
      iptype = parts[2],
      probetype = parts[3],
    }
  end

  return nil
end

-- ##############################################

function rtt_utils.deserializeHost(val)
  local parts = string.split(val, "|")

  if((parts ~= nil) and (#parts == 4)) then
    local value = {
      host = unescapeHttpHost(parts[1]),
      iptype = parts[2], -- ipv4 or ipv6
      probetype = parts[3],
      max_rtt = tonumber(parts[4]),
    }

    return value
  end
end

-- ##############################################

function rtt_utils.getHostsSerialized()
  return ntop.getHashAllCache(rtt_hosts_key) or {}
end

-- ##############################################

function rtt_utils.getHostSerialized(host_key)
   return ntop.getHashCache(rtt_hosts_key, host_key) or {}
end

-- ##############################################

function rtt_utils.getHosts()
  local hosts = rtt_utils.getHostsSerialized()
  local rv = {}

  for host, val in pairs(hosts) do
    rv[host] = rtt_utils.deserializeHost(val)
  end

  return rv
end

-- ##############################################

function rtt_utils.getHost(host_key)
   if not host_key then
      return
   end

   res = rtt_utils.getHostSerialized(host_key)

   if not isEmptyString(res) then
      return rtt_utils.deserializeHost(res)
   end
end

-- ##############################################

function rtt_utils.addHost(host, value)
  ntop.setHashCache(rtt_hosts_key, host, value)
end

-- ##############################################

function rtt_utils.removeHost(host)
  local alerts_api = require("alerts_api")
  local rtt_host_entity = alerts_api.pingedHostEntity(host)
  local old_ifname = ifname

  interface.select(getSystemInterfaceId())
  alerts_api.releaseEntityAlerts(rtt_host_entity)
  interface.select(old_ifname)

  ntop.delHashCache(rtt_hosts_key, host)
end

-- ##############################################

return rtt_utils
