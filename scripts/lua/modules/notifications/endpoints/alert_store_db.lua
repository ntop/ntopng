--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_keys/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local other_alert_keys = require "other_alert_keys"
local alert_entities = require "alert_entities"

local alert_store_db = {
   name = "DataBase",
   builtin = true, -- Whether this endpoint can be configured from the UI. Disabled for the builtin alert store

   endpoint_params = {
      -- No params, alert store is builtin
   },
   endpoint_template = {
      script_key = "alert_store_db",
      template_name = "alert_store_db_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      script_key = "alert_store_db",
      template_name = "alert_store_db_recipient.template"
   },
}

alert_store_db.EXPORT_FREQUENCY = 1
alert_store_db.prio = 400

-- ##############################################

local function recipient2sendMessageSettings(recipient)
   local settings = {
      -- builtin
  }

   return settings
end

local debugme = false

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

function alert_store_db.dequeueRecipientAlerts(recipient, budget)
   local more_available = true
   local budget_used = 0

   local success = true
   local error_message = nil
   local delivered = 0
   local discarded = 0
   local failures = 0

   -- Now also check for alerts pushed by checks from Lua
   -- Dequeue alerts up to budget
   -- Note: in this case budget is the number of alert_store_db alerts to insert into the queue
   while budget_used <= budget and more_available do
      local notifications = {}

      for i=1, budget do
         local notification = ntop.recipient_dequeue(recipient.recipient_id)

         if(debugme) then tprint(notification) end
         
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
         if alert then
            local alert_store = get_alert_store(alert.entity_id)
            if alert_store then

               interface.select(string.format("%d", alert.ifid or 0))

               if alert.action == "engage" then
                  -- Add to the in-memory table (in addition to the C++ data structures)
                  alert_store:insert_engaged(alert)

               else -- alert.action == "release"
                  -- Remove from the in-memory table if previously engaged
                  if alert.alert_id ~= 4 then -- Not alert_entity_flow (historical only)
                     alert_store:delete_engaged(alert)
                  end

                  -- Add to the historical table
                  alert_store:insert(alert)

                  if(debugme) then io.write("Stored alert in alert.entity_id "..alert.entity_id) end
               end

               delivered = delivered + #notifications

            else
               if(debugme) then io.write("Unable to find alert.entity_id "..alert.entity_id) end
            end
         end
      end

      -- Remove the processed messages from the queue
      budget_used = budget_used + #notifications
   end

 ::done::
   return {
      success = success,
      error_message = error_message,
      delivered = delivered,
      discarded = discarded,
      failures  = failures,
      more_available = more_available,
  }
end

-- ##############################################

function alert_store_db.runTest(recipient)
  local alert_store = get_alert_store(alert_entities.system.entity_id)

  local dummy_alert = {
    alert_id = other_alert_keys.alert_test,
    tstamp = os.time(),
    tstamp_end = os.time(),
    score = 100,
    entity_val = "",
    granularity = 0,
    json = "{}",
    require_attention = true
  }

  local success = alert_store:insert(dummy_alert)

  local msg
  if success then
    msg = i18n("alert_messages.database_test_success")
  else
    msg = i18n("alert_messages.database_test_failure")
  end

  return success, msg
end

-- ##############################################

return alert_store_db
