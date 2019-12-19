--
-- (C) 2013-18 - ntop.org
--

--
-- This script is executed once at startup similar to /etc/rc.local on Unix
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require("startup")
end

require "lua_utils"

-- Important: load this before any other alert related module
local plugins_utils = require "plugins_utils"
plugins_utils.loadPlugins()

require "alert_utils"

local discover_utils = require "discover_utils"
local host_pools_utils = require "host_pools_utils"
local os_utils = require "os_utils"
local lists_utils = require "lists_utils"
local recovery_utils = require "recovery_utils"
local delete_data_utils = require "delete_data_utils"
local ts_utils = require "ts_utils"
local user_scripts = require("user_scripts")
local presets_utils = require "presets_utils"
local prefs = ntop.getPrefs()

host_pools_utils.initPools()

if(ntop.isPro()) then
   shaper_utils = require "shaper_utils"
   shaper_utils.initShapers()
end

-- Load the default user scripts configuration
user_scripts.loadDefaultConfig()

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

local has_pcap_dump_interface = false

local function cleanupIfname(ifname)
   interface.select(ifname)
   local ifid = getInterfaceId(ifname)

   if interface.isPcapDumpInterface() then
      has_pcap_dump_interface = true
   end

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

-- Remove the json dumps previously needed for alerts generation
for _, ifname in pairs(interface.getIfNames()) do
   cleanupIfname(ifname)
end
cleanupIfname(getSystemInterfaceName())

-- Also flush the export queue
ntop.delCache("ntopng.influx_file_queue")

-- ##################################################################

-- Check remote assistance expiration
local remote_assistance = require "remote_assistance"
remote_assistance.checkAvailable()
remote_assistance.checkExpiration()

-- ##################################################################

local recording_utils = require "recording_utils"
recording_utils.checkAvailable()

-- ##################################################################

local companion_interface_utils = require "companion_interface_utils"
companion_interface_utils.initCompanions()

-- ##################################################################

lists_utils.clearErrors()
lists_utils.downloadLists()
lists_utils.reloadLists()
-- Need to do the actual reload also here as otherwise some
-- flows may be misdetected until housekeeping.lua is executed
lists_utils.checkReloadLists()

-- ##################################################################

-- Initialize device policies (presets)
-- NOTE: Must go after lists_utils initialization and reload
-- as new custom protocols can be set by lists utils
presets_utils.init()
presets_utils.reloadAllDevicePolicies()

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

-- Migrate "iface:ndpi_categories" under the correct folder
if(ntop.getCache("ntopng.cache.rrd_category_migration") ~= "1") then
   for ifid, ifname in pairs(delete_data_utils.list_all_interfaces()) do
      ntop.mkdir(dirs.workingdir .. "/" .. ifid .. "/rrd/ndpi_categories")

      for cat_name, cat_id in pairs(interface.getnDPICategories()) do
         local old_path = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/rrd/"..cat_name..".rrd")

         if ntop.exists(old_path) then
            local new_path = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/rrd/ndpi_categories/"..cat_name..".rrd")

            traceError(TRACE_INFO, TRACE_CONSOLE, "Migrating Category RRD: " .. old_path)
            os.rename(old_path, new_path)
         end
      end
   end

   -- do not perform migration again
   ntop.setCache("ntopng.cache.rrd_category_migration", "1")
end

if(has_pcap_dump_interface) then
  -- Load the lists at the very beginning in order to avoid misclassification
  -- when reading from PCAP dump. This can take some time.
  traceError(TRACE_NORMAL, TRACE_CONSOLE, "Loading category lists...")
  lists_utils.checkReloadLists()
  traceError(TRACE_NORMAL, TRACE_CONSOLE, "Loading category lists done")
end

-- Show the warning at most 1 time per run
ntop.delCache("ntopng.cache.rrd_format_change_warning_shown")
