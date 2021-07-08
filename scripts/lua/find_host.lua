--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local snmp_utils
local snmp_location

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   snmp_utils = require "snmp_utils"
   snmp_location = require "snmp_location"
end

sendHTTPHeader('application/json')

-- Limits
local max_group_items = 5
local max_total_items = 20

local cur_results
local already_printed = {}

local results = {}
local query = _GET["query"]
local hosts_only = _GET["hosts_only"]

if (isEmptyString(query)) then
   query = ""
else

   -- clean trailing spaces
   query = trimString(query)
   -- remove any decorator from string end
   -- this is done because to the result we append additional
   -- information that the original string doesn't have
   -- example: 'Consglio nazionale della Sicurezza' doesn't contain
   -- the substring 'Consiglio Nazionale dei Ministri [xxxx]'
   query = query:gsub("% %[.*%]*", "")

end

if not isEmptyString(_GET["ifid"]) then
   interface.select(_GET["ifid"])
else
   interface.select(ifname)
end

local ifid = interface.getId()

if not hosts_only then
   -- Look by network
   local network_stats = interface.getNetworksStats()
   cur_results = 0

   for network, stats in pairs(network_stats) do
      if((cur_results >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      local name = getFullLocalNetworkName(network)

      if string.contains(string.lower(name), string.lower(query)) then
         local network_id = stats.network_id

         results[#results + 1] = {
	    name = name,
            type="network", network = network_id,
         }
         cur_results = cur_results + 1
      end
   end

   -- Look by AS
   local as_info = interface.getASesInfo() or {}
   cur_results = 0

   for _, as in pairs(as_info.ASes or {}) do
      if((cur_results >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      local asn = "AS" .. as.asn
      local as_name = as.asname
      local found = false

      if string.contains(string.lower(as_name), string.lower(query)) then
         results[#results + 1] = {
	    name = string.format("%s [%s]", as_name, asn),
            type="asn", asn = as.asn,
         }
	 found = true
      elseif string.contains(string.lower(asn), string.lower(query)) then
         results[#results + 1] = {
            name = asn,
	    type="asn", asn = as.asn,
         }
	 found = true
      end

      if found then
	 cur_results = cur_results + 1
      end
   end

   -- Check also in the mac addresses of snmp devices
   -- The query can be partial so we can't use functions to
   -- test if it'a an IPv4, an IPv6, or a mac as they would yield
   -- wrong results. We can just check for a dot in the string as if
   -- there's a dot then we're sure it can't be a mac

   if ntop.isEnterpriseM() and snmp_location and not query:find("%.") then
      local mac = string.upper(query)
      local matches = snmp_location.find_mac_snmp_ports(mac, true)
      cur_results = 0

      for _, snmp_port in ipairs(matches) do
         if((cur_results >= max_group_items) or (#results >= max_total_items)) then
	    break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local matching_mac = snmp_port["mac"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]

         local title = snmp_utils.get_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = snmp_port_name})

         results[#results + 1] = {
            type = "snmp",
	    name = matching_mac .. ' '..title,
	    ip = snmp_device_ip,
            snmp_port_idx = snmp_port_idx
         }
         cur_results = cur_results + 1
      end
   end

   -- Look by SNMP interface name
   if ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_ports_by_name(name, true)
      cur_results = 0

      for _, snmp_port in ipairs(matches) do
         if cur_results >= max_group_items or #results >= max_total_items then
	    break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]
         local snmp_port_index_match = snmp_port["index_match"]

         local title = snmp_utils.get_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = ternary(snmp_port_index_match, nil, snmp_port_name) })

         results[#results + 1] = {
            type = "snmp",
	    name = title,
	    ip = snmp_device_ip,
            snmp_port_idx = snmp_port_idx
         }
         cur_results = cur_results + 1
      end
   end

   -- Look by SNMP device
   if ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_devices(name, true)
      cur_results = 0

      for _, snmp_device in ipairs(matches) do
         if cur_results >= max_group_items or #results >= max_total_items then
	    break
         end

         local title = snmp_utils.get_snmp_device_label(snmp_device["ip"])
         results[#results + 1] = {
            type = "snmp_device",
	    name = title.." ["..i18n("snmp.snmp_device").."]",
	    ip = snmp_device["ip"]
         }
         cur_results = cur_results + 1
      end
   end

end -- not hosts only

-- Active Hosts
local res = interface.findHost(query)

-- Inactive hosts (by MAC)
local key_to_ip_offset = string.len(string.format("ntopng.ip_to_mac.ifid_%u__", ifid)) + 1

for k in pairs(ntop.getKeysCache(string.format("ntopng.ip_to_mac.ifid_%u__%s*", ifid, query)) or {}) do
   -- Serialization by MAC address found
   local h = hostkey2hostinfo(string.sub(k, key_to_ip_offset))

   if(not res[h.host]) then
      -- Do not override active hosts
      res[h.host] = i18n("host_details.inactive_host_x", {host = hostinfo2hostkey({host=h.host, vlan=h.vlan})})
   end
end

-- Inactive hosts (by IP)
local key_to_ip_offset = string.len(string.format("ntopng.serialized_hosts.ifid_%u__", ifid)) + 1

for k in pairs(ntop.getKeysCache(string.format("ntopng.serialized_hosts.ifid_%u__%s*", ifid, query)) or {}) do
   local h = hostkey2hostinfo(string.sub(k, key_to_ip_offset))

   if(not res[h.host]) then
      -- Do not override active hosts / hosts by MAC
      res[h.host] = i18n("host_details.inactive_host_x", {host = hostinfo2hostkey({host=h.host, vlan=h.vlan})})
   end
end

-- Also look at the custom names
-- Note: inefficient, so a limit on the maximum number must be enforced.
local name_prefix = getHostAltNamesKey("")
local name_keys = ntop.getKeysCache(getHostAltNamesKey("*")) or {}
local ip_to_name = {}

local max_num_names = 100 -- Avoid doing too many searches
for k, _ in pairs(name_keys) do
   local name = ntop.getCache(k)

   if not isEmptyString(name) then
      local ip = k:gsub(name_prefix, "")
      ip_to_name[ip] = name
   end

   max_num_names = max_num_names - 1
   if max_num_names == 0 then
      break
   end
end

for ip,name in pairs(ip_to_name) do
   if string.contains(string.lower(name), string.lower(query)) then
      res[ip] = hostinfo2label({host = ip, name = name})
   end
end

-- Also look at the DHCP cache
local key_prefix_offset = string.len(getDhcpNameKey(getInterfaceId(ifname), "")) + 1
local mac_to_name = ntop.getKeysCache(getDhcpNameKey(getInterfaceId(ifname), "*")) or {}

for k in pairs(mac_to_name) do
   local mac = string.sub(k, key_prefix_offset)
   local name = ntop.getCache(k)

   if not isEmptyString(name) and string.contains(string.lower(name), string.lower(query)) then
      res[mac] = hostinfo2label({host = mac, mac = mac, name = name})
   end
end

cur_results = 0

for k, v in pairs(res) do
   if((cur_results >= max_group_items) or (#results >= max_total_items)) then
      break
   end

   if isIPv6(v) and (not string.contains(v, "%[IPv6%]")) then
      v = v.." [IPv6]"
   end

   if((v ~= "") and (already_printed[v] == nil)) then
      if isMacAddress(v) then
	 results[#results + 1] = {name = v, ip = v, type = "mac"}
      elseif isMacAddress(k) then
	 results[#results + 1] = {name = v, ip = k, type = "mac"}
      else
	 results[#results + 1] = {name = v, ip = k, type = "ip"}
      end

      already_printed[v] = true
      cur_results = cur_results + 1
   end -- if
end

local resp = {interface = ifname,
	      results = results}

print(json.encode(resp))
