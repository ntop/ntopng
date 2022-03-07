--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local tag_utils = require "tag_utils"
local snmp_utils
local snmp_location

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   snmp_utils = require "snmp_utils"
   snmp_location = require "snmp_location"
end

local rest_utils = require("rest_utils")

--
-- Read information about a host
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "query" : "192.168.1.1"}' http://localhost:3000/lua/rest/v2/get/host/find.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

-- Limits
local max_group_items = 5
local max_total_items = 20

local res_count
local already_printed = {}

local results = {}

if not isEmptyString(_GET["ifid"]) then
   interface.select(_GET["ifid"])
else
   interface.select(ifname)
end

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

local ifid = interface.getId()

local function build_historical_flows_url(key, value)
   return ntop.getHttpPrefix() .. '/lua/pro/db_search.lua?ifid=' .. ifid .. '&' .. tag_utils.build_request_filter(key, 'eq', value)
end

if not hosts_only then
   -- Look by network
   local network_stats = interface.getNetworksStats()
   res_count = 0

   for network, stats in pairs(network_stats) do
      if((res_count >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      local name = getFullLocalNetworkName(network)

      if string.contains(string.lower(name), string.lower(query)) then
         local network_id = stats.network_id

         results[#results + 1] = {
	    name = name,
            type="network",
            network = network_id,
         }
         res_count = res_count + 1
      end
   end

   -- Look by AS
   local as_info = interface.getASesInfo() or {}
   res_count = 0

   for _, as in pairs(as_info.ASes or {}) do
      if((res_count >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      local asn = "AS" .. as.asn
      local as_name = as.asname
      local found = false

      if string.contains(string.lower(as_name), string.lower(query)) then
         results[#results + 1] = {
	    name = string.format("%s [%s]", as_name, asn),
            type="asn",
            asn = as.asn,
         }
	 found = true
      elseif string.contains(string.lower(asn), string.lower(query)) then
         results[#results + 1] = {
            name = asn,
	    type="asn",
            asn = as.asn,
         }
	 found = true
      end

      if found then
	 res_count = res_count + 1
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
      res_count = 0

      for _, snmp_port in ipairs(matches) do
         if((res_count >= max_group_items) or (#results >= max_total_items)) then
	    break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local matching_mac = snmp_port["mac"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]

         local title = snmp_utils.get_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = snmp_port_name})

         results[#results + 1] = {
	    name = matching_mac .. ' '..title,
            type = "snmp",
	    ip = snmp_device_ip,
            snmp_port_idx = snmp_port_idx
         }
         res_count = res_count + 1
      end
   end

   -- Look by SNMP interface name
   if ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_ports_by_name(name, true)
      res_count = 0

      for _, snmp_port in ipairs(matches) do
         if res_count >= max_group_items or #results >= max_total_items then
	    break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]
         local snmp_port_index_match = snmp_port["index_match"]

         local title = snmp_utils.get_snmp_device_and_interface_label(snmp_device_ip, {index = snmp_port_idx, name = ternary(snmp_port_index_match, nil, snmp_port_name) })

         results[#results + 1] = {
	    name = title,
            type = "snmp",
	    ip = snmp_device_ip,
            snmp_port_idx = snmp_port_idx
         }
         res_count = res_count + 1
      end
   end

   -- Look by SNMP device
   if ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_devices(name, true)
      res_count = 0

      for _, snmp_device in ipairs(matches) do
         if res_count >= max_group_items or #results >= max_total_items then
	    break
         end

         local title = snmp_utils.get_snmp_device_label(snmp_device["ip"])
         results[#results + 1] = {
	    name = title.." ["..i18n("snmp.snmp_device").."]",
            type = "snmp_device",
	    ip = snmp_device["ip"]
         }
         res_count = res_count + 1
      end
   end

end -- not hosts only

local hosts = {}

-- Active Hosts
local res = interface.findHost(query)

for k, v in pairs(res) do
   local links = {}
   local historical_flows_url
   if k == v then -- IP
      historical_flows_url = build_historical_flows_url('ip', k)
   else -- Name
      historical_flows_url = build_historical_flows_url('name', v)
   end
   if historical_flows_url then
      links[#links + 1] = {
         icon = 'stream',
         url = historical_flows_url,
      }
   end

   hosts[k] = {
      label = v,
      name = v,
      ip = v,
      links = links,
   }
end

-- Inactive hosts (by MAC)
local key_to_ip_offset = string.len(string.format("ntopng.ip_to_mac.ifid_%u__", ifid)) + 1

for k in pairs(ntop.getKeysCache(string.format("ntopng.ip_to_mac.ifid_%u__%s*", ifid, query)) or {}) do
   -- Serialization by MAC address found
   local h = hostkey2hostinfo(string.sub(k, key_to_ip_offset))

   if(not hosts[h.host]) then
      -- Do not override active hosts
      hosts[h.host] = {
         label = i18n("host_details.inactive_host_x", {host = hostinfo2hostkey({host=h.host, vlan=h.vlan})}),
         ip = h.host,
         name = h.host,
      }
   end
end

-- Inactive hosts (by IP)
local key_to_ip_offset = string.len(string.format("ntopng.serialized_hosts.ifid_%u__", ifid)) + 1

for k in pairs(ntop.getKeysCache(string.format("ntopng.serialized_hosts.ifid_%u__%s*", ifid, query)) or {}) do
   local h = hostkey2hostinfo(string.sub(k, key_to_ip_offset))

   if(not hosts[h.host]) then
      -- Do not override active hosts / hosts by MAC
      hosts[h.host] = {
         label = i18n("host_details.inactive_host_x", {host = hostinfo2hostkey({host=h.host, vlan=h.vlan})}),
         ip = h.host,
         name = h.host,
      }
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
      local links = {}

      local historical_flows_url
      if name == value then -- IP
         historical_flows_url = build_historical_flows_url('ip', value)
      else -- Name
         historical_flows_url = build_historical_flows_url('name', value)
      end
      if historical_flows_url then
         links[#links + 1] = {
            icon = 'stream',
            url = historical_flows_url,
         }
      end

      hosts[ip] = {
         label = hostinfo2label({host = ip, name = name}),
         ip = ip,
         name = name,
      }
   end
end

-- Also look at the DHCP cache
local key_prefix_offset = string.len(getDhcpNameKey(getInterfaceId(ifname), "")) + 1
local mac_to_name = ntop.getKeysCache(getDhcpNameKey(getInterfaceId(ifname), "*")) or {}

for k in pairs(mac_to_name) do
   local mac = string.sub(k, key_prefix_offset)
   local name = ntop.getCache(k)

   if not isEmptyString(name) and string.contains(string.lower(name), string.lower(query)) then
      local links = {}
      hosts[mac] = {
         label = hostinfo2label({host = mac, mac = mac, name = name}),
         mac = mac,
         name = name,
         links = links,
      }
   end
end

res_count = 0

local function build_result(label, value, value_type, links)

   if value_type == 'ip' and isIPv6(value) and not string.contains(label, "%[IPv6%]") then
      label = label .. " [IPv6]"
   end

   local r = {
      name = label,
      ip = value,
      type = value_type,
      links = links or {
         -- { icon = nil, url = nil },
      },
   }
   return r
end

for k, v in pairs(hosts) do
   if((res_count >= max_group_items) or (#results >= max_total_items)) then
      break
   end

   if((v.label ~= "") and (already_printed[v.label] == nil)) then
      already_printed[v] = true

      if v.mac then
	 results[#results + 1] = build_result(v.label, v.mac, "mac")
      elseif v.ip then
	 results[#results + 1] = build_result(v.label, v.ip, "ip", v.links)
      end

      res_count = res_count + 1
   end -- if
end

local data = {
   interface = ifname,
   results = results,
}

rest_utils.answer(rc, data)

