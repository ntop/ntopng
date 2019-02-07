--
-- (C) 2013-18 - ntop.org
--

--
-- This script is executed once at startup similar to /etc/rc.local on Unix
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require("startup")
end

require "lua_utils"
require "alert_utils"

local discover_utils = require "discover_utils"
local host_pools_utils = require "host_pools_utils"
local os_utils = require "os_utils"
local lists_utils = require "lists_utils"
local recovery_utils = require "recovery_utils"
local ts_utils = require "ts_utils"

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

-- Use a specific bridging_policy_target_type default for previous user installations
if isEmptyString(ntop.getPref("ntopng.prefs.bridging_policy_target_type")) then
   for _, ifname in pairs(interface.getIfNames()) do
      local ifid = getInterfaceId(ifname)
      interface.select(ifname)

      local stats = interface.getStats()
      if stats.inline then
         -- Override the default
         ntop.setPref("ntopng.prefs.bridging_policy_target_type", "both")
         break
      end
   end
end

-- ##################################################################

-- Migration from old ntop auth_type to new separeted keys
local old_auth_val = ntop.getPref("ntopng.prefs.auth_type")
local new_local_auth = ntop.getPref("ntopng.prefs.local.auth_enabled")
local new_ldap_auth = ntop.getPref("ntopng.prefs.ldap.auth_enabled")

if((not isEmptyString(old_auth_val)) and isEmptyString(new_ldap_auth) and isEmptyString(new_local_auth)) then
   if old_auth_val == "ldap" then
      ntop.setPref("ntopng.prefs.local.auth_enabled", "0")
      ntop.setPref("ntopng.prefs.ldap.auth_enabled", "1")
   elseif old_auth_val == "ldap_local" then
      ntop.setPref("ntopng.prefs.local.auth_enabled", "1")
      ntop.setPref("ntopng.prefs.ldap.auth_enabled", "1")
   end
end

-- ##################################################################

-- Remove the json dumps previously needed for alerts generation
for _, ifname in pairs(interface.getIfNames()) do
   interface.select(ifname)
   local ifid = getInterfaceId(ifname)

   local alerts_status_path = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/json/")
   ntop.rmdir(alerts_status_path)

   -- Remove the active devices and pools keys
   deleteActiveDevicesKey(ifid)
   deleteActivePoolsKey(ifid)

   -- Remove network discovery request on startup
   discover_utils.clearNetworkDiscovery(ifid)

   -- Note: we do not delete this as quotas are persistent across ntopng restart
   --deletePoolsQuotaExceededItemsKey(ifid)

   -- Clean old InfluxDB export cache
   local export_dir = os_utils.fixPath(dirs.workingdir .. "/".. ifid .."/ts_export")
   ntop.rmdir(export_dir)
end

-- ##################################################################

-- Initialize device policies (presets)
local presets_utils = require "presets_utils"
local ifid, ifname = getFirstInterfaceId()
interface.select(ifname)
presets_utils.init()
presets_utils.reloadAllDevicePolicies()

-- ##################################################################

-- Check remote assistance expiration
local remote_assistance = require "remote_assistance"
remote_assistance.checkAvailable()
remote_assistance.checkExpiration()

-- ##################################################################

local recording_utils = require "recording_utils"
recording_utils.checkAvailable()

-- ##################################################################

initCustomnDPIProtoCategories()
lists_utils.reloadLists() -- housekeeping will do the actual reload...

-- TODO: migrate custom re-arm settings

-- this will retrieve host pools and policers configurtions via HTTP if enabled
if  ntop.isnEdge() then
   local http_bridge_conf_utils = require "http_bridge_conf_utils"
   http_bridge_conf_utils.configureBridge()
end

processAlertNotifications(os.time(), 0, true --[[ force ]])
notify_ntopng_start()

if not recovery_utils.check_clean_shutdown() then
   package.path = dirs.installdir .. "/scripts/callbacks/system/?.lua;" .. package.path
   require("recovery")
end

recovery_utils.unmark_clean_shutdown()

-- Need to run setup at startup since the schemas may be changed
ts_utils.setupAgain()
