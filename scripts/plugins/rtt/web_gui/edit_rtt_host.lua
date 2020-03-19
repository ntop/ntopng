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
	 reportError("Invalid measurement/host combination")
	 return(false)
      end
   end

   if(ntop.resolveHost(host, true) == nil) then
      reportError("Invalid host specified")
      return(false)
   end


   return(true)
end

-- ################################################

if isEmptyString(action) then
   reportError("Something went wrong (empty action). Try again.")
   return
end

if isEmptyString(host) then
   reportError("Missing 'rtt_host' parameter")
   return
end

if isEmptyString(measurement) then
   reportError("Missing 'measurement' parameter")
   return
end

if not haveAdminPrivileges() then
   reportError("Not admin")
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

   if(action == "edit") then
      rv.message = "Host "..url.." was successful edited!"
   else
      rv.message = "Host "..url.." was successful added!"
   end
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
      reportError("Missing 'old_rtt_host' parameter")
      return
   end

   if isEmptyString(old_measurement) then
      reportError("Missing 'old_measurement' parameter")
      return
   end

   existing = rtt_utils.hasHost(old_rtt_host, old_measurement)

   if not existing then
      local old_url = rtt_utils.formatRttHost(old_rtt_host, old_measurement)

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

   rv.message = "The host was successful modified!"
elseif(action == "delete") then
   local url = rtt_utils.formatRttHost(host, measurement)
   local existing = rtt_utils.hasHost(host, measurement)

   if not existing then
      reportError(i18n("rtt_stats.host_not_exists", {host=url}))
   end

   rtt_utils.deleteHost(host, measurement)
   rv.message = "The host was successful deleted!"
else
   reportError("Bad action paramater")
   return
end

-- ################################################

rv.success = true
rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
