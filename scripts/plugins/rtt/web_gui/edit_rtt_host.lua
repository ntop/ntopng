--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rtt_utils = require("rtt_utils")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local action      = _POST["action"]
local host        = _POST["rtt_host"]
local measurement = _POST["measurement"]

local rv = {}

local function reportError(msg)
   print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local function isValidHostMeasurementCombination(host, measurement)
   if((measurement == "icmp6") and not(isIPv6(host))) then
      if(ntop.resolveHost(host, false) == nil) then
	 return(true)
      else
	 reportError(i18n("rtt_stats.invalid_combination"))
	 return(false)
      end
   end

   if(ntop.resolveHost(host, true) == nil) then
      reportError(i18n("rtt_stats.invalid_host"))
      return(false)
   end


   return(true)
end

-- ################################################

if isEmptyString(action) then
   reportError(i18n("rtt_stats.empty_action"))
   return
end

if isEmptyString(host) then
   reportError(i18n("missing_x_parameter", {param='rtt_host'}))
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
   local rtt_value = _POST["rtt_max"] or 500
   local url = rtt_utils.formatRttHost(host, measurement)

   if(isValidHostMeasurementCombination(host, measurement) == false) then
      -- NOTE: reportError already called
      return
   end

   existing = rtt_utils.hasHost(host, measurement)

   if existing then
      reportError(i18n("rtt_stats.host_exists", {host=url}))
      return
   end

   rtt_utils.addHost(host, measurement, rtt_value)
   rv.message = i18n("rtt_stats.host_add_ok", {host=url})
elseif(action == "edit") then
   local existing
   local rtt_value = _POST["rtt_max"] or 500
   local url = rtt_utils.formatRttHost(host, measurement)
   local old_rtt_host = _POST["old_rtt_host"]
   local old_measurement = _POST["old_measurement"]

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

   local old_url = rtt_utils.formatRttHost(old_rtt_host, old_measurement)

   existing = rtt_utils.hasHost(old_rtt_host, old_measurement)

   if not existing then
      reportError(i18n("rtt_stats.host_not_exists", {host=old_url}))
      return
   end

   if((old_rtt_host ~= host) or (old_measurement ~= measurement)) then
      -- The key has changed, delete the old host and create a new one
      existing = rtt_utils.hasHost(host, measurement)

      if existing then
	 reportError(i18n("rtt_stats.host_exists", {host=url}))
	 return
      end

      rtt_utils.deleteHost(old_rtt_host, old_measurement)
      rtt_utils.addHost(host, measurement, rtt_value)
   else
      -- The key is the same, only update the rtt
      rtt_utils.addHost(host, measurement, rtt_value)
   end

   rv.message = i18n("rtt_stats.host_edit_ok", {host=old_url})
elseif(action == "delete") then
   local url = rtt_utils.formatRttHost(host, measurement)
   local existing = rtt_utils.hasHost(host, measurement)

   if not existing then
      reportError(i18n("rtt_stats.host_not_exists", {host=url}))
   end

   rtt_utils.deleteHost(host, measurement)
   rv.message = i18n("rtt_stats.host_delete_ok", {host=url})
else
   reportError(i18n("rtt_stats.bad_action_param"))
   return
end

-- ################################################

rv.success = true
rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
