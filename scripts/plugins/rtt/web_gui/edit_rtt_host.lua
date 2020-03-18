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

local rv = {
   success = false,
}

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

if not haveAdminPrivileges() then
   reportError("Not admin")
   return
end

-- ################################################

if((action == "add") or (action == "edit")) then
   local existing
   local rtt_value = _POST["rtt_max"] or 500
   local url

   if isEmptyString(host) then
      reportError("Missing 'host' parameter")
      return
   end

   url = measurement.."://"..host
   existing = rtt_utils.hasHost(url)

   if(existing and (action == "add")) then
      reportError("Host "..url.." is already existing")
      return
   end
   
   if(isValidHostMeasurementCombination(host, measurement) == false) then
      return
   end

   if existing then
      rv.error = i18n("rtt_stats.host_exists", {host=url})
   else
      rtt_utils.addHost(url, rtt_value)
      rv.success = true

      if(action == "edit") then
	 rv.message = "Host "..url.." was successful edited!"
      else
	 rv.message = "Host "..url.." was successful added!"
      end
   end
elseif(action == "delete") then
   local url      = rtt_utils.unescapeRttHost(_POST["rtt_url"])
   local existing = rtt_utils.hasHost(url)

   if not existing then
      rv.error = i18n("rtt_stats.host_not_exists", {host=url})
   else
      rtt_utils.deleteHost(url)
      rv.success = true
      rv.message = "The host was successful deleted!"
   end
else
   reportError("Bad action paramater")
   return
end

-- ################################################

rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
