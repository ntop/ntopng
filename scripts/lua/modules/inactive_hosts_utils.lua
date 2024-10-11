--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require("lua_utils")
local json = require("dkjson")
local discover = require "discover_utils"

local OFFLINE_LOCAL_HOSTS_KEY = "ntopng.hosts.offline.ifid_%s"
local inactive_hosts_utils = {}

-- ##########################################

-- Function used to check if the host has to be filtered out or not
-- return true in case the host is okey, false in case it has to be filtered out
local function check_filters(host_info, filters)
   local mac_manufacturer = ntop.getMacManufacturer(host_info.mac) or {}
   local filters_ok = true

   for filter, value in pairs(filters or {}) do
      if filter == "manufacturer" then
	 if mac_manufacturer.extended ~= value then
	    filters_ok = false
	    goto skip
	 end
      elseif tostring(host_info[filter]) ~= tostring(value) then
	 filters_ok = false
	 goto skip
      end
   end

   ::skip::
   return filters_ok
end

-- ##########################################

-- This function return a list of inactive hosts, with all the informations
function inactive_hosts_utils.getInactiveHosts(ifid, filters)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local networks_stats = interface.getNetworksStats()
   local host_list = {}

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)
      local network_name = ""

      if not isEmptyString(host_info_json) then
	 local host_info = json.decode(host_info_json)
	 local mac_manufacturer = ntop.getMacManufacturer(host_info.mac) or {}
	 local mac_manufacturer_label = ""

	 if not check_filters(host_info, filters) then
	    goto skip
	 end

	 for n, ns in pairs(networks_stats) do
	    if ns.network_id == tonumber(host_info.network) then
	       network_name = getFullLocalNetworkName(ns.network_key)
	    end
	 end
	 if mac_manufacturer and not isEmptyString(mac_manufacturer.extended) then
	    mac_manufacturer_label = mac_manufacturer.extended
	 end

	 local h_ip = host_info.ip
	 if(host_info.vlan ~= 0) then
	    h_ip = h_ip  .. "@" .. host_info.vlan
	 end
	 
	 host_list[#host_list + 1] = {
	    ip_address = host_info.ip,
	    mac_address = host_info.mac,
	    host = h_ip,
	    vlan = getFullVlanName(host_info.vlan),
	    vlan_id = host_info.vlan,
	    name = host_info.name,
	    last_seen = host_info.last_seen,
	    first_seen = host_info.first_seen,
	    epoch_end = host_info.last_seen,
	    epoch_begin = host_info.first_seen,
	    device_id = host_info.device_type,
	    device_type = discover.devtype2string(host_info.device_type),
	    network_id = host_info.network,
	    network = network_name,
	    serial_key = redis_key,
	    manufacturer = mac_manufacturer_label
	 }
      end

      ::skip::
   end

   return host_list
end

-- ##########################################

-- This function return the info of a specific inactive host, given the serialization (redis) key
function inactive_hosts_utils.getInactiveHostInfo(ifid, serial_key)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local host_info_json = ntop.getHashCache(redis_hash, serial_key)

   if not isEmptyString(host_info_json) then
      local host_info = json.decode(host_info_json)

      return host_info
   end

   return nil
end

-- ##########################################

-- Return the inactive host number
function inactive_hosts_utils.getInactiveHostsNumber(ifid, filters)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local count = 0

   if filters then
      local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
      local available_keys = ntop.getHashKeysCache(redis_hash) or {}

      for redis_key, _ in pairs(available_keys) do
	 local host_info_json = ntop.getHashCache(redis_hash, redis_key)

	 if not isEmptyString(host_info_json) then
	    local host_info = json.decode(host_info_json)
	    local last_seen = host_info.last_seen

	    -- Exclude those that do not follow the filters
	    if not check_filters(host_info, filters) then
	       goto skip
	    end

	    count = count + 1
	    ::skip::
	 end
      end
   else
      count = table.len(available_keys)
   end

   return count
end

-- ##########################################

-- This function return a list of available VLAN filters
function inactive_hosts_utils.getVLANFilters(ifid, filters)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local vlan_list = {}
   local rsp = {}

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)

      if not isEmptyString(host_info_json) then
	 local host_info = json.decode(host_info_json)

	 -- Exclude those that do not follow the filters
	 if not check_filters(host_info, filters) then
	    goto skip
	 end

	 if not (vlan_list[host_info.vlan]) then
	    vlan_list[host_info.vlan] = 1
	 else
	    vlan_list[host_info.vlan] = vlan_list[host_info.vlan] + 1
	 end

	 ::skip::
      end
   end

   -- Add the vlan names
   for vlan, count in pairsByKeys(vlan_list) do
      local vlan_name = ''
      if vlan == 0 then
	 if table.len(vlan_list) == 1 then
	    break
	 end
	 vlan_name = i18n('no_vlan')
      else
	 vlan_name = getFullVlanName(vlan)
      end
      rsp[#rsp + 1] = {
	 count = count,
	 key = "vlan_id",
	 value = vlan,
	 label = tostring(vlan_name)
      }
   end

   -- Add the "all" entry
   table.insert(rsp, 1, {
		   key = "vlan_id",
		   value = "",
		   label = i18n('all')
   })

   return rsp
end

-- ##########################################

-- This function return a list of available network filters
function inactive_hosts_utils.getNetworkFilters(ifid, filters)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local networks_stats = interface.getNetworksStats()
   local network_list = {}
   local rsp = {}

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)
      local network_name = ""

      if not isEmptyString(host_info_json) then
	 local host_info = json.decode(host_info_json)

	 -- Exclude those that do not follow the filters
	 if not check_filters(host_info, filters) then
	    goto skip
	 end

	 if not (network_list[host_info.network]) then
	    network_list[host_info.network] = 1
	 else
	    network_list[host_info.network] = network_list[host_info.network] + 1
	 end

	 ::skip::
      end
   end

   -- Format the networks name
   for network, count in pairsByKeys(network_list) do
      local network_name
      for n, ns in pairs(networks_stats) do
	 if ns.network_id == tonumber(network) then
	    network_name = getFullLocalNetworkName(ns.network_key)
	 end
      end

      rsp[#rsp + 1] = {
	 count = count,
	 key = "network",
	 value = network,
	 label = tostring(network_name or network)
      }
   end
   -- Add the "all" entry
   table.insert(rsp, 1, {
		   key = "network",
		   value = "",
		   label = i18n('all')
   })

   return rsp
end

-- ##########################################

-- This function return a list of available device filters
function inactive_hosts_utils.getDeviceFilters(ifid, filters)
   local discover_utils = require "discover_utils"
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local device_list = {}
   local rsp = {}

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)

      if not isEmptyString(host_info_json) then
	 local host_info = json.decode(host_info_json)
	 local dev_name = discover_utils.devtype2string(host_info.device_type)

	 -- Exclude those that do not follow the filters
	 if not check_filters(host_info, filters) then
	    goto skip
	 end

	 if not (device_list[dev_name]) then
	    device_list[dev_name] = {
	       count = 1,
	       type = host_info.device_type
	    }
	 else
	    device_list[dev_name].count = device_list[dev_name].count + 1
	 end
	 
	 ::skip::
      end
   end

   for device, info in pairsByKeys(device_list) do
      rsp[#rsp + 1] = {
	 count = info.count,
	 key = "device_type",
	 value = info.type,
	 label = device
      }
   end
   -- Add "all" entry
   table.insert(rsp, 1, {
		   key = "device_type",
		   value = "",
		   label = i18n('all')
   })

   return rsp
end

-- ##########################################

-- This function return a list of available manufacturer filters
function inactive_hosts_utils.getManufacturerFilters(ifid, filters)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local manufacturer_list = {}
   local rsp = {}

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)

      if not isEmptyString(host_info_json) then
	 local host_info = json.decode(host_info_json)
	 local mac_manufacturer = ntop.getMacManufacturer(host_info.mac) or {}
	 local tmp = mac_manufacturer.extended

	 if isEmptyString(tmp) then
	    tmp = mac_manufacturer.short
	 end

	 -- Exclude those that do not follow the filters
	 if not check_filters(host_info, filters) then
	    goto skip
	 end

	 if tmp then
	    if not (manufacturer_list[tmp]) then
	       manufacturer_list[tmp] = 1
	    else
	       manufacturer_list[tmp] = manufacturer_list[tmp] + 1
	    end
	 end

	 ::skip::
      end
   end

   for manufacturer, count in pairsByKeys(manufacturer_list) do
      rsp[#rsp + 1] = {
	 count = count,
	 key = "manufacturer",
	 value = manufacturer,
	 label = manufacturer
      }
   end

   table.insert(rsp, 1, {
		   key = "manufacturer",
		   value = "",
		   label = i18n('all')
   })

   return rsp
end

-- ##########################################

function inactive_hosts_utils.deleteAllEntries(ifid)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local num_hosts_deleted = table.len(available_keys)

   for redis_key, _ in pairs(available_keys) do
      ntop.delHashCache(redis_hash, redis_key)
   end

   return num_hosts_deleted
end

-- ##########################################

function inactive_hosts_utils.deleteAllEntriesSince(ifid, epoch)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local num_hosts_deleted = 0

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)

      if isEmptyString(host_info_json) then
	 ntop.delHashCache(redis_hash, redis_key)
	 num_hosts_deleted = num_hosts_deleted + 1
      end

      local host_info = json.decode(host_info_json)
      if host_info.last_seen < epoch then
	 num_hosts_deleted = num_hosts_deleted + 1
	 ntop.delHashCache(redis_hash, redis_key)
      end
   end
   
   return num_hosts_deleted
end

-- ##########################################

function inactive_hosts_utils.deleteSingleEntry(ifid, redis_key)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   ntop.delHashCache(redis_hash, redis_key)
   return 1 -- Number of hosts deleted
end

-- ##########################################

function inactive_hosts_utils.formatInactiveHosts(hosts, no_html)
   local format_utils = require("format_utils")
   local discover_utils = require "discover_utils"

   -- Format the values to be used by the front end application
   for key, value in pairs(hosts) do
      local url = nil
      hosts[key]["last_seen"] = format_utils.formatPastEpochShort(value["last_seen"])
      hosts[key]["first_seen"] = format_utils.formatPastEpochShort(value["first_seen"])
      hosts[key]["manufacturer"] = value["manufacturer"]

      -- If available, add url and extra info
      local mac_info = interface.getMacInfo(value["mac_address"])
      if mac_info then
	 url = mac2url(value["mac_address"])

	 if no_html then
	    url = nil
	 end

	 hosts[key]["mac_address"] = {
	    name = mac2label(value["mac_address"]),
	    value = value["mac_address"],
	    url = url
	 }
      end

      if interface.getNetworkStats(hosts[key]["network_id"]) then
	 url = '/lua/hosts_stats.lua?network=' .. hosts[key]["network_id"]

	 if no_html then
	    url = nil
	 end
	 
	 hosts[key]["network"] = {
	    name = hosts[key]["network"],
	    value = hosts[key]["network_id"],
	    url = url
	 }
      end

      url = '/lua/inactive_host_details.lua?serial_key=' .. hosts[key]["serial_key"]
      local device_type = discover_utils.devtype2icon(value["device_id"])

      if no_html then
	 url = nil
	 device_type = nil
      end

      hosts[key]["host"] = {
	 ip_address = {
	    name = hosts[key]["ip_address"],
	    value = hosts[key]["ip_address"],
	    url = url
	 },
	 device_type = device_type,
	 device_name = discover_utils.devtype2string(value["device_id"])
      }

      if hosts[key]["vlan_id"] then
	 hosts[key]["host"]["vlan"] = {
	    name = hosts[key]["vlan"],
	    value = hosts[key]["vlan_id"]
	 }
	 if interface.getVLANInfo(hosts[key]["vlan_id"]) and not no_html then
	    hosts[key]["host"]["vlan"]["url"] = '/lua/hosts_stats.lua?vlan=' .. hosts[key]["vlan_id"]
	 end
      end

      hosts[key]["device_id"] = nil
      hosts[key]["network_id"] = nil
      hosts[key]["vlan_id"] = nil

      if no_html then
	 hosts[key].epoch_end = nil
	 hosts[key].epoch_begin = nil
	 hosts[key].serial_key = nil
	 hosts[key].vlan = nil
	 hosts[key].name = nil
      end
   end

   return hosts
end

-- ##########################################

function inactive_hosts_utils.formatInactiveHostsCSV(hosts)
   local formatted_hosts = inactive_hosts_utils.formatInactiveHosts(hosts, true --[[ No HTML ]])
   local column_names = "|"
   local csv_formatted = ""

   for key, value in pairs(formatted_hosts) do
      local tmp_value

      if value.mac_address then
	 tmp_value = value.mac_address.value
	 formatted_hosts[key].mac_address = tmp_value
      end

      tmp_value = value.network.name
      formatted_hosts[key].network = tmp_value
      
      tmp_value = value.host.ip_address.value
      formatted_hosts[key].ip_address = tmp_value
      
      tmp_value = value.host.ip_address.name
      formatted_hosts[key].hostname = tmp_value
      
      tmp_value = value.host.device_name
      formatted_hosts[key].device_type = tmp_value
      
      tmp_value = ""
      if value.host.vlan then
	 tmp_value = value.host.vlan.name or value.host.vlan.value
      end
      formatted_hosts[key].vlan = tmp_value

      value.host = nil
      column_names = "|"
      local concat = "|"
      for column, data in pairsByKeys(value) do
	 column_names = column_names .. string.upper(column) .. "|"
	 concat = concat .. data .. "|"
      end 
      csv_formatted = csv_formatted .. concat .. "\n"
   end
   
   return column_names .. "\n" .. csv_formatted
end

-- ##########################################

function inactive_hosts_utils.formatInactiveHostsJSON(hosts)
   local json = require("dkjson")
   local formatted_hosts = inactive_hosts_utils.formatInactiveHosts(hosts, true --[[ No HTML ]])

   return json.encode(formatted_hosts or {})
end

-- ##########################################

-- Return the distribution of inactive hosts on epoch basis:
--  - hour
--  - day
--  - week
--  - older
function inactive_hosts_utils.getInactiveHostsEpochDistribution(ifid, filters)
   local redis_hash = string.format(OFFLINE_LOCAL_HOSTS_KEY, ifid)
   local available_keys = ntop.getHashKeysCache(redis_hash) or {}
   local epoch_list = {
      last_hour = 0,
      last_day = 0,
      last_week = 0,
      older = 0,
   }
   local now = os.time() -- current epoch
   local one_hour_epoch = now - 3600
   local one_day_epoch = now - 86400
   local one_week_epoch = now - 604800

   for redis_key, _ in pairs(available_keys) do
      local host_info_json = ntop.getHashCache(redis_hash, redis_key)
      local network_name = ""

      if not isEmptyString(host_info_json) then
	 local host_info = json.decode(host_info_json)
	 local last_seen = host_info.last_seen

	 -- Exclude those that do not follow the filters
	 if not check_filters(host_info, filters) then
	    goto skip
	 end

	 if last_seen >= one_hour_epoch then
	    -- newer then one hour
	    epoch_list.last_hour = epoch_list.last_hour + 1 
	 elseif last_seen >= one_day_epoch then
	    -- newer then one day but older then one hour
	    epoch_list.last_day = epoch_list.last_day + 1
	 elseif last_seen >= one_week_epoch then
	    -- newer then one week but older then one day
	    epoch_list.last_week = epoch_list.last_week + 1
	 else
	    -- Older then one week
	    epoch_list.older = epoch_list.older + 1
	 end

	 ::skip::
      end
   end

   return epoch_list
end

-- ##########################################

function inactive_hosts_utils.getFilters()
   local filters = {
      vlan = _GET["vlan_id"],
      network = _GET["network"],
      device_type = _GET["device_type"],
      manufacturer = _GET["manufacturer"],
   }

   -- Return the data
   for filter, value in pairs(filters) do
      if isEmptyString(value) then
	 filters[filter] = nil
      end
   end

   return filters
end

-- ##########################################

return inactive_hosts_utils
