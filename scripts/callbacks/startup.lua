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
host_pools_utils = require "host_pools_utils"

local prefs = ntop.getPrefs()

-- move the old serialized hosts format to the new one
local json = require("dkjson")
local first_one = true
for _, ifname in pairs(interface.getIfNames()) do
   interface.select(ifname)
   local ifid = getInterfaceId(ifname)

   local dumped_hosts = ntop.getKeysCache("ntopng.serialized_hosts.ifid_"..ifid.."__*")
   if dumped_hosts ~= nil then
      for hostkey, _ in pairs(dumped_hosts) do
         if first_one then
            io.write("Migrating hosts cache to new key format...\n")
            first_one = false
         end

         local json_val = ntop.getCache(hostkey)
         if json_val ~= nil then
            local val = json.decode(json_val)
            if (val ~= nil) and (val.ip ~= nil) and (not isEmptyString(val.ip.ip)) then
               local mac = ""
               local vlan_id = 0
               if isMacAddress(val.mac_address) then
                  mac = val.mac_address
               end
               if tonumber(val.vlan_id) ~= nil then
                  vlan_id = val.vlan_id
               end

               ntop.setCache("ntopng.serialized_hosts.ifid_"..ifid.."_"..val.ip.ip.."_"..mac.."@"..vlan_id, json_val)
               ntop.delCache(hostkey)
            end
         end
      end
   end
end

if not first_one then
   io.write("Hosts cache migration completed successfully\n")
end

-- restore sticky hosts
if prefs.sticky_hosts ~= nil then
   -- if the sticky hosts are set, then we try and restore them out of redis
   for _, ifname in pairs(interface.getIfNames()) do
      interface.select(ifname)
      local ifid = getInterfaceId(ifname)
      -- an example key is ntopng.serialized_hosts.ifid_6_192.168.2.136_22:12:13:14:15:34@0
      local keys_pattern = "ntopng.serialized_hosts.ifid_"..ifid.."_*"
      local dumped_hosts = ntop.getKeysCache("ntopng.serialized_hosts.ifid_"..ifid.."_*")
      if dumped_hosts ~= nil then
	 for hostkey, _ in pairs(dumped_hosts) do
	    -- let's extract just the host name and vlan from the whole key;
	    -- restore host will do the rest ...
	    local key_parts = string.split(hostkey, "_")
	    if key_parts ~= nil and key_parts[4] ~= nil then
	       local hostkey = key_parts[4]
	       if key_parts[5] ~= nil then
		  local parts = string.split(key_parts[5], "@")
		  if #parts == 2 then
		     -- add vlan
		     hostkey = hostkey .. "@" .. parts[2]
		  end
	       end

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

