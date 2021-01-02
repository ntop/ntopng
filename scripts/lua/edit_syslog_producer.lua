--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local syslog_utils = require("syslog_utils")
local syslog_utils = require "syslog_utils"

sendHTTPContentTypeHeader('application/json')

local rv = {}

-- ################################################

local action = _POST["action"]
local host = _POST["syslog_producer_host"]
local syslog_producer = _POST["syslog_producer"]

local ifid = interface.getId()
if tonumber(_GET["ifid"]) ~= nil then
  ifid = _GET["ifid"]
end

-- ################################################

local function getProducersMapKey(ifid)
  return string.format("ntopng.syslog.ifid_%d.producers_map", ifid)
end

local function reportError(msg)
  print(json.encode({ error = msg, success = false }))
end

-- ################################################

if not isAdministrator() then
  reportError(i18n("not_admin"))
  return
end

if ifid == nil then
  reportError(i18n("syslog.empty_action"))
  return 
end

if isEmptyString(action) then
  reportError(i18n("syslog.empty_action"))
  return
end

if isEmptyString(host) then
  reportError(i18n("missing_x_parameter", {param='syslog_producer_host'}))
  return
end

if isEmptyString(syslog_producer) then
  reportError(i18n("missing_x_parameter", {param='syslog_producer'}))
  return
end

-- ################################################

if(action == "add") then
   local existing

   local existing = syslog_utils.hasProducer(ifid, host)

   if existing then
      reportError(i18n("syslog.host_exists", {host=host}))
      return
   end

   syslog_utils.addProducer(ifid, host, syslog_producer)
   rv.message = i18n("syslog.host_add_ok", {host=host})

elseif(action == "edit") then
   local existing
   local old_host = _POST["old_syslog_producer_host"]
   local old_syslog_producer = _POST["old_syslog_producer"]

   if isEmptyString(old_host) then
      reportError(i18n("missing_x_parameter", {param='old_syslog_producer_host'}))
      return
   end

   if isEmptyString(old_syslog_producer) then
      reportError(i18n("missing_x_parameter", {param='old_syslog_producer'}))
      return
   end

   existing = syslog_utils.hasProducer(ifid, old_host)

   if not existing then
      reportError(i18n("syslog.host_not_exists", {host=old_host}))
      return
   end

   if old_host ~= host or old_syslog_producer ~= syslog_producer then

      if old_host ~= host then
        existing = syslog_utils.hasProducer(ifid, host, syslog_producer)

        if existing then
	  reportError(i18n("syslog.host_exists", {host=host}))
	  return
        end
      end

      syslog_utils.deleteProducer(ifid, old_host, old_syslog_producer)
      syslog_utils.addProducer(ifid, host, syslog_producer)
   end

   rv.message = i18n("syslog.host_edit_ok", {host=old_host})

elseif(action == "delete") then
   local existing = syslog_utils.hasProducer(ifid, host, syslog_producer)

   if not existing then
      reportError(i18n("syslog.host_not_exists", {host=host}))
      return
   end

   syslog_utils.deleteProducer(ifid, host, syslog_producer)
   rv.message = i18n("syslog.host_delete_ok", {host=host})

else
   reportError(i18n("syslog.bad_action_param"))
   return
end

-- ################################################

interface.updateSyslogProducers()

rv.success = true
print(json.encode(rv))

