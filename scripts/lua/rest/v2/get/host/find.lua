--
-- (C) 2013-23 - ntop.org
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

local is_system_interface = false
if interface.getId() == tonumber(getSystemInterfaceId()) then
   is_system_interface = true
end

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

-- Empty query
if(isEmptyString(query)) then
   local data = {
      interface = ifname,
      results = {},
   }
   
   -- tprint(results)
   
   rest_utils.answer(rc, data)
   return
end

local ifid = interface.getId()

--- Links

local function build_flow_alerts_url(key, value)
   local url = ntop.getHttpPrefix() .. '/lua/alert_stats.lua?ifid=' .. ifid .. "&status=historical&page=flow"

   local host_info = hostkey2hostinfo(value)
   if host_info['host'] then
      url = url .. '&' .. tag_utils.build_request_filter(key, 'eq', host_info['host'])
   end
   if host_info['vlan'] and host_info['vlan'] ~= 0 then
      url = url .. '&' .. tag_utils.build_request_filter('vlan_id', 'eq', host_info['vlan'])
   end

   return url
end

local function build_historical_flows_url(key, value)
   local url = ntop.getHttpPrefix() .. '/lua/pro/db_search.lua?ifid=' .. ifid

   local host_info = hostkey2hostinfo(value)
   if host_info['host'] then
      url = url .. '&' .. tag_utils.build_request_filter(key, 'eq', host_info['host'])
   end
   if host_info['vlan'] and host_info['vlan'] ~= 0 then
      url = url .. '&' .. tag_utils.build_request_filter('vlan_id', 'eq', host_info['vlan'])
   end

   return url
end

local function add_historical_flows_link(links, key --[[ ip, mac, name --]], value --[[ actual ip or mac or name (including vlan) --]])
   -- Alerts
   local flow_alerts_icon = 'exclamation-triangle'
   local flow_alerts_url = build_flow_alerts_url(key, value)
   links[#links + 1] = {
      icon = flow_alerts_icon,
      title = i18n('alerts_dashboard.alerts'),
      url = flow_alerts_url,
   }

   if hasClickHouseSupport() then
      -- Historical flows
      local historical_flows_icon = 'stream'
      local historical_flows_url = build_historical_flows_url(key, value)
      links[#links + 1] = {
         icon = historical_flows_icon,
         title = i18n('db_explorer.historical_data_explorer'),
         url = historical_flows_url,
      }
   end
end

local function add_icon_link(links, icon, title, url)
   -- table.insert(links, 1, link)
   links[#links + 1] = {
      icon = icon,
      title = title,
      url = url,
   }
end

local function add_asn_link(links)
   add_icon_link(links, 'cloud', i18n('as_details.as'))
end

local function add_network_link(links)
   add_icon_link(links, 'network-wired', i18n('network'))
end

local function add_device_link(links)
   add_icon_link(links, 'plug', i18n('device'))
end

local function add_host_link(links)
   add_icon_link(links, 'desktop', i18n('host_details.host'))
end

local function add_snmp_device_link(links, ip)
   add_icon_link(links, 'server', i18n('snmp.snmp_device'))
end

local function add_snmp_interface_link(links, ip, index)
   add_icon_link(links, 'ethernet', i18n('snmp.snmp_interface'))
end

--- Badges

local function add_badge(badges, label, icon, title)
   badges[#badges + 1] = {
      label = label,
      icon = icon,
      title = title,
   }
end

local function add_inactive_badge(badges)
   add_badge(badges, nil, 'moon', i18n('inactive'))
end

---

-- Look by network
if not is_system_interface and not hosts_only then
   local network_stats = interface.getNetworksStats()
   res_count = 0

   for network, stats in pairs(network_stats) do
      if((res_count >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      local name = getLocalNetworkLabel(network)

      if string.containsIgnoreCase(name, query) then
         local network_id = stats.network_id
         local links = {}
         add_network_link(links)

         results[#results + 1] = {
	    name = name,
            type = "network",
            network = network_id,
            links = links,
         }
         res_count = res_count + 1
      end
   end
end

-- Look by AS
if not is_system_interface and not hosts_only then
   local as_info = interface.getASesInfo() or {}
   res_count = 0

   for _, as in pairs(as_info.ASes or {}) do
      if((res_count >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      local asn = "AS" .. as.asn
      local as_name = as.asname
      local found = false
      local links = {}
      local badges = {}
      add_asn_link(links)

      if string.containsIgnoreCase(as_name, query) then
         add_badge(badges, asn)
         results[#results + 1] = {
	    name = as_name,
            type="asn",
            asn = as.asn,
            links = links,
            badges = badges,
         }
	 found = true
      elseif string.containsIgnoreCase(asn, query) then
         results[#results + 1] = {
            name = asn,
	    type = "asn",
            asn = as.asn,
            links = links,
            badges = badges,
         }
	 found = true
      end

      if found then
	 res_count = res_count + 1
      end
   end
end

-- Look by MAC - SNMP
if not hosts_only then
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

         local title = i18n("snmp.snmp_interface_x", { interface = shortenString(snmp_utils.get_snmp_interface_label({index = snmp_port_idx, name = snmp_port_name}))})

         title = title .. " · " .. snmp_utils.get_snmp_device_label(snmp_device_ip)

         local links = {}
         add_snmp_interface_link(links, snmp_device_ip, snmp_port_idx)

         results[#results + 1] = {
	    name = matching_mac .. ' '..title,
            type = "snmp",
	    ip = snmp_device_ip,
            snmp = snmp_device_ip,
            snmp_port_idx = snmp_port_idx,
            links = links,
         }
         res_count = res_count + 1
      end
   end
end

-- Look by interface name - SNMP
if not hosts_only then
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

         local title = i18n("snmp.snmp_interface_x", { interface = shortenString(snmp_utils.get_snmp_interface_label({index = snmp_port_idx, name = snmp_port_name}))})

         title = title .. " · " .. snmp_utils.get_snmp_device_label(snmp_device_ip)

         local links = {}
         add_snmp_interface_link(links, snmp_device_ip, snmp_port_idx)

         results[#results + 1] = {
	    name = title,
            type = "snmp",
	    ip = snmp_device_ip,
            snmp = snmp_device_ip,
            snmp_port_idx = snmp_port_idx,
            links = links,
         }
         res_count = res_count + 1
      end
   end
end

-- Look by SNMP device
if not hosts_only then
   if ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_devices(name, true)
      res_count = 0

      for _, snmp_device in ipairs(matches) do
         if res_count >= max_group_items or #results >= max_total_items then
	    break
         end

         local title = snmp_utils.get_snmp_device_label(snmp_device["ip"])

         local links = {}
         add_snmp_device_link(links, snmp_device["ip"])

         results[#results + 1] = {
	    name = title,
            type = "snmp_device",
	    ip = snmp_device["ip"],
            snmp_device = snmp_device["ip"],
            links = links,
         }
         res_count = res_count + 1
      end
   end

end -- not hosts only

-- Hosts

local hosts = {}

if not is_system_interface then

   -- Active Hosts
   local res = interface.findHost(query)

   for k, host_key in pairs(res) do
      local badges = {}
      local links = {}

      local ip = nil
      local mac = nil

      local label = host_key
      if host_key ~= k then
         label = label .. " · " .. k
      end

      if isMacAddress(host_key) then -- MAC
         mac = host_key
         add_device_link(links)
         add_historical_flows_link(links, 'mac', host_key)
      elseif isIPv6(host_key) then -- IP
         ip = host_key
         add_host_link(links)
         add_historical_flows_link(links, 'ip', host_key)
         add_badge(badges, 'IPv6')
      elseif k == host_key then -- IP
         ip = host_key
         add_host_link(links)
         add_historical_flows_link(links, 'ip', host_key)
      else -- Name
         ip = k
         add_host_link(links)
         add_historical_flows_link(links, 'name', host_key)
      end

      hosts[k] = {
         label = label,
         name = host_key,
         ip = ip,
         mac = mac,
         links = links,
         badges = badges,
      }
   end

   -- Inactive hosts - by MAC
   local key_to_ip_offset = string.len(string.format("ntopng.ip_to_mac.ifid_%u__", ifid)) + 1

   for k in pairs(ntop.getKeysCache(string.format("ntopng.ip_to_mac.ifid_%u__%s*", ifid, query)) or {}) do
      -- Serialization by MAC address found
      local h = hostkey2hostinfo(string.sub(k, key_to_ip_offset))

      if(not hosts[h.host]) then
         -- Do not override active hosts
         local links = {}
         add_host_link(links)
         add_historical_flows_link(links, 'ip', h.host)

         local badges = {}
         if isIPv6(h.host) then -- IP
            add_badge(badges, 'IPv6')
         end
         add_inactive_badge(badges)

         hosts[h.host] = {
            label = hostinfo2hostkey({host=h.host, vlan=h.vlan}),
            ip = h.host,
            name = h.host,
            links = links,
            badges = badges,
         }
      end
   end


   -- Inactive hosts - by IP
   local key_to_ip_offset = string.len(string.format("ntopng.serialized_hosts.ifid_%u__", ifid)) + 1

   for k in pairs(ntop.getKeysCache(string.format("ntopng.serialized_hosts.ifid_%u__%s*", ifid, query)) or {}) do
      local host_key = string.sub(k, key_to_ip_offset)

      if not hosts[host_key] then
         local h = hostkey2hostinfo(host_key)

         -- Do not override active hosts / hosts by MAC
         local links = {}
         add_host_link(links)
         add_historical_flows_link(links, 'ip', host_key)

         local badges = {}
         if isIPv6(h.host) then -- IP
            add_badge(badges, 'IPv6')
         end
         add_inactive_badge(badges)

         hosts[host_key] = {
            label = hostinfo2hostkey({host=h.host, vlan=h.vlan}),
            name = host_key,
            ip = host_key,
            links = links,
            badges = badges,
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
      if string.containsIgnoreCase(name, query) then
         local links = {}

         if name == value then -- IP
            add_host_link(links)
            add_historical_flows_link(links, 'ip', value)
         else -- Name
            add_host_link(links)
            add_historical_flows_link(links, 'name', value)
         end

         hosts[ip] = {
            label = hostinfo2label({host = ip, name = name}),
            ip = ip,
            name = name,
            links = links,
         }
      end
   end

   -- Also look at the DHCP cache
   local key_prefix_offset = string.len(getDhcpNameKey(getInterfaceId(ifname), "")) + 1
   local mac_to_name = ntop.getKeysCache(getDhcpNameKey(getInterfaceId(ifname), "*")) or {}
   for k in pairs(mac_to_name) do
      local mac = string.sub(k, key_prefix_offset)
      local name = ntop.getCache(k)

      if not isEmptyString(name) and string.containsIgnoreCase(name, query) then
         local links = {}
         add_device_link(links)
         add_historical_flows_link(links, 'mac', mac)

         hosts[mac] = {
            label = hostinfo2label({host = mac, mac = mac, name = name}) .. " · " .. mac,
            mac = mac,
            name = name,
            links = links,
         }
      end
   end

   -- Build final array with results

   res_count = 0

   local function build_result(label, value, value_type, links, badges, context)
      local r = {
         name = label,
         type = value_type,
         links = links,
         badges = badges,
         context = context,
      }

      r[value_type] = value

      return r
   end

   for k, v in pairsByField(hosts, 'name', asc) do
      if((res_count >= max_group_items) or (#results >= max_total_items)) then
         break
      end

      if((v.label ~= "") and (already_printed[v.label] == nil)) then
         already_printed[v] = true

         if v.mac then
            results[#results + 1] = build_result(v.label, v.mac, "mac", v.links, v.badges)
         elseif v.ip then

            -- Add badge for services
            local info = interface.getHostMinInfo(v.ip)
            if info and info.services then
               if not v.badges then v.badges = {} end
               for s,_ in pairs(info.services) do
                  add_badge(v.badges, s:upper())
               end
            end

            results[#results + 1] = build_result(v.label, v.ip, "ip", v.links, v.badges)
         end

         res_count = res_count + 1
      end -- if
   end

   if #results == 0 and not isEmptyString(query) then
      -- No results - add shortcut to search in historical data
      --tprint(query)
      if hasClickHouseSupport() then
         local label = ""
         local what = ""
         if isHostKey(query) then
            what = "ip"
            label = i18n("db_search.find_in_historical", {what=what, query=query})
            query = query .. tag_utils.SEPARATOR .. "eq"
         elseif isMacAddress(query) then
            what = "mac"
            label = i18n("db_search.find_in_historical", {what=what, query=query})
            query = query .. tag_utils.SEPARATOR .. "eq"
         elseif isCommunityId(query) then
         --tprint("HERE")
            what = "community_id"
            label = i18n("db_search.find_in_historical", {what=what, query=query})
            query = query .. tag_utils.SEPARATOR .. "eq"
         elseif isJA3(query) then
         --tprint("HERE")
            what = "ja3_client"
            label = i18n("db_search.find_in_historical", {what=what, query=query})
            query = query .. tag_utils.SEPARATOR .. "eq"
            results[#results + 1] = build_result(label, query, what, nil, nil, "historical")
            what = "ja3_server"
            label = i18n("db_search.find_in_historical", {what=what, query=query})
            query = query .. tag_utils.SEPARATOR .. "eq"
         else
            what = "hostname"
            label = i18n("db_search.find_in_historical", {what=what, query=query})
            query = query .. tag_utils.SEPARATOR .. "in"
         end

         --tprint(query)
         results[#results + 1] = build_result(label, query, what, nil, nil, "historical")
      end
   end

end -- hosts - not is_system_interface

local data = {
   interface = ifname,
   results = results,
}

-- tprint(results)

rest_utils.answer(rc, data)

