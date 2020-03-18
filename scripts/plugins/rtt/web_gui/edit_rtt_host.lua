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
   print(json.encode({ error = msg, success = false }))   
end

local function isValidHostMeasurementCombination(host, measurement)
   -- print("isValidHostMeasurementCombination("..host..","..measurement..")\n")
   if((measurement == "icmp6") and not(isIPv6(host))) then return(false) end
   
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

if(action == "add") then
   local existing = rtt_utils.hasHost(url)
   local rtt_value = _POST["rtt_max"] or 500
   local url = measurement.."://"..host
   
   if isEmptyString(host) then
      reportError("Missing 'host' parameter")
      return
   end
   
   if(isValidHostMeasurementCombination(host, measurement) == false) then
      reportError("Invalid measurement/host combination")
      return
   end

   if existing then
      rv.error = i18n("rtt_stats.host_exists", {host=url})
   else
      rtt_utils.addHost(url, rtt_value)
      rv.success = true
      rv.message = "The host ("..url..", "..rtt_value..") was successful added !"
   end
elseif(action == "edit") then
   local existing = rtt_utils.hasHost(url)
   local url = measurement.."://"..host

   if isEmptyString(host) then
      reportError("Missing 'host' parameter")
      return
   end
   
   if(isValidHostMeasurementCombination(host, measurement) == false) then
      reportError("Invalid measurement/host combination")
      return
   end

   if not existing then
      rv.error = i18n("rtt_stats.host_not_exists", {host=url})
   else
      local rtt_value = _POST["rtt_max"] or 100

      rtt_utils.addHost(url, rtt_value)
      rv.success = true
      rv.message = "The host was successful edited!"
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
   print(json.encode({
	       error = "Bad action paramater",
	       success = false
   }))
   return
end

-- ################################################

rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
