--
-- (C) 2014-18 - ntop.org
--
local dirs = ntop.getDirs()

require "graph_utils" -- getRRDName
local os_utils = require "os_utils"
local delete_data_utils = {}
local dry_run = false

function delete_data_utils.status_to_i18n(err)
   local map = {
      ERR_NO_HOST_FS_DATA = "delete_data..msg_err_no_fs_data",
      ERR_INVALID_HOST = "delete_data.msg_err_invalid_host",
   }

   return map[err] or 'delete_data.msg_err_unknown'
end

-- TODO: move to timeseries API
local function delete_host_fs_data(interface_id, host_info)
   local status = "OK"

   if not isMacAddress(host_info["host"]) and not isIPv4(host_info["host"]) and not isIPv6(host_info["host"]) then
      status = "ERR_INVALID_HOST"
   else
      -- getRRDName automatically determines the right path both for ip and mac addresses
      local host_rrd_dir = os_utils.fixPath(dirs.workingdir .. "/" .. interface_id .. "/rrd/" .. getPathFromKey(hostinfo2hostkey(host_info)))

      if not ntop.isdir(host_rrd_dir) then
	 -- missing directory
	 status = "ERR_NO_HOST_FS_DATA"
      else
	 local host_rrd_dir_contents = ntop.readdir(host_rrd_dir)

	 if host_rrd_dir_contents and table.len(host_rrd_dir_contents) == 0 then
	    -- directory existing, but missing files
	    status = "ERR_NO_HOST_FS_DATA"
	 end

	 if not dry_run then
	    ntop.rmdir(host_rrd_dir)
	 end
      end
   end

   return {status = status}
end

local function delete_host_redis_keys(interface_id, host_info)
   local status = "OK"
   local serialized_k, dns_k, devnames_k, devtypes_k

   if not isMacAddress(host_info["host"]) then
      -- this is an IP address, see HOST_SERIALIZED_KEY (ntop_defines.h)
      serialized_k = string.format("ntopng.serialized_hosts.ifid_%u__%s@%d", interface_id, host_info["host"], host_info["vlan"] or "0")
      dns_k = string.format("ntopng.dns.cache.%s", host_info["host"]) -- neither vlan nor ifid implemented for the dns cache
   elseif isIPv4(host_info["host"]) or isIPv6(host_info["host"]) then
      -- is a mac address, see MAC_SERIALIED_KEY (see ntop_defines.h)
      serialized_k = string.format("ntopng.serialized_macs.ifid_%u__%s", interface_id, host_info["host"])
      devnames_k = string.format("ntopng.cache.devnames.%s", host_info["host"])
      devtypes_k = string.format("ntopng.prefs.device_types.%s", host_info["host"])
   end

   if not dry_run then
      if serialized_k then ntop.delCache(serialized_k) end
      if devnames_k   then ntop.delCache(devnames_k) end
      if devtypes_k   then ntop.delCache(devtypes_k) end
      if dns_k        then ntop.delCache(dns_k) end
   end

   return {status = status}
end

local function delete_host_mysql_flows(interface_id, host_info)
   local status = "OK"

   if ntop.getPrefs()["is_dump_flows_to_mysql_enabled"] then
      local addr = host_info["host"]
      local vlan = host_info["vlan"] or 0
      local q

      if isIPv4(addr) then
	 q = string.format("DELETE FROM %s WHERE (IP_SRC_ADDR = INET_ATON('%s') OR IP_DST_ADDR = INET_ATON('%s')) AND VLAN_ID = %u and INTERFACE_ID = %u",
			   "flowsv4", addr, addr, vlan, interface_id)
      elseif isIPv6(addr) then
	 q = string.format("DELETE FROM %s WHERE (IP_SRC_ADDR = '%s' OR IP_DST_ADDR = '%s') AND VLAN_ID = %u AND INTERFACE_ID = %u",
			   "flowsv6", addr, addr, vlan, interface_id)
      end

      if not dry_run and q then
	 interface.execSQLQuery(q)
      end
   end

   return {status = status}
end

function delete_data_utils.delete_host(interface_id, host_info)
   local h_fs = delete_host_fs_data(interface_id, host_info)
   local h_rk = delete_host_redis_keys(interface_id, host_info)
   local h_db = delete_host_mysql_flows(interface_id, host_info)

   return {delete_host_fs_data = h_fs, delete_host_redis_keys = h_rk, delete_host_mysql_flows = h_db}
end

return delete_data_utils

