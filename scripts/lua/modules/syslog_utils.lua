--
-- (C) 2019-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_consts = require("alert_consts")
local alerts_api = require "alerts_api"
local companion_interface_utils = require "companion_interface_utils"

local syslog_utils = {}

-- #################################################################
  
local syslog_facility = {
   [0] = "kernel messages",
   [1] = "user-level messages",
   [2] = "mail system",
   [3] = "system daemons",
   [4] = "**security/authorization messages",
   [5] = "messages generated internally by syslog",
   [6] = "line printer subsystem",
   [7] = "network news subsystem",
   [8] = "UUCP subsystem",
   [9] = "clock daemon",
   [10] = "security/authorization messages",
   [11] = "FTP daemon",
   [12] = "NTP subsystem",
   [13] = "log audit",
   [14] = "log alert",
   [15] = "clock daemon",
}

------------------------------------------------------------------------

local syslog_level = {
   [0] = "EMERGENCY",
   [1] = "ALERT",
   [2] = "CRITICAL",
   [3] = "ERROR",
   [4] = "WARNING",
   [5] = "NOTICE",
   [6] = "INFORMATIONAL",
   [7] = "DEBUG",
}

------------------------------------------------------------------------

-- The function below returns a subtype for the log based on a simple hash
local function getLogSubtype(line)
   local hash = 0
   for i = 1, #line do
    hash = hash + line:byte(i)
   end
   return tostring(hash)
end

------------------------------------------------------------------------

function syslog_utils.handle_event(message, host, priority, level_threshold)
   -- Priority = Facility * 8 + Level
   local facility = math.floor(priority / 8)
   local level = priority - (facility * 8)

   local facility_name = syslog_facility[facility] or ""
   local level_name = syslog_level[level] or ""

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "[host="..host.."][facility="..facility_name.."][level="..level_name.."][message="..message.."]")

   -- Discard info messages
   if level_threshold and level <= level_threshold then

      local entity = alerts_api.hostAlertEntity(host, 0)

      local score = 10
      if level <= 3 then
         score = 100
      elseif level <= 4 then
         score = 50
      end

      local type_info = alert_consts.alert_types.host_alert_host_log.new(
         host,
         level_name,
         facility_name,
         message)
         
      type_info:set_subtype(getLogSubtype(message))
      type_info:set_score(score)

      -- Deliver alert
      type_info:store(entity)

         -- Deliver to companion if any
      local companion_of = companion_interface_utils.getCurrentCompanionOf(interface.getId())
      local curr_iface = tostring(interface.getId())
      for _, m in pairs(companion_of) do
         interface.select(m)
         type_info:store(entity)
      end
      interface.select(curr_iface)

      return true
   end

   return false
end

-- #################################################################

local function getProducersMapKey(ifid)
  return string.format("ntopng.syslog.ifid_%d.producers_map", ifid)
end

------------------------------------------------------------------------

function syslog_utils.getProducers(ifid)
  local key = getProducersMapKey(ifid)
  local providers = ntop.getHashAllCache(key) or {}

  local res = {}
  for host, producer in pairs(providers) do
    res[#res + 1] = {
      host = host,
      producer = producer,
      producer_title = i18n(producer.."_collector.title"),
    }
  end

  return res
end

------------------------------------------------------------------------

function syslog_utils.hasProducer(ifid, host)
  local key = getProducersMapKey(ifid)
  local producer_type = ntop.getHashCache(key, host)
  return not isEmptyString(producer_type) 
end

------------------------------------------------------------------------

function syslog_utils.addProducer(ifid, host, producer_type)
  local key = getProducersMapKey(ifid)
  ntop.setHashCache(key, host, producer_type) 
end

------------------------------------------------------------------------

function syslog_utils.deleteProducer(ifid, host)
  local key = getProducersMapKey(ifid)
  ntop.delHashCache(key, host)
end

------------------------------------------------------------------------

return syslog_utils
