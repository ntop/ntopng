--
-- (C) 2021 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local alert_severities = require "alert_severities"
local alert_entities = require "alert_entities"
local recording_utils = require "recording_utils"

local smart_recording = {
   name = "Smart Recording",
   conf_max_num = 1, -- At most 1 endpoint
   endpoint_params = {
   },
   endpoint_template = {
      script_key = "smart_recording",
      template_name = "smart_recording_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      script_key = "smart_recording",
      template_name = "smart_recording_recipient.template"
   },
}

-- ##############################################

function smart_recording.isAvailable()
   return recording_utils.isAvailable()
end

-- ##############################################

local function processHostAlert(alert)
   local instance = recording_utils.getN2diskInstanceName(alert.ifid)

   if isEmptyString(instance) or 
      isEmptyString(alert.ip) then
      return false
   end

   local filter = string.format("%s", alert.ip)

   local key = string.format("n2disk.%s.filter.host.%s", instance, filter)
   local expiration = 30*60 -- 30 min
   ntop.setCache(key, "1", expiration)

   return true
end

-- ##############################################

local function processFlowAlert(alert)
   local instance = recording_utils.getN2diskInstanceName(alert.ifid)

   if isEmptyString(instance) or 
      isEmptyString(alert.cli_ip) or
      isEmptyString(alert.srv_ip) then
      return false
   end

   local filter = string.format("%s,%s,%d,%d,%d",
      alert.cli_ip,
      alert.srv_ip,
      alert.cli_port or 0,
      alert.srv_port or 0,
      alert.proto or 0)

   local key = string.format("n2disk.%s.filter.tuple.%s", instance, filter)
   local expiration = 30*60 -- 30 min
   ntop.setCache(key, "1", expiration)

   return true
end

-- ##############################################

-- Dequeue alerts from a recipient queue for sending notifications
function smart_recording.dequeueRecipientAlerts(recipient, budget)
   local notifications = {}

   for i = 1, budget do
      local notification = ntop.recipient_dequeue(recipient.recipient_id)
      if notification and notification.alert then
         local alert = json.decode(notification.alert)
         if alert.entity_id == alert_entities.host.entity_id then
            processHostAlert(alert)
         elseif alert.entity_id == alert_entities.flow.entity_id then
            processFlowAlert(alert)
         end
      else
         break
      end
   end

   if not notifications or #notifications == 0 then
      return {success = true, more_available = false}
   end

   return {success = true,  more_available = true}
end

-- ##############################################

function smart_recording.runTest(recipient)
   local success = true
   local message_info = i18n("success")
   return success, message_info
end

-- ##############################################

return smart_recording
