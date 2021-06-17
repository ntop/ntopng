--
-- (C) 2021 - ntop.org
--

package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"

local sqlite = {
   name = "SQLite",
   builtin = true, -- Whether this endpoint can be configured from the UI. Disabled for the builtin SQLite

   endpoint_params = {
      -- No params, SQLite is builtin
   },
   endpoint_template = {
      plugin_key = "sqlite_alert_endpoint",
      template_name = "sqlite_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "sqlite_alert_endpoint",
      template_name = "sqlite_recipient.template"
   },
}

sqlite.EXPORT_FREQUENCY = 1
sqlite.prio = 400

-- ##############################################

local function recipient2sendMessageSettings(recipient)
   local settings = {
      -- builtin
  }

   return settings
end


-- ##############################################

-- Cache alert store to avoid always allocating new instances
local cached_alert_store = {}

local function get_alert_store(entity_id)
   local alert_entity = alert_consts.alertEntityById(entity_id)
   if not alert_entity then
      return nil
   end

   local alert_store_name = alert_entity.alert_store_name
   if not cached_alert_store[alert_store_name] then
      local alert_store = require(alert_store_name.."_alert_store").new()
      cached_alert_store[alert_store_name] = alert_store
   end

   return cached_alert_store[alert_store_name]
end

-- ##############################################

function sqlite.dequeueRecipientAlerts(recipient, budget, high_priority)
   local more_available = true
   local budget_used = 0

   -- Now also check for alerts pushed by checks from Lua
   -- Dequeue alerts up to budget
   -- Note: in this case budget is the number of sqlite alerts to insert into the queue
   while budget_used <= budget and more_available do
      local notifications = {}

      for i=1, budget do
         local notification = ntop.recipient_dequeue(recipient.recipient_id, high_priority)
         if notification then
	    notifications[#notifications + 1] = notification.alert
         else
	    break
         end
      end

      if not notifications or #notifications == 0 then
         more_available = false
         break
      end

      for _, json_message in ipairs(notifications) do
         local alert = json.decode(json_message)

         if alert.action ~= "engage" then
	    -- Do not store alerts engaged - they're are handled only in-memory

	    if(alert) then
	       interface.select(string.format("%d", alert.ifid))

               local alert_store = get_alert_store(alert.entity_id)
               if alert_store then
                  alert_store:insert(alert)
               end
	    end
   
         end
      end

      -- Remove the processed messages from the queue
      budget_used = budget_used + #notifications
   end

   return {success = true, more_available = more_available}
end

-- ##############################################

function sqlite.runTest(recipient)
  return false, "Not implemented"
end

-- ##############################################

return sqlite
