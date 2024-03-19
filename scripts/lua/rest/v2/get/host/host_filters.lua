--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "label_utils"
require "http_lint"
require "lua_utils_get"
local rest_utils = require "rest_utils"
local rsp = {}
local ip_version_filters = {{
   key = "version",
   value = "",
   label = i18n("all")
}, {
   key = "version",
   value = "4",
   label = i18n("flows_page.ipv4_only")
}, {
   key = "version",
   value = "6",
   label = i18n("flows_page.ipv6_only")
}}

rsp[#rsp + 1] = {
   action = "version",
   label = i18n("flows_page.ip_version"),
   name = "version",
   value = ip_version_filters
}

local vlans = interface.getVLANsList()
if vlans then
   local vlan_filters = {{
      key = "vlan",
      value = "",
      label = i18n("all")
   }}
   for _, vlan in pairs(vlans.VLANs) do
      local vlan_name = tostring(getFullVlanName(vlan["vlan_id"]))
      if isEmptyString(vlan_name) then
         vlan_name = i18n('no_vlan')
      end
      vlan_filters[#vlan_filters + 1] = {
         key = "vlan",
         value = vlan["vlan_id"],
         label = vlan_name
      }
   end

   rsp[#rsp + 1] = {
      action = "vlan",
      label = i18n("flows_page.vlan"),
      name = "vlan",
      value = vlan_filters
   }
end

local direction_filters = {{
   key = "traffic_type",
   value = "",
   label = i18n("all")
}, {
   key = "traffic_type",
   value = "one_way",
   label = i18n("hosts_stats.traffic_type_one_way")
}, {
   key = "traffic_type",
   value = "bidirectional",
   label = i18n("hosts_stats.traffic_type_two_ways")
}}

rsp[#rsp + 1] = {
   action = "traffic_type",
   label = i18n("flows_page.direction"),
   name = "traffic_type",
   value = direction_filters
}

local hosts_filters = {{
   key = "mode",
   value = "",
   label = i18n("all")
}, {
   key = "mode",
   value = "blacklisted",
   label = i18n("hosts_stats.blacklisted_hosts_only")
}, {
   key = "mode",
   value = "broadcast_multicast",
   label = i18n("hosts_stats.broadcast_and_multicast")
}, {
   key = "mode",
   value = "local",
   label = i18n("hosts_stats.local_hosts_only")
}, {
   key = "mode",
   value = "local_no_tx",
   label = i18n("hosts_stats.local_no_tx")
}, {
   key = "mode",
   value = "local_no_tcp_tx",
   label = i18n("hosts_stats.local_no_tcp_tx")
}, {
   key = "mode",
   value = "remote",
   label = i18n("hosts_stats.remote_hosts_only")
}, {
   key = "mode",
   value = "remote_no_tx",
   label = i18n("hosts_stats.remote_no_tx")
}, {
   key = "mode",
   value = "remote_no_tcp_tx",
   label = i18n("hosts_stats.remote_no_tcp_tx")
}}

if interface.isPacketInterface() and not interface.isPcapDumpInterface() then
   hosts_filters[#hosts_filters + 1] = {
      key = "mode",
      value = "broadcast_domain",
      label = i18n("hosts_stats.broadcast_domain_hosts_only")
   }
   hosts_filters[#hosts_filters + 1] = {
      key = "mode",
      value = "dhcp",
      label = i18n("mac_stats.dhcp_only")
   }
end

rsp[#rsp + 1] = {
   action = "mode",
   label = i18n("hosts_stats.filter_hosts"),
   name = "mode",
   value = hosts_filters
}

-- Host pools
local host_pools = require "host_pools"
local host_pools_instance = host_pools:create()
local pools = host_pools_instance:get_all_pools()
if (table.len(pools) > 1) then
   local pool_filters = {{ 
      key = "pool",
      value = "",
      label = i18n("all")
   }}
   for _, pool in pairs(pools) do
      pool_filters[#pool_filters + 1] = {
         key = "pool",
         value = pool.pool_id,
         label = pool.name
      }
   end

   rsp[#rsp + 1] = {
      action = "pool",
      label = i18n("if_stats_config.add_rules_type_host_pool"),
      name = "pool",
      value = pool_filters
   }
end

if ntop.isPro() then
   local flowdevs = interface.getFlowDevices() or {}
   local devips = getProbesName(flowdevs)
   if table.len(devips) > 0 then
      local exporter_filters = {{ 
         key = "deviceIP",
         value = "",
         label = i18n("all")
      }}
      for interface, device_list in pairs(devips or {}) do
         for dev_ip, dev_resolved_name in pairsByValues(device_list, asc) do
            local dev_name = dev_ip
            if not isEmptyString(dev_resolved_name) and dev_resolved_name ~= dev_name then
               dev_name = dev_resolved_name
            end
            exporter_filters[#exporter_filters + 1] = {
               key = "deviceIP",
               value = dev_ip,
               label = dev_name
            }
         end
      end

      rsp[#rsp + 1] = {
         action = "deviceIP",
         label = i18n("flows_page.device_ip"),
         name = "deviceIP",
         value = exporter_filters
      }
   end
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
