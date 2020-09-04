--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local json = require "dkjson"
local notification_configs = require("notification_configs")
local alert_consts = require("alert_consts")
local do_trace = false

-- #################################################################

local ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG = "ntopng.prefs.notification_endpoint.endpoint_recipient_to_endpoint_conf"
local ENDPOINT_RECIPIENTS_KEY = "ntopng.prefs.notification_endpoint.endpoint_config_%s.recipients"
local RECIPIENT_QUEUE_KEY = "ntopng.alerts.notification_recipient_queue.%s"
local RECIPIENT_NEXT_EXPORT_TIME_KEY = "ntopng.cache.notification_recipient_export_time.%s"

-- #################################################################

local notification_recipients = {}

-- #################################################################

local function get_endpoint_recipient_queue(endpoint_recipient_name)
   local k = string.format(RECIPIENT_QUEUE_KEY, endpoint_recipient_name)
   return k
end

-- #################################################################

local function check_endpoint_export(endpoint_recipient_name, export_frequency)
   local k = string.format(RECIPIENT_NEXT_EXPORT_TIME_KEY, endpoint_recipient_name)
   local cached_val = tonumber(ntop.getCache(k))

   if cached_val then
      -- Cached key exists. TTL not eached, not yet time to export
      -- tprint({endpoint_recipient_name, "cached"})
      return false
   else
      -- Cached key doesn't exists: TTL has expired
      -- Set the cache with TTL equal to the export_frequency and do the export!

      ntop.setCache(k, "1", export_frequency)
      -- tprint({endpoint_recipient_name, "time to export!!"})
      return true
   end
end

-- #################################################################

-- @brief Check if an endpoint configuration with name `endpoint_recipient_name` exists
-- @param endpoint_recipient_name A string with the endpoint recipient name
-- @return true if the configuration exists, false otherwise
local function is_endpoint_recipient_existing(endpoint_recipient_name)
   if not endpoint_recipient_name or endpoint_recipient_name == "" then
      return false
   end

   local res = ntop.getHashCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG, endpoint_recipient_name)

   if res == nil or res == '' then
      return false
   end

   return true
end

-- #################################################################

-- @brief Read the recipient configuration parameters of an existing configuration
-- @param endpoint_recipient_name A string with the configuration endpoint recipient name
-- @return A table with two keys: endpoint_conf_name and recipient_params or nil if the configuration isn't found
local function read_endpoint_recipient_raw(endpoint_recipient_name)
   local endpoint_conf_name = ntop.getHashCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG, endpoint_recipient_name)

   local k = string.format(ENDPOINT_RECIPIENTS_KEY, endpoint_conf_name)
   local recipient_params = ntop.getHashCache(k, endpoint_recipient_name)

   if recipient_params and recipient_params ~= '' then
      return {endpoint_conf_name = endpoint_conf_name, recipient_params = recipient_params}
   end
end

-- #################################################################

local function check_endpoint_recipient_name(endpoint_recipient_name)
   if not endpoint_recipient_name or endpoint_recipient_name == "" then
      return false, {status = "failed", error = {type = "invalid_endpoint_recipient_name"}}
   end

   return true
end

-- #################################################################

-- @brief Set a configuration along with its params. Configuration name and params must be already sanitized
-- @param endpoint_conf_name A string with the notification endpoint configuration name
-- @param endpoint_recipient_name A string with the recipient name
-- @param safe_params A table with endpoint recipient params already sanitized
-- @return nil
local function set_endpoint_recipient_params(endpoint_conf_name, endpoint_recipient_name, safe_params)
   -- Write the endpoint recipient name and the conf name in an hash
   ntop.setHashCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG, endpoint_recipient_name, endpoint_conf_name)
   -- Write the endpoint recipient config into another hash
   local k = string.format(ENDPOINT_RECIPIENTS_KEY, endpoint_conf_name)
   ntop.setHashCache(k, endpoint_recipient_name, json.encode(safe_params))
end

-- #################################################################

-- @brief Sanity checks for the endpoint configuration parameters
-- @param endpoint_key A string with the notification endpoint key
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return false with a description of the error, or true, with a table containing sanitized configuration params.
local function check_endpoint_recipient_params(endpoint_key, recipient_params)
   if not recipient_params or not type(recipient_params) == "table" then
      return false, {status = "failed", error = {type = "invalid_recipient_params"}}
   end

   -- Create a safe_params table with only expected params
   local safe_params = {}
   -- So iterate across all expected params of the current endpoint
   for _, param in ipairs(notification_configs.get_types()[endpoint_key].recipient_params) do
      -- param is a lua table so we access its elements
      local param_name = param["param_name"]
      local optional = param["optional"]

      if recipient_params and recipient_params[param_name] and not safe_params[param_name] then
	 safe_params[param_name] = recipient_params[param_name]
      elseif not optional then
	 return false, {status = "failed", error = {type = "missing_mandatory_param", missing_param = param_name}}
      end
   end

   return true, {status = "OK", safe_params = safe_params}
end

-- #################################################################

function notification_recipients.add_recipient(endpoint_conf_name, endpoint_recipient_name, recipient_params)
   local ec = notification_configs.get_endpoint_config(endpoint_conf_name)

   if ec["status"] ~= "OK" then
      return ec
   end

   local ok, status = check_endpoint_recipient_name(endpoint_recipient_name)
   if not ok then
      return status
   end

   -- Is the endpoint already existing?
   if is_endpoint_recipient_existing(endpoint_recipient_name) then
      return {status = "failed", error = {type = "endpoint_recipient_already_existing", endpoint_recipient_name = endpoint_recipient_name}}
   end

   local endpoint_key = ec["endpoint_key"]
   ok, status = check_endpoint_recipient_params(endpoint_key, recipient_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   -- Set the config
   set_endpoint_recipient_params(endpoint_conf_name, endpoint_recipient_name, safe_params)

   return {status = "OK"}
end

-- #################################################################

-- @brief Edit the recipient parameters of an existing endpoint configuration
-- @param endpoint_recipient_name A string with the recipient name
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function notification_recipients.edit_recipient(endpoint_recipient_name, recipient_params)
   local ok, status = check_endpoint_recipient_name(endpoint_recipient_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local rc = read_endpoint_recipient_raw(endpoint_recipient_name)
   if not rc then
      return {status = "failed", error = {type = "endpoint_recipient_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
   end

   local ec = notification_configs.get_endpoint_config(rc["endpoint_conf_name"])

   if ec["status"] ~= "OK" then
      return ec
   end

   -- Are the submitted params those expected by the endpoint?
   ok, status = check_endpoint_recipient_params(ec["endpoint_key"], recipient_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   -- Overwrite the config
   set_endpoint_recipient_params(rc["endpoint_conf_name"], endpoint_recipient_name, safe_params)

   return {status = "OK"}
end

-- #################################################################

function notification_recipients.get_recipient(endpoint_recipient_name)
   local ok, status = check_endpoint_recipient_name(endpoint_recipient_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local rc = read_endpoint_recipient_raw(endpoint_recipient_name)
   if not rc then
      return {status = "failed", error = {type = "endpoint_recipient_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
   end

   local ec = notification_configs.get_endpoint_config(rc["endpoint_conf_name"])

   if ec["status"] ~= "OK" then
      return ec
   end

   return {
      status = "OK",
      endpoint_conf = ec,
      recipient_params = json.decode(rc["recipient_params"]),
      recipient_name = endpoint_recipient_name,
      export_queue = get_endpoint_recipient_queue(endpoint_recipient_name),
   }
end

-- #################################################################

function notification_recipients.get_recipients(exclude_builtin)
   local res = {}
   local all_recipients = ntop.getHashAllCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG)

   for recipient_name, config_name in pairs(all_recipients or {}) do
      local r = notification_recipients.get_recipient(recipient_name)

      if not exclude_builtin or not r.endpoint_conf.endpoint_conf.builtin then
	 res[#res + 1] = r
      end
   end

   return res
end

-- #################################################################

function notification_recipients.delete_recipient(endpoint_recipient_name)
   local pools_lua_utils = require "pools_lua_utils"
   local ok, status = check_endpoint_recipient_name(endpoint_recipient_name)
   if not ok then
      return status
   end

   -- Is the endpoint already existing?
   if not is_endpoint_recipient_existing(endpoint_recipient_name) then
      return {status = "failed", error = {type = "endpoint_recipient_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
   end

   local endpoint_conf_name = ntop.getHashCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG, endpoint_recipient_name)
   if not endpoint_conf_name or endpoint_conf_name == '' then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
   end

   local k = string.format(ENDPOINT_RECIPIENTS_KEY, endpoint_conf_name)
   ntop.delHashCache(k, endpoint_recipient_name)
   ntop.delHashCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG, endpoint_recipient_name)

   pools_lua_utils.unbind_all_recipient_id(endpoint_recipient_name)

   return {status = "OK"}
end

-- #################################################################

function notification_recipients.delete_recipients(endpoint_conf_name)
   local ec = notification_configs.get_endpoint_config(endpoint_conf_name)

   if ec["status"] ~= "OK" then
      return ec
   end

   local k = string.format(ENDPOINT_RECIPIENTS_KEY, endpoint_conf_name)
   local all_recipients = ntop.getHashAllCache(k) or {}

   for endpoint_recipient_name, endpoint_recipient_config in pairs(all_recipients) do
      notification_recipients.delete_recipient(endpoint_recipient_name)
   end

   ntop.delCache(k)

   return {status = "OK"}
end

-- #################################################################

function notification_recipients.test_recipient(endpoint_conf_name, endpoint_recipient_name, recipient_params)

   -- Get endpoint config

   local ec = notification_configs.get_endpoint_config(endpoint_conf_name)

   if ec["status"] ~= "OK" then
      return ec
   end

   -- Check recipient parameters

   local endpoint_key = ec["endpoint_key"]
   ok, status = check_endpoint_recipient_params(endpoint_key, recipient_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   -- Create dummy recipient

   local recipient = {
      endpoint_conf = ec,
      recipient_params = safe_params,
   }

   -- Get endpoint module

   local modules_by_name = notification_configs.get_types()
   local module_name = recipient.endpoint_conf.endpoint_key
   local m = modules_by_name[module_name]
   if not m then
      return {status = "failed", error = {type = "endpoint_module_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
   end

   -- Run test

   if not m.runTest then
      return {status = "failed", error = {type = "endpoint_test_not_available", endpoint_recipient_name = endpoint_recipient_name}}
   end

   local success, message = m.runTest(recipient)

   if success then
      return {status = "OK"}
   else
      return {status = "failed", error = {type = "endpoint_test_failure", message = message }}
   end
end

-- #################################################################

function notification_recipients.dispatchNotification(message, json_message)
   local pools_alert_utils = require "pools_alert_utils"

   -- Dispatch to the builtin sqlite recipient (possibly check if the recipient is enabled or disabled)
   -- The builtin sqlite recipient is created in startup.lua
   -- NOTE: Using straight the recipient_id for efficieny reasons
   local builtin_queue = get_endpoint_recipient_queue("builtin_recipient_sqlite")
   -- Push the message at the tail of the export queue for the recipient
   ntop.rpushCache(builtin_queue, json_message, alert_consts.MAX_NUM_QUEUED_ALERTS_PER_RECIPIENT)

   -- Now see, and possibly dispatch, the notification also to any additional recipient
   -- which is responsible for the entity pool id
   local pools = pools_alert_utils.get_entity_pools_by_id(message.alert_entity)
   
   if not pools then
      -- traceError(TRACE_ERROR, TRACE_CONSOLE, "Pools for entity "..message.alert_entity.." not found")
      return
   end

   local recipients = pools:get_recipients(message.pool_id)
   for _, recipient_id in pairs(recipients) do
      local export_queue = get_endpoint_recipient_queue(recipient_id)

      -- Push the message at the tail of the expor queue for the recipient
      ntop.rpushCache(export_queue, json_message, alert_consts.MAX_NUM_QUEUED_ALERTS_PER_RECIPIENT)
   end
end

-- #################################################################

function notification_recipients.processNotifications(now, periodic_frequency, force_export)
   local recipients = notification_recipients.get_recipients()
   local modules_by_name = notification_configs.get_types()
   local ready_recipients = {}

   -- Check, among all available recipients, those that are ready to export, depending on
   -- their EXPORT_FREQUENCY
   for _, recipient in pairs(recipients) do
      local module_name = recipient.endpoint_conf.endpoint_key 

      if modules_by_name[module_name] then
         local m = modules_by_name[module_name]
	 if force_export or check_endpoint_export(recipient.recipient_name, m.EXPORT_FREQUENCY) then
	    ready_recipients[#ready_recipients + 1] = {recipient = recipient, mod = m}
	 end
      end
   end

   -- Total budget availabe, which is a multiple of the periodic_frequency
   -- Budget in this case is the maximum number of notifications which can
   -- be processed during this call.
   local total_budget = 1000 * periodic_frequency
   -- To avoid having one recipient jeopardizing all the resources, the total
   -- budget is consumed in chunks, that is, recipients are iterated multiple times
   -- and, each time any recipient has a maximum budget for every iteration.
   local budget_per_iter = 100

   -- Cycle until there are ready_recipients and total_budget left
   while #ready_recipients > 0 and total_budget >= 0 and not ntop.isDeadlineApproaching() do
      for i = #ready_recipients, 1, -1 do
	 local ready_recipient = ready_recipients[i]
	 local recipient = ready_recipient.recipient
	 local m = ready_recipient.mod

	 if do_trace then tprint("Dequeuing alerts for ready recipient: ".. recipient.recipient_name) end

	 if m.dequeueRecipientAlerts then
	    local rv = m.dequeueRecipientAlerts(recipient, budget_per_iter)

	    -- If the recipient has failed (not rv.success) or
	    -- if it has no more work to do (not rv.more_available)
	    -- it can be removed from the array of ready recipients.
	    if not rv.success or not rv.more_available then
	       table.remove(ready_recipients, i)

	       if do_trace then tprint("Ready recipient done: ".. recipient.recipient_name) end

	       if not rv.success then
		  local msg = rv.error_message or "Unknown Error"
		  traceError(TRACE_ERROR, TRACE_CONSOLE, "Error while sending notifications via " .. recipient.recipient_name .. " " .. msg)
	       end
	    end
	 end
      end

      -- Update the total budget
      total_budget = total_budget - budget_per_iter
   end

   if do_trace then
      if #ready_recipients > 0 then
	 tprint("Deadline approaching: "..tostring(ntop.isDeadlineApproaching()))
	 tprint("Budget left: "..total_budget)
	 tprint("The following recipients were unable to dequeue all their notifications")
	 for _, ready_recipient in pairs(ready_recipients) do
	    tprint(" "..ready_recipient.recipient.recipient_name)
	 end
      end
   end
end

-- #################################################################

return notification_recipients
