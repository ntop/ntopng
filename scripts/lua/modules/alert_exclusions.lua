--
-- (C) 2017-21 - ntop.org
--
-- Module to keep things in common across alert_exclusions of various type

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_consts = require "alert_consts"
local json = require "dkjson"

-- ##############################################

local alert_exclusions = {}

-- ##############################################

local function _get_alert_exclusions_prefix_key()
   local key = string.format("ntopng.prefs.alert_exclusions")

   return key
end

-- ##############################################

local function _get_alert_exclusions_lock_key()
   local key = string.format("ntopng.cache.alert_exclusions.alert_exclusions_lock")

   return key
end

-- ##############################################

local function _lock()
   local max_lock_duration = 5 -- seconds
   local max_lock_attempts = 5 -- give up after at most this number of attempts
   local lock_key = _get_alert_exclusions_lock_key()

   for i = 1, max_lock_attempts do
      local value_set = ntop.setnxCache(lock_key, "1", max_lock_duration)

      if value_set then
	 return true -- lock acquired
      end

      ntop.msleep(1000)
   end

   return false -- lock not acquired
end

-- ##############################################

local function _unlock()
   ntop.delCache(_get_alert_exclusions_lock_key())
end

-- ##############################################

local function _check_host_ip_alert_key(host_ip, alert_key)
   if not isIPv4(host_ip) and not isIPv6(host_ip) then
      -- Invalid host submitted
      return false
   end

   if not alert_consts.alertTypeRaw(tonumber(alert_key)) then
      -- Invalid alert key submitted
      return false
   end

   return true
end

-- ##############################################

local function _get_configured_alert_exclusions()
   local excl_key = _get_alert_exclusions_prefix_key()
   local configured_excl_str = ntop.getPref(excl_key)
   local configured_excl = json.decode(configured_excl_str) or {}

   return configured_excl
end

-- ##############################################

local function _set_configured_alert_exclusions(exclusions)
   local excl_key = _get_alert_exclusions_prefix_key()

   ntop.setPref(excl_key, json.encode(exclusions)) -- Add the preference
   ntop.reloadAlertExclusions()                    -- Tell ntopng to reload
end

-- ##############################################

--@brief Enables or disables an alert for an `host_ip`
local function _toggle_alert(host_ip, alert_key, disable)
   local ret = false

   if not _check_host_ip_alert_key(host_ip, alert_key) then
      -- Invalid params submitted
      return false
   end

   local locked = _lock()

   if locked then
      -- In JSON, keys are always strings
      alert_key = tostring(alert_key)
      local do_persist = false
      local exclusions = _get_configured_alert_exclusions()

      -- Add an entry for the current alert key, if currently existing exclusions don't already have it
      if not exclusions[alert_key] then
	 exclusions[alert_key] = {excluded_hosts = {}}
      end

      -- Add an entry for excluded_hosts, if the currently existing exclusions don't already have it
      if not exclusions[alert_key]["excluded_hosts"] then
	 exclusions[alert_key]["excluded_hosts"] = {}
      end

      -- Now check if there is actually some work to do
      if not disable and exclusions[alert_key]["excluded_hosts"][host_ip] then
	 -- Enable an host_ip that was disabled
	 exclusions[alert_key]["excluded_hosts"][host_ip] = nil
	 do_persist = true
      elseif disable and not exclusions[alert_key]["excluded_hosts"][host_ip] then
	 -- Disable an host_ip that was not already disabled
	 exclusions[alert_key]["excluded_hosts"][host_ip] = { --[[ Currently empty, will possibly contain values in the future, e.g., as_cli, as_srv--]]}
	 do_persist = true
      end

      if do_persist then
	 _set_configured_alert_exclusions(exclusions)
      end

      ret = true
      _unlock()
   end

   return ret
end

-- ##############################################

--@brief Marks an alert as disabled for a given `host_ip`
--@return True, if alert is disabled with success, false otherwise
function alert_exclusions.disable_alert(host_ip, alert_key)
   return _toggle_alert(host_ip, alert_key, true --[[ disable --]])
end

-- ##############################################

--@brief Marks an alert as enabled for a given `host_ip`
--@return True, if alert is enabled with success, false otherwise
function alert_exclusions.enable_alert(host_ip, alert_key)
   return _toggle_alert(host_ip, alert_key, false --[[ enable --]])
end

-- ##############################################

-- @brief Returns true if `host_ip` has the alert identified with `alert_key` disabled
function alert_exclusions.has_disabled_alert(host_ip, alert_key)
   local exclusions = _get_configured_alert_exclusions()
   alert_key = tostring(alert_key)

   return not not (exclusions[alert_key] and exclusions[alert_key]["excluded_hosts"] and exclusions[alert_key]["excluded_hosts"][host_ip])
end

-- ##############################################

-- @brief Delete all alert_exclusions
function alert_exclusions.cleanup()
   local locked = _lock()

   if locked then
      local excl_key = _get_alert_exclusions_prefix_key()

      ntop.delCache(excl_key)
      ntop.reloadAlertExclusions() -- Tell ntopng to reload

      _unlock()
   end
end

-- ##############################################

return alert_exclusions
