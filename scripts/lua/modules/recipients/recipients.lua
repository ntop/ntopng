--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local json = require "dkjson"
local alert_consts = require "alert_consts"
local notification_configs = require("notification_configs")

-- ##############################################

local recipients = {}

-- ##############################################

recipients.MAX_NUM_RECIPIENTS = 128

-- ##############################################

function recipients:create(args)
   if args then
      -- We're being sub-classed
      if not args.key then
	 return nil
      end
   end

   local this = args or {key = "recipients"}

   setmetatable(this, self)
   self.__index = self

   return this
end

-- ##############################################

-- @brief Performs Initialization operations performed during startup
function recipients:initialize()
   -- Initialize builtin recipients, that is, recipients always existing an not editable from the UI
   -- For each builtin configuration type, a configuration and a recipient is created
   for endpoint_key, endpoint in pairs(notification_configs.get_types()) do
      if endpoint.builtin then
	 -- Add the configuration
	 notification_configs.add_config(
	    endpoint_key --[[ the type of the endpoint--]],
	    "builtin_config_"..endpoint_key --[[ the name of the endpoint configuration --]],
	    {} --[[ no default params --]]
	 )

	 -- And the recipient
	 self:add_recipient(
	    "builtin_config_"..endpoint_key --[[ the name of the endpoint configuration --]], 
	    "builtin_recipient_"..endpoint_key --[[ the name of the endpoint recipient --]],
	    {} --[[ no recipient params --]]
	 )
      end
   end

   -- Possibly create a default recipient (if not existing)
end

-- ##############################################

function recipients:_get_recipients_lock_key()
   local key = string.format("ntopng.cache.recipients.recipients_lock")

   return key
end

-- ##############################################

-- @brief Key to store a flag for signaling recipient changes
-- @return A string key
function recipients:_get_recipients_changed_key()
   local key = string.format("ntopng.cache.recipients.recipients_changed")

   return key
end

-- ##############################################

-- @brief Mark a recipients change (must be called when adding/deleteding/editing a recipient)
-- @return nil
function recipients:_set_recipients_change()
   ntop.setCache(self:_get_recipients_changed_key(), "1")
end

-- ##############################################

-- @brief Checks whether recipients have changed. If recipients have changed, the change is acknowledged
-- @return True if recipients have changed, false otherwise.
function recipients:_check_recipients_change()
   local res = ntop.getCache(self:_get_recipients_changed_key()) ~= ""

   if res then
      -- A change in recipients has occurred
      -- Remove the key to aknowledge the change
      ntop.delCache(self:_get_recipients_changed_key())
   end

   return res
end

-- ##############################################

function recipients:_lock()
   local max_lock_duration = 5 -- seconds
   local max_lock_attempts = 5 -- give up after at most this number of attempts
   local lock_key = self:_get_recipients_lock_key()

   for i = 1, max_lock_attempts do
      local value_set = ntop.setnxCache(lock_key, "1", max_lock_duration)

      if value_set then
	 return true -- lock acquired
      end

      ntop.msleep(1000)
   end

   return false -- lock not acquired
end

-- ##############################################

function recipients:_unlock()
   ntop.delCache(self:_get_recipients_lock_key())
end

-- ##############################################

function recipients:_get_recipients_prefix_key()
   local key = string.format("ntopng.prefs.recipients")

   return key
end

-- ##############################################

function recipients:_get_recipient_ids_key()
   local key = string.format("%s.recipient_ids", self:_get_recipients_prefix_key())

   return key
end

-- ##############################################

function recipients:_get_recipient_details_key(recipient_id)
   recipient_id = tonumber(recipient_id)

   if not recipient_id then
      -- A recipient id is always needed
      return nil
   end

   local key = string.format("%s.recipient_id_%d.details", self:_get_recipients_prefix_key(), recipient_id)

   return key
end

-- ##############################################

-- @brief Returns an array with all the currently assigned recipient ids
function recipients:_get_assigned_recipient_ids()
   local res = { }

   local cur_recipient_ids = ntop.getMembersCache(self:_get_recipient_ids_key())

   for _, cur_recipient_id in pairs(cur_recipient_ids) do
      cur_recipient_id = tonumber(cur_recipient_id)
      res[#res + 1] = cur_recipient_id
   end

   return res
end

-- ##############################################

function recipients:_assign_recipient_id()
   local cur_recipient_ids = self:_get_assigned_recipient_ids()
   local next_recipient_id

   -- Create a Lua table with currently assigned recipient ids as keys
   -- to ease the lookup
   local ids_by_key = {}
   for _, recipient_id in pairs(cur_recipient_ids) do
      ids_by_key[recipient_id] = true
   end

   -- Lookup for the first (smallest) available recipient id.
   -- This is to effectively recycle recipient ids no longer used, that is,
   -- belonging to deleted recipients
   for i = 0, recipients.MAX_NUM_RECIPIENTS - 1 do
      if not ids_by_key[i] then
	 next_recipient_id = i
	 break
      end
   end

   if next_recipient_id then
      -- Add the atomically assigned recipient id to the set of current recipient ids (set wants a string)
      ntop.setMembersCache(self:_get_recipient_ids_key(), string.format("%d", next_recipient_id))
   else
      -- All recipient ids exhausted
   end

   return next_recipient_id
end

-- ##############################################

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

-- ##############################################

-- @brief Set a configuration along with its params. Configuration name and params must be already sanitized
-- @param endpoint_conf_name A string with the notification endpoint configuration name
-- @param endpoint_recipient_name A string with the recipient name
-- @param safe_params A table with endpoint recipient params already sanitized
-- @return nil
function recipients:_set_endpoint_recipient_params(recipient_id, endpoint_conf_name, endpoint_recipient_name, safe_params)
   -- Write the endpoint recipient config into another hash
   local k = self:_get_recipient_details_key(recipient_id)

   ntop.setCache(k, json.encode({endpoint_conf_name = endpoint_conf_name,
				 recipient_name = endpoint_recipient_name,
				 recipient_params = safe_params}))

   -- Notify a change in the recipients
   self:_set_recipients_change()

   return recipient_id
end

-- ##############################################

function recipients:add_recipient(endpoint_conf_name, endpoint_recipient_name, recipient_params)
   local locked = self:_lock()
   local res = { status = "failed" }

   if locked then
      local ec = notification_configs.get_endpoint_config(endpoint_conf_name)

      if ec["status"] == "OK" and endpoint_recipient_name then
	 -- Is the endpoint already existing?
	 local same_recipient = self:get_recipient_by_name(endpoint_recipient_name)
	 if same_recipient then
	    res = {status = "failed",
		   error = {type = "endpoint_recipient_already_existing",
			    endpoint_recipient_name = endpoint_recipient_name}
	    }
	 else
	    local endpoint_key = ec["endpoint_key"]
	    local ok, status = check_endpoint_recipient_params(endpoint_key, recipient_params)

	    if ok then
	       local safe_params = status["safe_params"]

	       -- Assign the recipient id
	       local recipient_id = self:_assign_recipient_id()
	       -- Persist the configuration
	       self:_set_endpoint_recipient_params(recipient_id, endpoint_conf_name, endpoint_recipient_name, safe_params)

	       res = {status = "OK", recipient_id = recipient_id}
	    end
	 end
      end

      self:_unlock()
   end

   return res
end

-- ##############################################

-- @brief Edit the recipient parameters of an existing endpoint configuration
-- @param recipient_id The integer recipient identificator
-- @param endpoint_recipient_name A string with the recipient name
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function recipients:edit_recipient(recipient_id, endpoint_recipient_name, recipient_params)
   local locked = self:_lock()
   local res = { status = "failed" }

   if locked then
      local rc = self:get_recipient(recipient_id)

      if not rc then
	 res = {status = "failed", error = {type = "endpoint_recipient_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
      else
	 local ec = notification_configs.get_endpoint_config(rc["endpoint_conf_name"])

	 if ec["status"] ~= "OK" then
	    res = ec
	 else
	    -- Are the submitted params those expected by the endpoint?
	    local ok, status = check_endpoint_recipient_params(ec["endpoint_key"], recipient_params)

	    if not ok then
	       res = status
	    else
	       local safe_params = status["safe_params"]

	       -- Persist the configuration
	       self:_set_endpoint_recipient_params(recipient_id, rc["endpoint_conf_name"], endpoint_recipient_name, safe_params)

	       res = {status = "OK"}
	    end
	 end
      end

      self:_unlock()
   end

   return res
end

-- ##############################################

function recipients:delete_recipient(recipient_id)
   local pools_lua_utils = require "pools_lua_utils"
   local ret = false

   local locked = self:_lock()

   if locked then
      -- Make sure the recipient exists
      local cur_recipient_details = self:get_recipient(recipient_id)

      if cur_recipient_details then	 
	 -- Unbind the recipient from any assigned pool
	 pools_lua_utils.unbind_all_recipient_id(recipient_id)

	 -- Remove the key with all the recipient details (e.g., with members, and configset_id)
	 ntop.delCache(self:_get_recipient_details_key(recipient_id))

	 -- Remove the recipient_id from the set of all currently existing recipient ids
	 ntop.delMembersCache(self:_get_recipient_ids_key(), string.format("%d", recipient_id))

	 -- Notify a change in the recipients
	 self:_set_recipients_change()

	 -- Finally, remove the recipient from C
	 ntop.recipient_delete(recipient_id)
	 ret = true
      end

      self:_unlock()
   end

   return ret
end

-- ##############################################

-- @brief Delete all recipients having the given `endpoint_conf_name`
-- @param endpoint_conf_name An endpoint configuration key
-- @return nil
function recipients:delete_recipients_by_conf(endpoint_conf_name)
   local ret = false

   local all_recipients = self:get_all_recipients()
   for _, recipient in pairs(all_recipients) do
      if recipient.endpoint_conf_name == endpoint_conf_name then
	 self:delete_recipient(recipient.recipient_id)
      end
   end
end

-- #################################################################

function recipients:test_recipient(endpoint_conf_name, recipient_params)
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
      endpoint_conf_name = endpoint_conf_name,
      endpoint_conf = ec["endpoint_conf"],
      endpoint_key = ec["endpoint_key"],
      recipient_params = safe_params,
   }

   -- Get endpoint module
   local modules_by_name = notification_configs.get_types()
   local module_name = recipient.endpoint_key
   local m = modules_by_name[module_name]
   if not m then
      return {status = "failed", error = {type = "endpoint_module_not_existing", endpoint_recipient_name = recipient.endpoint_conf.endpoint_key}}
   end

   -- Run test

   if not m.runTest then
      return {status = "failed", error = {type = "endpoint_test_not_available", endpoint_recipient_name = recipient.endpoint_conf.endpoint_key}}
   end

   local success, message = m.runTest(recipient)

   if success then
      return {status = "OK"}
   else
      return {status = "failed", error = {type = "endpoint_test_failure", message = message }}
   end
end

-- ##############################################

function recipients:get_recipient(recipient_id)
   local recipient_details
   local recipient_details_key = self:_get_recipient_details_key(recipient_id)

   -- Attempt at retrieving the recipient details key and at decoding it from JSON
   if recipient_details_key then
      local recipient_details_str = ntop.getCache(recipient_details_key)
      recipient_details = json.decode(recipient_details_str)

      if recipient_details then
	 -- Add the integer recipient id
	 recipient_details["recipient_id"] = tonumber(recipient_id)

	 -- Add also the endpoint configuration
	 local ec = notification_configs.get_endpoint_config(recipient_details["endpoint_conf_name"])

	 if ec then
	    recipient_details["endpoint_conf"] = ec["endpoint_conf"]
	    recipient_details["endpoint_key"] = ec["endpoint_key"]
	 end
      end
   end

   -- Upon success, recipient details are returned, otherwise nil
   return recipient_details
end

-- ##############################################

function recipients:get_all_recipients(exclude_builtin)
   local res = {}
   local cur_recipient_ids = self:_get_assigned_recipient_ids()

   for _, recipient_id in pairs(cur_recipient_ids) do
      local recipient_details = self:get_recipient(recipient_id)

      if recipient_details and (not exclude_builtin or not recipient_details.endpoint_conf.builtin) then
	 res[#res + 1] = recipient_details
      end
   end

   return res
end

-- ##############################################

function recipients:get_recipient_by_name(name)
   local cur_recipient_ids = self:_get_assigned_recipient_ids()

   for _, recipient_id in pairs(cur_recipient_ids) do
      local recipient_details = self:get_recipient(recipient_id)

      if recipient_details and recipient_details["recipient_name"] and recipient_details["recipient_name"] == name then
	 return recipient_details
      end
   end

   return nil
end

-- ##############################################

function recipients:get_builtin_recipients()
   -- Currently, only sqlite (created in startup.lua) is the builtin recipient
   -- The builtin sqlite recipient is created in startup.lua
   if not self.builtin_recipients_cache then
      self.builtin_recipients_cache = { self:get_recipient_by_name("builtin_recipient_sqlite").recipient_id }
   end

   return self.builtin_recipients_cache
end

-- ##############################################

local function is_notification_high_priority(notification)
   local res = true

   if notification.alert_entity == alert_consts.alertEntity("flow") then
      -- Flow alerts are low-priority
      res = false
   end

   return res
end

-- ##############################################

-- @brief Dispatches a `notification` to all the interested recipients
-- @param notification An alert notification
-- @return nil
function recipients:dispatch_notification(notification)
   local pools_alert_utils = require "pools_alert_utils"
   local recipients = pools_alert_utils.get_entity_recipients_by_pool_id(notification.alert_entity, notification.pool_id)

   -- NOTE: Using straight the recipient_id for efficieny reasons
   for _, recipient_id in pairs(self:get_builtin_recipients()) do
      recipients[#recipients + 1] = recipient_id
   end

   if #recipients > 0 then
      local json_notification = json.encode(notification)
      local is_high_priority = is_notification_high_priority(notification)

      for _, recipient_id in pairs(recipients) do
	 ntop.recipient_enqueue(recipient_id, is_high_priority, json_notification)
      end
   end
end

-- ##############################################

-- @brief Processes notifications dispatched to recipients
-- @param ready_recipients A table with recipients ready to export. Recipients who completed their work are removed from the table
-- @param high_priority A boolean indicating whether to process high- or low-priority notifications
-- @param now An epoch of the current time
-- @param periodic_frequency The frequency, in seconds, of this call
-- @param force_export A boolean telling to forcefully export dispatched notifications
-- @return nil
local function process_notifications_by_priority(ready_recipients, high_priority, now, deadline, periodic_frequency, force_export)
   -- Total budget availabe, which is a multiple of the periodic_frequency
   -- Budget in this case is the maximum number of notifications which can
   -- be processed during this call.
   local total_budget = 1000 * periodic_frequency
   -- To avoid having one recipient jeopardizing all the resources, the total
   -- budget is consumed in chunks, that is, recipients are iterated multiple times
   -- and, each time any recipient has a maximum budget for every iteration.
   local budget_per_iter = 10

   -- Cycle until there are ready_recipients and total_budget left
   local cur_time = os.time()
   while #ready_recipients > 0 and total_budget >= 0 and cur_time <= deadline do
      for i = #ready_recipients, 1, -1 do
	 local ready_recipient = ready_recipients[i]
	 local recipient = ready_recipient.recipient
	 local m = ready_recipient.mod

	 if do_trace then tprint("Dequeuing alerts for ready recipient: ".. recipient.recipient_name.. " high_priority: "..tostring(high_priority)) end

	 if m.dequeueRecipientAlerts then
	    local rv = m.dequeueRecipientAlerts(recipient, budget_per_iter, high_priority)

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
      cur_time = os.time()
   end

   if do_trace then
      if #ready_recipients > 0 then
	 tprint("Deadline approaching: "..tostring(deadline < cur_time))
	 tprint("Budget left: "..total_budget)
	 tprint("The following recipients were unable to dequeue all their notifications")
	 for _, ready_recipient in pairs(ready_recipients) do
	    tprint(" "..ready_recipient.recipient.recipient_name)
	 end
      end
   end
end

-- #################################################################

local function check_endpoint_export(recipient_id, export_frequency)
   local k = string.format("ntopng.cache.notification_recipient_export_time.recipient_id_%d", recipient_id)
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

-- @brief Processes notifications dispatched to recipients
-- @param now An epoch of the current time
-- @param periodic_frequency The frequency, in seconds, of this call
-- @param force_export A boolean telling to forcefully export dispatched notifications
-- @return nil
function recipients:process_notifications(now, deadline, periodic_frequency, force_export)
   if not areAlertsEnabled() then
      return
   end

   if not self.recipients then
      -- Cache recipients to avoid re-reading them constantly
      self.recipients = self:get_all_recipients()
   else
      -- Make sure the recipients cache is still valid (i.e., no recipient changes have occurred in the meanwhile)
      local locked = self:_lock()

      if locked then
	 if self:_check_recipients_change() then
	    -- If there has been a change, a reload is performed
	    self.recipients = self:get_all_recipients()
	 end
	 self:_unlock()
      else
	 -- Unable to acquire the lock, exit (will retry later)
	 return
      end
   end
   local modules_by_name = notification_configs.get_types()
   local ready_recipients = {}

   -- Check, among all available recipients, those that are ready to export, depending on
   -- their EXPORT_FREQUENCY
   for _, recipient in pairs(self.recipients) do
      local module_name = recipient.endpoint_key 

      if modules_by_name[module_name] then
         local m = modules_by_name[module_name]
	 if force_export or check_endpoint_export(recipient.recipient_id, m.EXPORT_FREQUENCY) then
	    ready_recipients[#ready_recipients + 1] = {recipient = recipient, recipient_id = recipient.recipient_id, mod = m}
	 end
      end
   end

   -- Use table.clone to pass recipients as the table is modified to only leave, after the call,
   -- only those recipients who didn't complete their job.
   process_notifications_by_priority(table.clone(ready_recipients), true  --[[ high priority --]], now, deadline, periodic_frequency, force_export)
   process_notifications_by_priority(table.clone(ready_recipients), false --[[ low priority  --]], now, deadline, periodic_frequency, force_export)
   -- Refresh recipients periodically
   ntop.recipients_refresh()
end

-- ##############################################

function recipients:cleanup()
   -- Delete recipient details
   local cur_recipient_ids = self:_get_assigned_recipient_ids()

   for _, recipient_id in pairs(cur_recipient_ids) do
      self:delete_recipient(recipient_id)
   end

   local locked = self:_lock()
   if locked then
      -- Delete recipient ids
      ntop.delCache(self:_get_recipient_ids_key())

      self:_unlock()
   end

   -- Redo the initialization after cleanup
   self:initialize()
end

-- ##############################################

return recipients
