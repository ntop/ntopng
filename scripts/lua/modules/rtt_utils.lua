--
-- (C) 2019 - ntop.org
--

local rtt_utils = {}
local ts_utils = require "ts_utils_core"
local format_utils = require "format_utils"

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

function rtt_utils.key2label(key)
  local parts = string.split(key, "@")

  if((parts ~= nil) and (#parts == 3)) then
    -- TODO improve
    return string.format("%s [%s] (%s)", parts[1], parts[2], string.upper(parts[3]))
  end

  return key
end

-- ##############################################

function rtt_utils.deserializeHost(val)
  local parts = string.split(val, "|")

  if((parts ~= nil) and (#parts == 4)) then
    local value = {
      host = parts[1],
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

local function get_rtt_host_table_data(host_key)
   local host_conf = rtt_utils.getHost(host_key)
   if not host_conf then
      return
   end

   local host_rtt = rtt_utils.getLastRttUpdate(host_key)

   local host_chart = ''
   if ts_utils.exists("monitored_host:rtt", {ifid = getSystemInterfaceId(), host = host_key}) then
      host_chart = '<a href="'.. ntop.getHttpPrefix() ..'/lua/system/rtt_stats.lua?rtt_host='.. host_key ..'&page=historical"><i class="fa fa-area-chart fa-lg"></i></a>'
   end

   return {conf = host_conf, rtt = host_rtt, chart = host_chart}
end

-- ##############################################

local function print_host_rtt_table_row(host, i18n_host_label, host_value, host_data)
   print[[
    <tr>
      <th width=10%>]] print(i18n(i18n_host_label)) print[[</th>
      <td width=20%>]] print(host_value) print[[</td>]]

   if not host_data then
      print[[<td colspan=4><i>]] print(i18n("system_stats.no_rtt_configured_for_host", {host = host_value})) print[[.</i>]]
      print[[ <a href="]] print(ntop.getHttpPrefix()) print[[/lua/host_details.lua?]] print(hostinfo2url(host)) print[[&page=config"><i class="fa fa-cog"></i></a>]]
      print[[</td>]]
   else
      local last_val = ''
      local last_update = ''
      if host_data["rtt"] then
	 last_val = format_utils.formatValue(host_data["rtt"]["value"]).." ms"
	 last_update = format_utils.formatPastEpochShort(host_data["rtt"]["when"])
      end

      print[[
      <td style="text-align: center;">]] print(host_data["chart"]) print[[</td>
      <td style="text-align: center;">]] print(formatValue(host_data["conf"]["max_rtt"])) print[[ ms</td>
      <td style="text-align: center;">]] print(last_val) print[[</td>
      <td style="text-align: center;">]] print(last_update) print[[</td>
    </tr>]]
   end
end

-- ##############################################

function rtt_utils.print_host_rtt_table(host)
   local host_ip = host["ip"]
   local host_ip_key = rtt_utils.host2key(host_ip, ternary(isIPv4(host_ip), "ipv4", "ipv6"), "icmp")
   local host_ip_data = get_rtt_host_table_data(host_ip_key)

   local host_name = getResolvedAddress(hostkey2hostinfo(host["ip"]))
   local host_name_key
   local host_name_data

   if host_name ~= host_ip then
      host_name_key = rtt_utils.host2key(host_name, ternary(isIPv4(host_ip), "ipv4", "ipv6"), "icmp")
      host_name_data = get_rtt_host_table_data(host_name_key)
   end

   print[[
<table class="table table-bordered table-striped">
  <thead>
    <tr>
      <th width=10% colspan=2>]] print(i18n("traffic_profiles.host_traffic")) print[[</th>
      <th style="text-align: center;" width=5%>]] print(i18n("chart")) print[[</th>
      <th style="text-align: center;">]] print(i18n("system_stats.max_rtt_no_ms")) print[[</th>
      <th style="text-align: center;">]] print(i18n("system_stats.last_rtt")) print[[</th>
      <th style="text-align: center;">]] print(i18n("category_lists.last_update")) print[[</th>
    </tr>
  </thead>
  <tbody>]]

   print_host_rtt_table_row(host, "ip_address", host_ip, host_ip_data)

   if host_name ~= host_ip and host_name_data then
      print_host_rtt_table_row(host, "name", host_name, host_name_data)
   end

   print[[
  </tbody>
</table>
]]
end

-- ##############################################

return rtt_utils
