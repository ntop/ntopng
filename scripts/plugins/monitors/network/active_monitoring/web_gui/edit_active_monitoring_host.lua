--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
local auth = require "auth"

sendHTTPContentTypeHeader('application/json')

-- ################################################

local action      = _POST["action"]
local host        = _POST["am_host"]
local measurement = _POST["measurement"]
local pool        = _POST["pool"]
local ifname = _POST["ifname"]

local rv = {}

local function reportError(msg)
   print(json.encode({ error = msg, success = false}))
end

local function isValidHostMeasurementCombination(host, measurement)
   -- Strips the prefix (either http:// or https://) and a possible port

   -- Extract the domain, e.g.,
   -- http://user:password@www.example.com/p1/p2 becomes www.example.com
   -- http://www.example.com:3000/p1/p2 becomes www.example.com

   -- See if domain has user and password encoded, i.e.,
   -- http://user:password@www.example.com becomes www.example.com
   local domain = host:match('^%w+://[^:]+:[^@]+@([^/:]+)')

   if not domain then
      -- Domain has no user and password encoded, i.e.,
      -- http://www.example.com:3000/p1/p2
      domain = host:match('^%w+://([^/:]+)')
   end

   -- Take the domain (if found) or the host as-is
   host = domain or host

   local host_v4 = isIPv4(host)
   local host_v6 = isIPv6(host)

   if not host_v4 and not host_v6 then
      -- Host is a domain, try to resolve it as ipv4, then ipv6
      if ntop.resolveHost(host, true) then
	 -- Valid Host
	 return(true)
      elseif ntop.resolveHost(host, false) then
	 -- Valid Host
	 return(true)
      else
	 reportError(i18n("active_monitoring_stats.invalid_host"))
	 return(false)
      end
   end

   return(true)
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

if not auth.has_capability(auth.capabilities.active_monitoring) then
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
      local measurement_info = am_utils.getMeasurementInfo(measurement)
      reportError(i18n("active_monitoring_stats.host_exists", {measurement = i18n(measurement_info.i18n_label), host = url}))
      return
   end

   am_utils.addHost(host, ifname, measurement, threshold, granularity, pool)
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

   existing = am_utils.getHost(old_am_host, old_measurement)

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
      am_utils.addHost(host, ifname, measurement, threshold, granularity, pool)
   else
      -- The key is the same, only update its settings
      am_utils.editHost(host, ifname, measurement, threshold, granularity, pool)
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
print(json.encode(rv))
