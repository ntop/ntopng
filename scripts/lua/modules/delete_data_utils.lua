--
-- (C) 2014-20 - ntop.org
--
local dirs = ntop.getDirs()

require("lua_utils")
local ts_utils = require("ts_utils")
local os_utils = require("os_utils")
local tracker = require "tracker"

local delete_data_utils = {}
local dry_run = false

local ALL_INTERFACES_HASH_KEYS         = "ntopng.prefs.iface_id"
local ACTIVE_INTERFACES_DELETE_HASH    = "ntopng.prefs.delete_active_interfaces_data"
local PCAP_DUMP_INTERFACES_DELETE_HASH = "ntopng.prefs.delete_pcap_dump_interfaces_data"

-- ################################################################

function delete_data_utils.status_to_i18n(err)
   local map = {
      ERR_NO_HOST_FS_DATA = "delete_data.msg_err_no_fs_data",
      ERR_INVALID_HOST = "delete_data.msg_err_invalid_host",
      ERR_TS_DELETE = "delete_data.msg_err_unable_to_delete_ts_data",
      ERR_UNABLE_TO_DELETE_DIR = "delete_data.msg_err_unable_to_delete_dir",
   }

   return map[err] or 'delete_data.msg_err_unknown'
end

-- ################################################################

local function delete_host_timeseries_data(interface_id, host_info)
   local status = "OK"
   local is_mac = isMacAddress(host_info["host"])

   if not is_mac and not isIPv4(host_info["host"]) and not isIPv6(host_info["host"]) then
      status = "ERR_INVALID_HOST"
   else
      local to_delete
      local delete_tags
      local value = hostinfo2hostkey(host_info)

      if is_mac then
	 to_delete = "mac"
	 delete_tags = {ifid=interface_id, mac=value}
      else
	 to_delete = "host"
	 delete_tags = {ifid=interface_id, host=value}
      end

      if not dry_run then
	 if not ts_utils.delete(to_delete, delete_tags) then
	    status = "ERR_TS_DELETE"
	 end
      end
   end

   return {status = status}
end

-- ################################################################

-- TODO delete HOST_V4_BY_MAC_SERIALIZED_KEY and HOST_V6_BY_MAC_SERIALIZED_KEY as well
local function delete_host_redis_keys(interface_id, host_info)
   local status = "OK"
   local hostkey = hostinfo2hostkey(host_info, nil, true)
   local serialized_k, dns_k, devnames_k, devtypes_k, drop_k, label_k, dhcp_k

   if not isMacAddress(host_info["host"]) then
      -- this is an IP address, see HOST_SERIALIZED_KEY (ntop_defines.h)
      serialized_k = string.format("ntopng.serialized_hosts.ifid_%d__%s@%d", interface_id, host_info["host"], host_info["vlan"] or "0")
      dns_k = string.format("ntopng.dns.cache.%s", host_info["host"]) -- neither vlan nor ifid implemented for the dns cache
      drop_k = "ntopng.prefs.drop_host_traffic"
      label_k = "ntopng.host_labels"
   else
      -- is a mac address, see MAC_SERIALIED_KEY (see ntop_defines.h)
      serialized_k = string.format("ntopng.serialized_macs.ifid_%d__%s", interface_id, host_info["host"])
      devnames_k = string.format("ntopng.cache.devnames.%s", host_info["host"])
      devtypes_k = string.format("ntopng.prefs.device_types.%s", host_info["host"])
      dhcp_k = getDhcpNamesKey(interface_id)
   end

   if not dry_run then
      if serialized_k then ntop.delCache(serialized_k) end
      if devnames_k   then ntop.delCache(devnames_k) end
      if devtypes_k   then ntop.delCache(devtypes_k) end
      if dns_k        then ntop.delCache(dns_k) end
      if dhcp_k       then ntop.delHashCache(dhcp_k, host_info["host"]) end
      if drop_k       then ntop.delHashCache(drop_k, hostkey) end
      if label_k      then ntop.delHashCache(label_k, hostkey) end
   end

   return {status = status}
end

-- ################################################################

local function delete_host_mysql_flows(interface_id, host_info)
   local status = "OK"

   if ntop.getPrefs()["is_dump_flows_to_mysql_enabled"] then
      local addr = host_info["host"]
      local vlan = host_info["vlan"] or 0
      local q

      if isIPv4(addr) then
	 q = string.format("DELETE FROM %s WHERE (IP_SRC_ADDR = INET_ATON('%s') OR IP_DST_ADDR = INET_ATON('%s')) AND VLAN_ID = %u and INTERFACE_ID = %d",
			   "flowsv4", addr, addr, vlan, interface_id)
      elseif isIPv6(addr) then
	 q = string.format("DELETE FROM %s WHERE (IP_SRC_ADDR = '%s' OR IP_DST_ADDR = '%s') AND VLAN_ID = %u AND INTERFACE_ID = %d",
			   "flowsv6", addr, addr, vlan, interface_id)
      end

      if not dry_run and q then
	 interface.execSQLQuery(q)
      end
   end

   return {status = status}
end

-- ################################################################

local function _delete_host(interface_id, host_info)
   local old_ifname = interface.getStats().name
   local is_mac = isMacAddress(host_info["host"])
   interface.select(getInterfaceName(interface_id))

   if is_mac then
      interface.deleteMacData(host_info["host"])
   else
      interface.deleteHostData(hostinfo2hostkey(host_info))
   end

   local h_ts = delete_host_timeseries_data(interface_id, host_info)
   local h_rk = delete_host_redis_keys(interface_id, host_info)
   local h_db = delete_host_mysql_flows(interface_id, host_info)

   interface.select(old_ifname)
   return {delete_host_timeseries_data = h_ts, delete_host_redis_keys = h_rk, delete_host_mysql_flows = h_db}
end

-- ################################################################

function delete_data_utils.delete_host(interface_id, host_info)
   -- TRACKER HOOK
   tracker.log('delete_host', { hostinfo2hostkey(host_info) })

   return _delete_host(interface_id, host_info)
end

-- ################################################################

function delete_data_utils.delete_network(interface_id, netaddr, mask, vlan)
   mask = tonumber(mask)

   -- TRACKER HOOK
   tracker.log('delete_network', { hostinfo2hostkey({host=netaddr.."/"..mask, vlan=vlan}) })

   if not isIPv4(netaddr) then
      return {delete_network = {status = "ERR_INVALID_IPV4_NETWORK"}}
   end

   if (mask < 24) or (mask > 32) then
      return {delete_network = {status = "ERR_NETWORK_TOO_BIG"}}
   end

   local prefix = ntop.networkPrefix(netaddr, tonumber(mask))
   local parts = string.split(prefix, "%.")
   local start = tonumber(parts[4])

   local size = 1 << (32-mask)

   for i=0,size-1 do
      parts[4] = tostring(start + i)

      local ip = table.concat(parts, ".")
      local status = _delete_host(interface_id, {host=ip, vlan=vlan})

      for what, what_res in pairs(status) do
	 if what_res["status"] ~= "OK" then
	    return status
	 end
      end
   end

   -- Delete network ts data
   if not ts_utils.delete("subnet", {ifid=interface_id, subnet=prefix.."/"..mask}) then
      return {delete_network_timeseries = {status = "ERR_TS_DELETE"}}
   end

   return {delete_network = {status = "OK"}}
end

-- ################################################################

local function delete_keys_patterns(keys_patterns, preserve_prefs)
  for _, pattern in pairs(keys_patterns) do
    local matching_keys = ntop.getKeysCache(pattern)

    for matching_key, _ in pairs(matching_keys or {}) do
	    if((not preserve_prefs) or
		  ((not starts(matching_key, "ntopng.prefs.")) and
		   (not starts(matching_key, "ntopng.user.")))) then
	       if not dry_run then
		  ntop.delCache(matching_key)
	       end
	    end
	 end
  end
end

-- ################################################################

local function delete_system_interface_redis(preserve_prefs)
  local keys_patterns = {
    "ntopng.prefs.snmp_devices*",
    "ntopng.prefs.system_rtt_hosts*",
    "cachedsnmp*",
  }

  delete_keys_patterns(keys_patterns, preserve_prefs)
end

-- ################################################################

local function delete_interfaces_redis_keys(interfaces_list, preserve_prefs)
   local pref_prefix = "ntopng.prefs"
   local status = "OK"

   for if_id, if_name in pairs(interfaces_list) do
      -- let's match some patterns here (don't write an hexahustive list of keys
      -- as it will become unmanageable)

      local keys_patterns = {
	 -- examples:
	 --  ntopng.prefs.0.host_pools.pool_ids
	 --  ntopng.prefs.0.host_pools.details.0
	 string.format("%s.%d.*", pref_prefix, if_id),
	 -- examples:
	 --  ntopng.profiles_counters.ifid_0
	 --  ntopng.serialized_host_pools.ifid_0
	 string.format("ntopng.*ifid_%d", if_id),
	 -- examples:
	 --  ntopng.serialized_macs.ifid_0__52:54:00:3B:CB:B3
	 --  ntopng.serialized_hosts.ifid_0__192.168.2.131@0
	 string.format("*.ifid_%d_*", if_id),
	 -- examples:
	 --  ntopng.cache.engaged_alerts_cache_ifid_4_5mins
	 --  ntopng.cache.engaged_alerts_cache_ifid_4_min
	 string.format("ntopng.*_ifid_%d_*", if_id),
	 -- examples:
	 -- ntopng.prefs.ifid_0.custom_nDPI_proto_categories
	 -- ntopng.prefs.ifid_0.is_traffic_mirrored
	 string.format("*.ifid_%d.*", if_id),
	 -- examples:
	 --  ntopng.prefs.iface_2.packet_drops_alert
	 --  ntopng.prefs.iface_3.scaling_factor
	 string.format("%s.iface_%d.*", pref_prefix, if_id),
	 -- examples:
	 --  ntopng.prefs.enp1s0f0.xxx
	 string.format("%s.%s.*", pref_prefix, if_name),
	 -- examples:
	 --  ntopng.prefs.enp2s0f0_not_idle
	 string.format("%s.%s_*", pref_prefix, if_name),
      }

      delete_keys_patterns(keys_patterns, preserve_prefs)

      if(if_id == getSystemInterfaceId()) then
        delete_system_interface_redis(preserve_prefs)
      end
   end

   return {status = status}
end

-- ################################################################

local function delete_interfaces_data(interfaces_list)
   local status = "OK"
   local data_dir = ntop.getDirs()["workingdir"]

   for if_id, if_name in pairs(interfaces_list) do
      local if_dir = os_utils.fixPath(string.format("%s/%d/", data_dir, if_id))

      if not dry_run then
	 if not ts_utils.delete("" --[[ all schemas ]], {ifid=if_id}) then
	    status = "ERR_TS_DELETE"
	    break
	 end

	 -- Delete additional data
	 if ntop.exists(if_dir) and not ntop.rmdir(if_dir) then
	    status = "ERR_UNABLE_TO_DELETE_DIR"
	    break
	 end
      end
   end

   return {status = status}
end

-- ################################################################

local function delete_interfaces_db_flows(interfaces_list)
   local db_utils = require "db_utils"
   local status = "OK"
   local prefs = ntop.getPrefs()

   for if_id, if_name in pairs(interfaces_list) do
      -- this deletes MySQL
      if prefs.is_dump_flows_to_mysql_enabled == true and not dry_run then
	 db_utils.harverstExpiredMySQLFlows(if_id, os.time() + 86400 --[[ go 1d in the future to make sure everything is deleted --]])
      end
      -- TODO: add delete for nIndex
   end

   return {status = status}
end

-- ################################################################

local function delete_interfaces_ids(interfaces_list)
   local status = "OK"

   for if_id, if_name in pairs(interfaces_list) do
      -- delete the interface from the all interfaces hash
      -- this will cause the id to be re-used
      if not dry_run then
	 ntop.delHashCache(ALL_INTERFACES_HASH_KEYS, if_name)
	 ntop.delHashCache(ALL_INTERFACES_HASH_KEYS, if_id)
      end
   end

   return {status = status}
end

-- ################################################################

local function list_interfaces(inactive_interfaces_only)
   local res = {}
   local active_interfaces = interface.getIfNames()
   local all_interfaces = ntop.getHashAllCache(ALL_INTERFACES_HASH_KEYS)

   for k, v in pairs(all_interfaces) do
      if tonumber(k) ~= nil then
	 -- assumes this in an interface integer id
	 -- this check is necessary as function Utils::ifname2id
	 -- inserts in the same hash table both the ids and the interface
	 -- names. So for example interface eno1 with id 20 has two entries in the
	 -- hash table, namely eno1: 20 and 20: eno1
	 goto continue
      end

      local if_name = k
      local if_id = v

      if inactive_interfaces_only and active_interfaces[if_id] then
	 -- the interface is active
	 goto continue
      end

      -- add the interface to the list of inactive interfaces
      res[if_id] = if_name
      ::continue::
   end

   return res
end

-- ################################################################

function delete_data_utils.list_inactive_interfaces()
   return list_interfaces(true --[[ inactive interfaces only --]])
end

-- ################################################################

function delete_data_utils.list_all_interfaces()
   return list_interfaces(false --[[ all interfaces, active and inactive --]])
end

-- ################################################################

local function delete_interfaces_from_list(interfaces_list, preserve_interface_ids, preserve_redis_keys)
   local if_dt = delete_interfaces_data(interfaces_list)
   local if_db = delete_interfaces_db_flows(interfaces_list)
   local preserve_prefs = ternary(ntop.isnEdge(), true, false)

   local if_rk
   if not preserve_redis_keys then
      if_rk = delete_interfaces_redis_keys(interfaces_list, preserve_prefs)
   end

   -- last step is to also free the ids that can thus be recycled
   -- if everything was OK.
   local if_in
   if not preserve_interface_ids then
      if not preserve_redis_keys or if_rk["status"] == "OK" then
	 if if_dt["status"] == "OK" then
	    if if_db["status"] == "OK" then
	       if_in = delete_interfaces_ids(interfaces_list)
	    end
	 end
      end
   end

   local res = {delete_if_data = if_dt, delete_if_redis_keys = if_rk, delete_if_db = if_db, delete_if_ids = if_in}

   for op, op_res in pairs(res or {}) do
      local trace_level = TRACE_NORMAL
      local status = op_res["status"]

      if status ~= "OK" then
	 trace_level = TRACE_ERROR
      end

      traceError(trace_level, TRACE_CONSOLE, string.format("Deleting data [%s][%s]", op, status))
   end

   return res
end

-- ################################################################

function delete_data_utils.delete_all_interfaces_data()
   -- Deleting all interfaces can be a risky operation as it includes active interfaces.
   -- Currently we are using this only in boot.lua (that is, before interfaces registration)
   -- and only in nEdge. Use it carefully.

   if not ntop.isnEdge() then
      return
   end

   local if_list = delete_data_utils.list_all_interfaces()

   return delete_interfaces_from_list(if_list)
end

-- ################################################################

function delete_data_utils.delete_active_interfaces_data()
   local if_list = ntop.getHashAllCache(ACTIVE_INTERFACES_DELETE_HASH)

   return delete_interfaces_from_list(if_list, true --[[ preserve ids --]])
end

-- ################################################################

function delete_data_utils.request_delete_active_interface_data(if_id)
   local if_name = getInterfaceName(if_id)
   ntop.setHashCache(ACTIVE_INTERFACES_DELETE_HASH, tostring(if_id), if_name)
end

-- ################################################################

function delete_data_utils.clear_request_delete_active_interface_data()
   ntop.delCache(ACTIVE_INTERFACES_DELETE_HASH)
end

-- ################################################################

function delete_data_utils.delete_active_interface_data_requested(if_name)
   if not isEmptyString(if_name) then
      -- Check if a delete has been requested for a particular interface
      local if_id = getInterfaceId(if_name)
      if tonumber(if_id) >= -1 then
         local req = ntop.getHashCache(ACTIVE_INTERFACES_DELETE_HASH, tostring(if_id))
         if not isEmptyString(req) then
            return true
         end
      end
   else
      -- Check if there's at least a data delete request
      return (ntop.getHashAllCache(ACTIVE_INTERFACES_DELETE_HASH) ~= nil)
   end

   return false
end

-- ################################################################

function delete_data_utils.delete_pcap_dump_interfaces_data()
   local if_list = ntop.getHashAllCache(PCAP_DUMP_INTERFACES_DELETE_HASH)
   local res = {}

   if if_list and table.len(if_list) > 0 then
      res = delete_interfaces_from_list(if_list)

      ntop.delCache(PCAP_DUMP_INTERFACES_DELETE_HASH)
   end

   return res
end

-- ################################################################

function delete_data_utils.delete_inactive_interfaces()
   delete_data_utils.delete_pcap_dump_interfaces_data()

   local inactive_if_list = delete_data_utils.list_inactive_interfaces()

   local res = delete_interfaces_from_list(inactive_if_list)

   for if_id, _ in pairs(inactive_if_list) do
      ntop.delHashCache(PCAP_DUMP_INTERFACES_DELETE_HASH, if_id)
   end

   return res
end

-- ################################################################

-- NOTE: this has 1 day accuracy
function delete_data_utils.harvestDateBasedDirTree(dir, retention, now, verbose)
   if not ntop.exists(dir) then
      return
   end

   if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format('Deleting files in %s older than %u days', dir, retention)) end

   for year in pairs(ntop.readdir(dir) or {}) do
      local year_path = os_utils.fixPath(dir .. "/" .. year)
      local num_deleted_months = 0
      local tot_months = 0

      for month in pairs(ntop.readdir(year_path) or {}) do
         local month_path = os_utils.fixPath(year_path .. "/" .. month)
         local num_deleted_days = 0
         local tot_days = 0

         for day in pairs(ntop.readdir(month_path) or {}) do
            if(tonumber(day) ~= nil) then
               local tstamp = os.time({day=tonumber(day), month=tonumber(month), year=tonumber(year), hour=0, min=0, sec=0})
               local days_diff = (now - tstamp) / 86400

               if(days_diff > retention) then
                  local day_path = os_utils.fixPath(month_path .. "/" .. day)
                  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, os.date('PURGE day: %Y-%m-%d', tstamp)) end

                  if not dry_run then
                     ntop.rmdir(day_path)
                  end

                  num_deleted_days = num_deleted_days + 1
               else
                  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, os.date('Keep day: %Y-%m-%d', tstamp)) end
               end

               tot_days = tot_days + 1
            end
         end

         if num_deleted_days == tot_days then
            if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "PURGE month: ".. month .."/" .. year) end

            if not dry_run then
               ntop.rmdir(month_path)
            end

            num_deleted_months = num_deleted_months + 1
         else
            if verbose then
               traceError(TRACE_NORMAL, TRACE_CONSOLE,
                  string.format("Keep month %u/%u: it still has %u days", month, year, tot_days-num_deleted_months))
            end
         end

         tot_months = tot_months + 1
      end

      if num_deleted_months == tot_months then
        if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "PURGE year: ".. year) end

        if not dry_run then
          ntop.rmdir(year_path)
        end
      else
         if verbose then
            traceError(TRACE_NORMAL, TRACE_CONSOLE,
               string.format("Keep year %u: it still has %u months", year, tot_months-num_deleted_months))
         end
      end
   end
end

-- ################################################################

-- TRACKER HOOK

tracker.track(delete_data_utils, 'delete_all_interfaces_data')
tracker.track(delete_data_utils, 'delete_inactive_interfaces')
tracker.track(delete_data_utils, 'request_delete_active_interface_data')

-- ################################################################

return delete_data_utils


