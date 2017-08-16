--
-- (C) 2013-17 - ntop.org
--

--
-- This script is executed once at startup similar to /etc/rc.local on Unix
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "alert_utils"
require "blacklist_utils"
require "db_utils"
local host_pools_utils = require "host_pools_utils"
local http_bridge_conf_utils = require "http_bridge_conf_utils"

local prefs = ntop.getPrefs()

-- restore sticky hosts
if prefs.sticky_hosts ~= nil then
   -- if the sticky hosts are set, then we try and restore them out of redis
   for _, ifname in pairs(interface.getIfNames()) do
      interface.select(ifname)
      local ifid = getInterfaceId(ifname)
      -- an example key is ntopng.serialized_hosts.ifid_6__192.168.2.136@0
      local keys_pattern = "ntopng.serialized_hosts.ifid_"..ifid.."__*"
      local dumped_hosts = ntop.getKeysCache("ntopng.serialized_hosts.ifid_"..ifid.."__*")

      if dumped_hosts ~= nil then
	 for hostkey, _ in pairs(dumped_hosts) do
	    -- let's extract just the host name and vlan from the whole key;
	    -- restore host will do the rest ...
	    local key_parts = string.split(hostkey, "__")
	    if key_parts ~= nil and key_parts[2] ~= nil then
	       local hostkey = key_parts[2]

	       interface.restoreHost(hostkey, true --[[ skip privileges checks: no web access --]])
	    end
	 end
      end
   end
end

host_pools_utils.initPools()

if(ntop.isPro()) then
   shaper_utils = require "shaper_utils"
   shaper_utils.initShapers()
end

-- old host alerts were global and did not consider vlans
-- this part of the script aims at converting old global alerts to per-interface, vlan aware alerts

-- convert host alert to include interfaces and vlans
for _, timespan in ipairs(alerts_granularity) do
   granularity = timespan[1]
   -- this is the old hash table that didn't include interfaces or vlans
   local hash_name = "ntopng.prefs.alerts_"..granularity
   -- grab the old hosts
   local hosts = ntop.getHashKeysCache(hash_name)
   if hosts ~= nil then
      for h in pairs(hosts) do
	 local hash_val = ntop.getHashCache(hash_name, h)
	 -- if here, we need to migrate the old hosts. Assumptions are that hosts
	 -- will be set for _all_ interfaces and for vlan 0

	 -- h can be iface_2 or a subnet such as 192.168.2.0/24 or an host such as 192.168.2.2
	 if not string.starts(h, "iface_") then
	    if not string.match(h,  "/") then
	       -- this is an host so we want to add the vlan
	       h = h.."@0"
	    end
	 end

	 for _, ifname in pairs(interface.getIfNames()) do
	    local ifid = getInterfaceId(ifname)
	    local new_hash_name = get_alerts_hash_name(granularity, ifname)
	    ntop.setHashCache(new_hash_name, h, hash_val)
	 end
      end
      -- remember to delete the hash with named hash_name
      ntop.delCache(hash_name)
   end
end

-- convert suppressed alerts to include interfaces and vlans
local hash_name = "ntopng.prefs.alerts"
-- grab the old hosts
local suppressed_alerts = ntop.getHashKeysCache(hash_name)
if suppressed_alerts ~= nil then
   for h in pairs(suppressed_alerts) do
      -- h can be iface_2 or a subnet such as 192.168.2.0/24 or an host such as 192.168.2.2
      if not string.starts(h, "iface_") then
	 if not string.match(h,  "/") then
	    -- this is an host so we want to add the vlan
	    h = h.."@0"
	 end
      end
      for _, ifname in pairs(interface.getIfNames()) do
	 local ifid = getInterfaceId(ifname)
	 local new_hash_name = "ntopng.prefs.alerts.ifid_"..tostring(ifid)
	 ntop.setHashCache(new_hash_name, h, "false")
      end
   end
end
-- remember to delete the hash with named hash_name
ntop.delCache(hash_name)

-- ##################################################################

loadHostBlackList()
checkOpenFiles()
-- TODO: migrate custom re-arm settings

-- this will retrieve host pools and policers configurtions via HTTP if enabled
http_bridge_conf_utils.configureBridge()
