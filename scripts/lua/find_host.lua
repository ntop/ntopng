--
-- (C) 2013-18 - ntop.org
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

local max_num_to_find = 5
local already_printed = {}

local results = {}
local query = _GET["query"]
if(query == nil) then query = "" end

interface.select(ifname)
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

-- Look by network
local network_stats = interface.getNetworksStats()

for network, stats in pairs(network_stats) do
   local name = getFullLocalNetworkName(network)

   if string.contains(string.lower(name), string.lower(query)) then
      local network_id = stats.network_id

      results[#results + 1] = {
	 name = name,
	 type="network", network = network_id,
      }

      if #results >= max_num_to_find then
	 break
      end
   end
end

-- Look by AS
local as_info = interface.getASesInfo() or {}
for _, as in pairs(as_info.ASes or {}) do
   local asn = "AS" .. as.asn
   local as_name = as.asname

   if string.contains(string.lower(as_name), string.lower(query)) then
      results[#results + 1] = {
	 name = string.format("%s [%s]", as_name, asn),
	 type="asn", asn = as.asn,
      }
   elseif string.contains(string.lower(asn), string.lower(query)) then
      results[#results + 1] = {
	 name = asn,
	 type="asn", asn = as.asn,
      }
   end

   if #results >= max_num_to_find then
      break
   end
end

-- Check also in the mac addresses of snmp devices
-- The query can be partial so we can't use functions to
-- test if it'a an IPv4, an IPv6, or a mac as they would yield
-- wrong results. We can just check for a dot in the string as if
-- there's a dot then we're sure it can't be a mac
if ntop.isEnterprise() and not query:find("%.") then
   local mac = string.upper(query)
   local devices = get_snmp_devices()
   local matches = find_mac_snmp_ports(mac, true)

   for _, snmp_port in ipairs(matches) do
      local snmp_device_ip = snmp_port["snmp_device_ip"]
      local matching_mac = snmp_port["mac"]
      local snmp_port_idx = snmp_port["id"]
      local snmp_port_name = snmp_port["name"]

      local title = get_localized_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = snmp_port_name})

      results[#results + 1] = {
	 name = matching_mac .. ' '..title, type = "snmp",
	 ip = snmp_device_ip, snmp_port_idx = snmp_port_idx}

      if #results >= max_num_to_find then
	 break
      end
   end
end

if #results < max_num_to_find and res ~= nil then
   for k, v in pairs(res) do
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
      end -- if

      if #results >= max_num_to_find then
	 break
      end
   end -- for
end -- if

local resp = {interface = ifname,
	      results = results}

print(json.encode(resp))
