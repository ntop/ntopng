--
-- (C) 2017-26 - ntop.org
--
require "label_utils"
local json = require "dkjson"
local flowfilter_utils = require "flowfilter_utils"
local snmp_utils
local snmp_location

if ntop.isPro and ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   snmp_utils = require "snmp_utils"
   snmp_location = require "snmp_location"
end

local find_utils = {}

-- Limits
local max_group_items = 5
local max_total_items = 20

-- -----------------------------------------------

local function build_flow_alerts_url(key, value, ifid)
   local url = ntop.getHttpPrefix() .. '/lua/alert_stats.lua?ifid=' .. ifid .. "&status=historical&page=flow"

   local host_info = hostkey2hostinfo(value)
   if host_info['host'] then
      url = url .. '&' .. flowfilter_utils.build_request_filter(key, 'eq', host_info['host'])
   end
   if host_info['vlan'] and host_info['vlan'] ~= 0 then
      url = url .. '&' .. flowfilter_utils.build_request_filter('vlan_id', 'eq', host_info['vlan'])
   end

   return url
end

-- -----------------------------------------------

local function build_historical_flows_url(key, value, ifid)
   local url = ntop.getHttpPrefix() .. '/lua/pro/db_search.lua?ifid=' .. ifid

   local host_info = hostkey2hostinfo(value)
   if host_info['host'] then
      url = url .. '&' .. flowfilter_utils.build_request_filter(key, 'eq', host_info['host'])
   end
   if host_info['vlan'] and host_info['vlan'] ~= 0 then
      url = url .. '&' .. flowfilter_utils.build_request_filter('vlan_id', 'eq', host_info['vlan'])
   end

   return url
end

-- -----------------------------------------------

local function add_historical_flows_link(links, key --[[ ip, mac, name --]] , value --[[ actual ip or mac or name (including vlan) --]] ,
   ifid)
   -- Alerts
   local flow_alerts_icon = 'exclamation-triangle'
   local flow_alerts_url = build_flow_alerts_url(key, value, ifid)
   links[#links + 1] = {
      icon = flow_alerts_icon,
      title = i18n('alerts_dashboard.alerts'),
      url = flow_alerts_url
   }

   if hasClickHouseSupport() then
      -- Historical flows
      local historical_flows_icon = 'stream'
      local historical_flows_url = build_historical_flows_url(key, value, ifid)
      links[#links + 1] = {
         icon = historical_flows_icon,
         title = i18n('db_explorer.historical_data_explorer'),
         url = historical_flows_url
      }
   end
end

-- -----------------------------------------------

local function add_as_info_link(links, asn, ifid)
   -- AS Info
   local as_info_icon = 'circle-info'
   local as_info_url = ntop.getHttpPrefix() .. '/lua/as_stats.lua?ifid=' .. ifid .. '&asn=' .. asn
   links[#links + 1] = {
      icon = as_info_icon,
      title = i18n('as_info'),
      url = as_info_url
   }
end

-- -----------------------------------------------

local function add_icon_link(links, icon, title, url)
   -- table.insert(links, 1, link)
   links[#links + 1] = {
      icon = icon,
      title = title,
      url = url
   }
end

-- -----------------------------------------------

local function add_asn_link(links)
   add_icon_link(links, 'cloud', i18n('as_details.as'))
end

-- -----------------------------------------------

local function add_network_link(links)
   add_icon_link(links, 'network-wired', i18n('network'))
end

-- -----------------------------------------------

local function add_device_link(links)
   add_icon_link(links, 'plug', i18n('device'))
end

-- -----------------------------------------------

local function add_host_link(links)
   add_icon_link(links, 'desktop', i18n('host_details.host'))
end

-- -----------------------------------------------

local function add_snmp_device_link(links, ip)
   add_icon_link(links, 'server', i18n('snmp.snmp_device'))
end

-- -----------------------------------------------

local function add_snmp_interface_link(links, ip, index)
   add_icon_link(links, 'ethernet', i18n('snmp.snmp_interface'))
end

-- -----------------------------------------------

--- Badges
local function add_badge(badges, label, icon, title)
   badges[#badges + 1] = {
      label = label,
      icon = icon,
      title = title
   }
end

-- -----------------------------------------------

local function add_inactive_badge(badges)
   add_badge(badges, nil, 'moon', i18n('inactive'))
end

-- -----------------------------------------------

local function build_result(label, value, value_type, links, badges, context, ifid)
   local r = {
      name = label,
      type = value_type,
      links = links,
      badges = badges,
      context = context,
      ifid = ifid,
      if_name = interface.getName()
   }

   r[value_type] = value

   return r
end

-- -----------------------------------------------

-- No results - add shortcut to search in historical data
local function build_no_results_entry(query, ifid)
   local label = ""
   local what = ""
   if isHostKey(query) then
      what = "ip"
      label = i18n("db_search.find_in_historical", {
         what = what,
         query = query
      })
      query = query .. flowfilter_utils.SEPARATOR .. "eq"
   elseif isMacAddress(query) then
      what = "mac"
      label = i18n("db_search.find_in_historical", {
         what = what,
         query = query
      })
      query = query .. flowfilter_utils.SEPARATOR .. "eq"
   elseif isCommunityId(query) then
      what = "community_id"
      label = i18n("db_search.find_in_historical", {
         what = what,
         query = query
      })
      query = query .. flowfilter_utils.SEPARATOR .. "eq"
   else
      what = "hostname"
      label = i18n("db_search.find_in_historical", {
         what = what,
         query = query
      })
      query = query .. flowfilter_utils.SEPARATOR .. "in"
   end
   return build_result(label, query, what, nil, nil, "historical", ifid)
end

-- -----------------------------------------------

-- No Exact Match - add shortcut to search in historical data
local function build_no_exact_match_entry(query, ifid)
   what = "ip"
   label = i18n("db_search.no_exact_match", {
      what = what,
      query = query
   })
   query = query .. flowfilter_utils.SEPARATOR .. "eq"
   return build_result(label, query, what, nil, nil, "historical", ifid)
end

-- -----------------------------------------------

-- Look by network
local function find_network(query, tot_results, ifid, add_interface_name)
   local results = {}
   local interface_name = getInterfaceName(ifid)

   local network_stats = interface.getNetworksStats()

   for network, stats in pairs(network_stats) do
      if #results >= max_group_items or (#results + tot_results) >= max_total_items then
         break
      end

      local name = getLocalNetworkLabel(network)

      if string.containsIgnoreCase(name, query) then
         local network_id = stats.network_id
         local links = {}
         local badges = {}
         add_network_link(links)

         if add_interface_name then
            add_badge(badges, interface_name)
         end

         results[#results + 1] = {
            name = name,
            type = "network",
            network = network_id,
            links = links,
            badges = badges,
            ifid = ifid
         }
      end
   end

   return results
end

-- -----------------------------------------------

-- Look by AS
local function find_as(query, tot_results, ifid, add_interface_name)
   local results = {}

   local as_info = interface.getASesInfo() or {}
   local interface_name = getInterfaceName(ifid)

   for _, as in pairs(as_info.ASes or {}) do
      if #results >= max_group_items or (#results + tot_results) >= max_total_items then
         break
      end

      local asn = "AS" .. as.asn
      local as_name = as.asname
      local links = {}
      local badges = {}
      local name = ""
      add_asn_link(links)
      add_as_info_link(links, as.asn, ifid)

      if add_interface_name then
         add_badge(badges, interface_name)
      end

      if string.containsIgnoreCase(as_name, query) then
         add_badge(badges, asn)
         results[#results + 1] = {
            name = name .. as_name,
            type = "asn",
            asn = as.asn,
            links = links,
            badges = badges,
            ifid = ifid,
            if_name = interface.getName()
         }
      elseif string.containsIgnoreCase(asn, query) then
         results[#results + 1] = {
            name = name .. asn,
            type = "asn",
            asn = as.asn,
            links = links,
            badges = badges,
            ifid = ifid,
            if_name = interface.getName()
         }
      end
   end

   return results
end

-- -----------------------------------------------

-- Look by MAC - SNMP
local function find_snmp_mac(query, tot_results)
   local results = {}

   -- Check also in the mac addresses of snmp devices
   -- The query can be partial so we can't use functions to
   -- test if it'a an IPv4, an IPv6, or a mac as they would yield
   -- wrong results. We can just check for a dot in the string as if
   -- there's a dot then we're sure it can't be a mac

   if ntop.isEnterpriseM and ntop.isEnterpriseM() and snmp_location and not query:find("%.") then
      local mac = string.upper(query)
      local matches = snmp_location.find_mac_snmp_ports(mac, true)

      for _, snmp_port in ipairs(matches) do
         if #results >= max_group_items or (#results + tot_results) >= max_total_items then
            break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local matching_mac = snmp_port["mac"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]

         local title = i18n("snmp.snmp_interface_x", {
            interface = shortenString(snmp_utils.get_snmp_interface_label({
               index = snmp_port_idx,
               name = snmp_port_name
            }))
         })

         title = title .. " · " .. snmp_utils.get_snmp_device_label(snmp_device_ip)

         local links = {}
         add_snmp_interface_link(links, snmp_device_ip, snmp_port_idx)

         results[#results + 1] = {
            name = matching_mac .. ' ' .. title,
            type = "snmp",
            ip = snmp_device_ip,
            snmp = snmp_device_ip,
            snmp_port_idx = snmp_port_idx,
            links = links,
            ifid = ifid
         }
      end
   end

   return results
end

-- -----------------------------------------------

-- Look by interface name - SNMP
local function find_snmp_interface(query, tot_results)
   local results = {}

   if ntop.isEnterpriseM and ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_ports_by_name(name, true)

      for _, snmp_port in ipairs(matches) do
         if #results >= max_group_items or (#results + tot_results) >= max_total_items then
            break
         end

         local snmp_device_ip = snmp_port["snmp_device_ip"]
         local snmp_port_idx = snmp_port["id"]
         local snmp_port_name = snmp_port["name"]
         local snmp_port_index_match = snmp_port["index_match"]

         local title = i18n("snmp.snmp_interface_x", {
            interface = shortenString(snmp_utils.get_snmp_interface_label({
               index = snmp_port_idx,
               name = snmp_port_name
            }))
         })

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
            ifid = ifid
         }
      end
   end

   return results
end

-- -----------------------------------------------

-- Look by SNMP device
local function find_snmp_device(query, tot_results)
   local results = {}

   if ntop.isEnterpriseM and ntop.isEnterpriseM() then
      local name = string.upper(query)
      local matches = snmp_utils.find_snmp_devices(name, true)

      for _, snmp_device in ipairs(matches) do
         if #results >= max_group_items or (#results + tot_results) >= max_total_items then
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
            ifid = ifid
         }
      end
   end

   return results
end

-- -----------------------------------------------

-- Hosts
local function find_host(query, tot_results, ifid, add_interface_name)
   local results = {}

   local interface_name = getInterfaceName(ifid)

   local query_info = hostkey2hostinfo(query)
   local is_full_ip = isIPv4(query_info['host']) or isIPv6(query_info['host'])

   local already_printed = {}

   -- Report if a perfect host match was found (full ip)
   local exact_ip_match = false
   local partial_ip_match = false

   local hosts = {}

   -- 1st look at custom names (aliases)

   -- Note: inefficient, so a limit on the maximum number must be enforced.
   local name_prefix = getHostAltNamesKey("")
   local ip_to_name = {}
   local max_num_names = 500 -- Limit the number of keys in the lookup
   local name_keys = ntop.getKeysCache(getHostAltNamesKey("*")) or {}
   for k, _ in pairs(name_keys) do
      local name = ntop.getCache(k)

      if isEmptyString(name) then
         -- key cleanup (unused)
         ntop.delCache(k)
      else
         local ip = k:gsub(name_prefix, "")
         ip_to_name[ip] = name

         max_num_names = max_num_names - 1
         if max_num_names == 0 then
            break
         end
      end
   end

   for ip, name in pairs(ip_to_name) do
      if not hosts[ip] then
         if string.containsIgnoreCase(name, query) then
            local links = {}

            if name == ip then -- IP
               add_host_link(links)
               add_historical_flows_link(links, 'ip', ip, ifid)
            else -- Name
               add_host_link(links)
               add_historical_flows_link(links, 'name', name, ifid)
            end

            hosts[ip] = {
               label = hostinfo2label({
                  host = ip,
                  name = name
               }),
               ip = ip,
               name = name,
               links = links
            }
         end
      end
   end

   -- Active Hosts
   local res = interface.findHost(query)

   for k, host_key in pairs(res) do
      if not hosts[k] then
         local badges = {}
         local links = {}

         local ip = nil
         local mac = nil

         local host_info = hostkey2hostinfo(host_key)
         local label = hostinfo2label(host_info, true)
         if host_key ~= k then
            label = label .. " · " .. k
         end

         if isMacAddress(host_key) then -- MAC
            mac = host_key
            add_device_link(links)
            add_historical_flows_link(links, 'mac', host_key, ifid)
         elseif isIPv6(host_key) then -- IP
            ip = host_key
            add_host_link(links)
            add_historical_flows_link(links, 'ip', host_key, ifid)
            add_badge(badges, 'IPv6')
         elseif k == host_key then -- IP
            ip = host_key
            add_host_link(links)
            add_historical_flows_link(links, 'ip', host_key, ifid)
         else -- Name
            ip = k
            add_host_link(links)
            add_historical_flows_link(links, 'name', host_key, ifid)
         end

         if add_interface_name then
            add_badge(badges, interface_name)
         end

         partial_ip_match = true
         exact_ip_match = is_full_ip and host_info['host'] == query_info['host']

         hosts[k] = {
            label = label,
            name = host_key,
            ip = ip,
            mac = mac,
            links = links,
            badges = badges
         }
      end
   end

   -- Inactive hosts - by MAC
   local key_to_ip_offset = string.len(string.format("ntopng.ip_to_mac.ifid_%u__", ifid)) + 1

   for k in pairs(ntop.getKeysCache(string.format("ntopng.ip_to_mac.ifid_%u__%s*", ifid, query)) or {}) do
      -- Serialization by MAC address found
      local h = hostkey2hostinfo(string.sub(k, key_to_ip_offset))

      if not hosts[h.host] then
         -- Do not override active hosts
         local links = {}
         add_host_link(links)
         add_historical_flows_link(links, 'ip', h.host, ifid)

         local badges = {}

         if isIPv6(h.host) then -- IP
            add_badge(badges, 'IPv6')
         end
         add_inactive_badge(badges)

         if add_interface_name then
            add_badge(badges, interface_name)
         end

         hosts[h.host] = {
            label = hostinfo2label({
               host = h.host,
               vlan = h.vlan
            }, true),
            ip = h.host,
            name = h.host,
            links = links,
            badges = badges
         }
      end
   end

   -- Inactive hosts - by IP
   --[[ Note: host serialization is disabled
   local key_to_ip_offset = string.len(string.format("ntopng.serialized_hosts.ifid_%u__", ifid)) + 1

   for k in pairs(ntop.getKeysCache(string.format("ntopng.serialized_hosts.ifid_%u__%s*", ifid, query)) or {}) do
      local host_key = string.sub(k, key_to_ip_offset)

      if not hosts[host_key] then
         local h = hostkey2hostinfo(host_key)

         -- Do not override active hosts / hosts by MAC
         local links = {}
         add_host_link(links)
         add_historical_flows_link(links, 'ip', host_key, ifid)

         local badges = {}
         if isIPv6(h.host) then -- IP
            add_badge(badges, 'IPv6')
         end
         add_inactive_badge(badges)

         if add_interface_name then
            add_badge(badges, interface_name)
         end

         hosts[host_key] = {
            label = hostinfo2hostkey({host=h.host, vlan=h.vlan}),
            name = host_key,
            ip = host_key,
            links = links,
            badges = badges,
         }
      end
   end
   --]]

   -- Also look at the DHCP cache
   local key_prefix_offset = string.len(getDhcpNameKey(ifid, "")) + 1
   local mac_to_name = ntop.getKeysCache(getDhcpNameKey(ifid, "*")) or {}
   for k in pairs(mac_to_name) do

      local mac = string.sub(k, key_prefix_offset)
      if hosts[mac] then

         local name = ntop.getCache(k)
         if not isEmptyString(name) and string.containsIgnoreCase(name, query) then

            local links = {}
            add_device_link(links)
            add_historical_flows_link(links, 'mac', mac, ifid)

            hosts[mac] = {
               label = hostinfo2label({
                  host = mac,
                  mac = mac,
                  name = name
               }) .. " · " .. mac,
               mac = mac,
               name = name,
               links = links
            }
         end
      end
   end

   -- Build final array with results

   for k, v in pairsByField(hosts, 'name', asc) do
      if #results >= max_group_items or (#results + tot_results) >= max_total_items then
         break
      end

      if ((v.label ~= "") and (already_printed[v.label] == nil)) then
         already_printed[v] = true

         if v.mac then
            results[#results + 1] = build_result(v.label, v.mac, "mac", v.links, v.badges, nil, ifid)
         elseif v.ip then

            -- Add badge for services
            local info = interface.getHostMinInfo(v.ip)
            if info and info.services then
               if not v.badges then
                  v.badges = {}
               end
               for s, _ in pairs(info.services) do
                  add_badge(v.badges, s:upper())
               end
            end

            results[#results + 1] = build_result(v.label, v.ip, "ip", v.links, v.badges, nil, ifid)
         end
      end -- if
   end

   local lookup_info = {
      is_full_ip = is_full_ip,
      partial_ip_match = partial_ip_match,
      exact_ip_match = exact_ip_match
   }

   return results, lookup_info
end

-- -----------------------------------------------

-- Lookup on all entities
local function find_on_interface(query, hosts_only, ifid, tot_results, add_interface_name)
   local results = {}
   local host_results = {}
   local lookup_info = {}

   tot_results = tot_results or 0

   -- Select requested ifid
   local active_ifid = interface.getId()
   if active_ifid ~= ifid then
      interface.select(ifid)
   end

   local is_system_interface = false
   if interface.getId() == tonumber(getSystemInterfaceId()) then
      is_system_interface = true
   end

   -- Lookups

   if not hosts_only then
      if not is_system_interface then
         results = table.merge(results, find_network(query, #results + tot_results, ifid, add_interface_name))
         results = table.merge(results, find_as(query, #results + tot_results, ifid, add_interface_name))
      end
   end

   if not is_system_interface then
      host_results, lookup_info = find_host(query, #results + tot_results, ifid, add_interface_name)
      results = table.merge(results, host_results)
   end

   -- Select actual ifid
   if active_ifid ~= ifid then
      interface.select(active_ifid)
   end

   lookup_info.num_hosts = #host_results

   return results, lookup_info
end

-- -----------------------------------------------

-- Lookup on all entities
function find_utils.find(query, hosts_only, ifid)
   local results = {}
   local lookup_info = {}

   -- Lookups

   results, lookup_info = find_on_interface(query, hosts_only, ifid, #results)

   if lookup_info.num_hosts == 0 and not isEmptyString(query) and hasClickHouseSupport() then
      results[#results + 1] = build_no_results_entry(query, ifid)
   else
      local no_exact_ip_match = (lookup_info.is_full_ip and lookup_info.partial_ip_match and not lookup_info.exact_ip_match)
      if no_exact_ip_match then
         results[#results + 1] = build_no_exact_match_entry(query)
      end
   end

   if not hosts_only then
      results = table.merge(results, find_snmp_mac(query, #results, ifid))
      results = table.merge(results, find_snmp_interface(query, #results, ifid))
      results = table.merge(results, find_snmp_device(query, #results, ifid))
   end

   return results
end

-- -----------------------------------------------

-- Lookup on all entities
function find_utils.find_on_any_interface(query, hosts_only)
   local results = {}
   local lookup_info = {}
   local tot_num_hosts = 0
   local is_full_ip = false
   local exact_ip_match = false
   local partial_ip_match = false

   local interfaces = interface.getIfNames()

   for id, name in pairs(interfaces) do
      local host_results, lookup_info = find_on_interface(query, hosts_only, id, #results, true --[[ Add the interface name to the label ]])
      results = table.merge(results, host_results)
      tot_num_hosts = tot_num_hosts + lookup_info.num_hosts
      if lookup_info.is_full_ip then
         is_full_ip = true
      end
      if lookup_info.exact_ip_match then
         exact_ip_match = true
      end
      if lookup_info.partial_ip_match then
         partial_ip_match = true
      end
   end

   if tot_num_hosts == 0 and not isEmptyString(query) and hasClickHouseSupport() then
      results[#results + 1] = build_no_results_entry(query)
   else
      local no_exact_ip_match = (is_full_ip and partial_ip_match and not exact_ip_match)
      if no_exact_ip_match then
         results[#results + 1] = build_no_exact_match_entry(query)
      end
   end

   if not hosts_only then
      results = table.merge(results, find_snmp_mac(query, #results, ifid))
      results = table.merge(results, find_snmp_interface(query, #results, ifid))
      results = table.merge(results, find_snmp_device(query, #results, ifid))
   end

   return results
end

-- -----------------------------------------------

return find_utils
