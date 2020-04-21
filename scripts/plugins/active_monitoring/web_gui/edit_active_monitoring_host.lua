--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local action      = _POST["action"]
local host        = _POST["am_host"]
local measurement = _POST["measurement"]

local rv = {}

local function reportError(msg)
   print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local function isValidHostMeasurementCombination(host, measurement)
   local host_v4 = isIPv4(host)
   local host_v6 = isIPv6(host)
   local expected_ipv = ternary((measurement == "icmp6"), 6, 4)

   if(((expected_ipv == 6) and host_v6) or
	 ((expected_ipv == 4) and host_v4)) then
      -- IP address version matches
      return(true)
   elseif(((expected_ipv == 6) and host_v4) or
	  ((expected_ipv == 4) and host_v6)) then
      reportError(i18n("active_monitoring_stats.invalid_combination"))
      return(false)
   end

   -- Host is a domain, try to resolve it to validate it
   if(ntop.resolveHost(host, ternary((expected_ipv == 4), true, false)) ~= nil) then
      -- Valid Host
      return(true)
   end

   reportError(i18n("active_monitoring_stats.invalid_host"))
   return(false)
end
-- ################################################

if isEmptyString(action) then
   reportError(i18n("active_monitoring_stats.empty_action"))
   return
end

if isEmptyString(host) then
   reportError(i18n("missing_x_parameter", {param='am_host'}))
   return
end

if isEmptyString(measurement) then
   reportError(i18n("missing_x_parameter", {param='measurement'}))
   return
end

if not haveAdminPrivileges() then
   reportError(i18n("not_admin"))
   return
end

-- ################################################

if(action == "add") then
   local existing
   local threshold = _POST["threshold"]
   local granularity = _POST["granularity"]
   local url = am_utils.formatAmHost(host, measurement)

   if(isValidHostMeasurementCombination(host, measurement) == false) then
      -- NOTE: reportError already called
      return
   end

   existing = am_utils.hasHost(host, measurement)

   if existing then
      reportError(i18n("active_monitoring_stats.host_exists", {host=url}))
      return
   end

   am_utils.addHost(host, measurement, threshold, granularity)
   rv.message = i18n("active_monitoring_stats.host_add_ok", {host=url})
elseif(action == "edit") then
   local existing
   local threshold = _POST["threshold"]
   local granularity = _POST["granularity"]
   local url = am_utils.formatAmHost(host, measurement)
   local old_am_host = _POST["old_am_host"]
   local old_measurement = _POST["old_measurement"]
   local old_granularity = _POST["old_granularity"]

   if(isValidHostMeasurementCombination(host, measurement) == false) then
      -- NOTE: reportError already called
      return
   end

   if isEmptyString(old_am_host) then
      reportError(i18n("missing_x_parameter", {param='old_am_host'}))
      return
   end

   if isEmptyString(old_measurement) then
      reportError(i18n("missing_x_parameter", {param='old_measurement'}))
      return
   end

   if isEmptyString(old_granularity) then
      reportError(i18n("missing_x_parameter", {param='old_granularity'}))
      return
   end

   local old_url = am_utils.formatAmHost(old_am_host, old_measurement)

   existing = am_utils.hasHost(old_am_host, old_measurement)

   if not existing then
      reportError(i18n("active_monitoring_stats.host_not_exists", {host=old_url}))
      return
   end

   if((old_am_host ~= host) or (old_measurement ~= measurement)) then
      -- The key has changed, delete the old host and create a new one
      existing = am_utils.hasHost(host, measurement)

      if existing then
	 reportError(i18n("active_monitoring_stats.host_exists", {host=url}))
	 return
      end

      am_utils.deleteHost(old_am_host, old_measurement) -- also calls discardHostTimeseries
      am_utils.addHost(host, measurement, threshold, granularity)
   else
      -- The key is the same, only update the value/granularity
      if(old_granularity ~= granularity) then
	 -- Need to discard the old timeseries as the granularity has changed
	 am_utils.discardHostTimeseries(host, measurement)
      end

      am_utils.addHost(host, measurement, threshold, granularity)

      local m_info = am_utils.getMeasurementInfo(measurement)
      local last_update = am_utils.getLastAmUpdate(host, measurement)

      if m_info and last_update then
	 -- Recheck the threshold
	 local key = am_utils.getAmHostKey(host, measurement)
	 local value = last_update.value
	 threshold = tonumber(threshold)

	 -- NOTE: system interface must be manually sected and then unselected
	 local old_iface = tostring(interface.getId())
	 interface.select(getSystemInterfaceId())

    -- Always release the old alert because:
    --  - If the granularity has changed, since the alert is bound to a specific granularity, it must be released
    --  - If the threshold has changed, we want to change the threshold in the alert message (if engaged)
    am_utils.releaseAlert(last_update.ip, key, value, threshold, old_granularity)

	 if am_utils.hasExceededThreshold(threshold, m_info.operator, value) then
	    am_utils.triggerAlert(last_update.ip, key, value, threshold, granularity)
	 end

	 interface.select(old_iface)
      end
   end

   rv.message = i18n("active_monitoring_stats.host_edit_ok", {host=old_url})
elseif(action == "delete") then
   local url = am_utils.formatAmHost(host, measurement)
   local existing = am_utils.hasHost(host, measurement)

   if not existing then
      reportError(i18n("active_monitoring_stats.host_not_exists", {host=url}))
   end

   am_utils.deleteHost(host, measurement)
   rv.message = i18n("active_monitoring_stats.host_delete_ok", {host=url})
else
   reportError(i18n("active_monitoring_stats.bad_action_param"))
   return
end

-- ################################################

rv.success = true
rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
