--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

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
   local rtt_value = _POST["rtt_max"]
   local granularity = _POST["granularity"]
   local url = active_monitoring_utils.formatRttHost(host, measurement)

   if(isValidHostMeasurementCombination(host, measurement) == false) then
      -- NOTE: reportError already called
      return
   end

   existing = active_monitoring_utils.hasHost(host, measurement)

   if existing then
      reportError(i18n("active_monitoring_stats.host_exists", {host=url}))
      return
   end

   active_monitoring_utils.addHost(host, measurement, rtt_value, granularity)
   rv.message = i18n("active_monitoring_stats.host_add_ok", {host=url})
elseif(action == "edit") then
   local existing
   local rtt_value = _POST["rtt_max"]
   local granularity = _POST["granularity"]
   local url = active_monitoring_utils.formatRttHost(host, measurement)
   local old_rtt_host = _POST["old_rtt_host"]
   local old_measurement = _POST["old_measurement"]
   local old_granularity = _POST["old_granularity"]

   if(isValidHostMeasurementCombination(host, measurement) == false) then
      -- NOTE: reportError already called
      return
   end

   if isEmptyString(old_rtt_host) then
      reportError(i18n("missing_x_parameter", {param='old_rtt_host'}))
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

   local old_url = active_monitoring_utils.formatRttHost(old_rtt_host, old_measurement)

   existing = active_monitoring_utils.hasHost(old_rtt_host, old_measurement)

   if not existing then
      reportError(i18n("active_monitoring_stats.host_not_exists", {host=old_url}))
      return
   end

   if((old_rtt_host ~= host) or (old_measurement ~= measurement)) then
      -- The key has changed, delete the old host and create a new one
      existing = active_monitoring_utils.hasHost(host, measurement)

      if existing then
	 reportError(i18n("active_monitoring_stats.host_exists", {host=url}))
	 return
      end

      active_monitoring_utils.deleteHost(old_rtt_host, old_measurement) -- also calls discardHostTimeseries
      active_monitoring_utils.addHost(host, measurement, rtt_value, granularity)
   else
      -- The key is the same, only update the rtt/granularity
      if(old_granularity ~= granularity) then
	 -- Need to discard the old timeseries as the granularity has changed
	 active_monitoring_utils.discardHostTimeseries(host, measurement)
      end

      active_monitoring_utils.addHost(host, measurement, rtt_value, granularity)
   end

   rv.message = i18n("active_monitoring_stats.host_edit_ok", {host=old_url})
elseif(action == "delete") then
   local url = active_monitoring_utils.formatRttHost(host, measurement)
   local existing = active_monitoring_utils.hasHost(host, measurement)

   if not existing then
      reportError(i18n("active_monitoring_stats.host_not_exists", {host=url}))
   end

   active_monitoring_utils.deleteHost(host, measurement)
   rv.message = i18n("active_monitoring_stats.host_delete_ok", {host=url})
else
   reportError(i18n("active_monitoring_stats.bad_action_param"))
   return
end

-- ################################################

rv.success = true
rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
