--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   require("snmp_utils")
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
if(query == nil) then query = "" end

interface.select(ifname)

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
   if ntop.isEnterprise() and not query:find("%.") then
      local mac = string.upper(query)
      local matches = find_mac_snmp_ports(mac, true)
      cur_results = 0

      for _, snmp_port in ipairs(matches) do
         if((cur_results >= max_group_items) or (#results >= max_total_items)) then
	    break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local matching_mac = snmp_port["mac"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]

         local title = get_localized_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = snmp_port_name})

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
   if ntop.isEnterprise() then
      local name = string.upper(query)
      local matches = find_snmp_ports_by_name(name, true)
      cur_results = 0

      for _, snmp_port in ipairs(matches) do
         if cur_results >= max_group_items or #results >= max_total_items then
	    break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]
         local snmp_port_index_match = snmp_port["index_match"]

         local title = get_localized_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = ternary(snmp_port_index_match, nil, snmp_port_name) })

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
   if ntop.isEnterprise() then
      local name = string.upper(query)
      local matches = find_snmp_devices(name, true)
      cur_results = 0

      for _, snmp_device in ipairs(matches) do
         if cur_results >= max_group_items or #results >= max_total_items then
	    break
         end

         local title = get_snmp_device_label(snmp_device["ip"])
         results[#results + 1] = {
            type = "snmp_device",
	    name = title.." ["..i18n("snmp.snmp_device").."]", 
	    ip = snmp_device["ip"]
         }
         cur_results = cur_results + 1
      end
   end

end -- not hosts only

-- Hosts
local res = interface.findHost(query)

-- Also look at the custom names
local ip_to_name = ntop.getHashAllCache(getHostAltNamesKey()) or {}

for ip,name in pairs(ip_to_name) do
   if string.contains(string.lower(name), string.lower(query)) then
      res[ip] = hostVisualization(ip, name)
   end
end

-- Also look at the DHCP cache
local mac_to_name = ntop.getHashAllCache(getDhcpNamesKey(getInterfaceId(ifname))) or {}
for mac, name in pairs(mac_to_name) do
   if string.contains(string.lower(name), string.lower(query)) then
      res[mac] = hostVisualization(mac, name)
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
