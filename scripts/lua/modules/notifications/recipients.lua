--
-- (C) 2017-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local json = require "dkjson"
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local alert_entities = require "alert_entities"
local checks = require "checks"

local host_pools = require "host_pools":create()
local interface_pools = require "interface_pools":create()

local endpoints = require("endpoints")

-- ##############################################

local recipients = {}

-- ##############################################

recipients.MAX_NUM_RECIPIENTS = 64 -- Keep in sync with ntop_defines.h MAX_NUM_RECIPIENTS

-- ##############################################

recipients.FIRST_RECIPIENT_CREATED_CACHE_KEY = "ntopng.prefs.endpoint_hints.recipient_created"

local default_builtin_minimum_severity = alert_severities.notice.severity_id -- minimum severity is notice (to avoid flooding) (*****)

-- ##############################################

-- @brief Performs Initialization operations performed during startup
function recipients.initialize()
   local checks = require "checks"

   -- Initialize builtin recipients, that is, recipients always existing an not editable from the UI
   -- For each builtin configuration type, a configuration and a recipient is created
   local all_categories = {}
   for _, category in pairs(checks.check_categories) do
      all_categories[#all_categories + 1] = category.id
   end

   -- Add host pools
   local all_host_pools = {}
   local pools = host_pools:get_all_pools()
   for _, pool in pairs(pools) do
      all_host_pools[#all_host_pools + 1] = pool.pool_id
   end

   -- Add interface pools
   local all_interface_pools = {}
   local pools = interface_pools:get_all_pools()
   for _, pool in pairs(pools) do
      all_interface_pools[#all_interface_pools + 1] = pool.pool_id
   end

   for endpoint_key, endpoint in pairs(endpoints.get_types()) do
      if endpoint.builtin then
	 -- Delete (if existing) the old, string-keyed endpoint configuration
	 endpoints.delete_config("builtin_config_"..endpoint_key)

         -- Add the configuration
         local res = endpoints.add_config(
            endpoint_key --[[ the type of the endpoint--]],
            "builtin_endpoint_"..endpoint_key --[[ the name of the endpoint configuration --]],
            {} --[[ no default params --]]
         )

	 -- Endpoint successfully created (or existing)
	 if res and res.endpoint_id then
	    -- And the recipient

	    local recipient_res = recipients.add_recipient(
	       res.endpoint_id --[[ the id of the endpoint --]],
	       "builtin_recipient_"..endpoint_key --[[ the name of the endpoint recipient --]],
	       all_categories,
	       default_builtin_minimum_severity,
               all_host_pools, -- host pools
               all_interface_pools, -- interface pools
	       {} --[[ no recipient params --]]
	    )

	 end
      end
   end

   -- Delete (if existing) the old, string-keyed recipient and endpoint
   local sqlite_recipient = recipients.get_recipient_by_name("builtin_recipient_sqlite")
   if sqlite_recipient then
      recipients.delete_recipient(sqlite_recipient.recipient_id)
   end

   endpoints.delete_config("builtin_config_sqlite")

   -- Register all existing recipients in C to make sure ntopng can start with all the
   -- existing recipients properly loaded and ready for notification enqueues/dequeues
   for _, recipient in pairs(recipients.get_all_recipients()) do
      ntop.recipient_register(recipient.recipient_id, recipient.minimum_severity, 
         table.concat(recipient.check_categories, ','),
         table.concat(recipient.host_pools, ','),
         table.concat(recipient.interface_pools, ',')
      )
   end
end

-- ##############################################

local function _get_recipients_lock_key()
   local key = string.format("ntopng.cache.recipients.recipients_lock")

   return key
end

-- ##############################################

local function _lock()
   local max_lock_duration = 5 -- seconds
   local max_lock_attempts = 5 -- give up after at most this number of attempts
   local lock_key = _get_recipients_lock_key()

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

local function _unlock()
   ntop.delCache(_get_recipients_lock_key())
end

-- ##############################################

local function _get_recipients_prefix_key()
   local key = string.format("ntopng.prefs.recipients")

   return key
end

-- ##############################################

local function _get_recipient_ids_key()
   local key = string.format("%s.recipient_ids", _get_recipients_prefix_key())

   return key
end

-- ##############################################

local function _get_recipient_details_key(recipient_id)
   recipient_id = tonumber(recipient_id)

   if not recipient_id then
      -- A recipient id is always needed
      return nil
   end

   local key = string.format("%s.recipient_id_%d.details", _get_recipients_prefix_key(), recipient_id)

   return key
end

-- ##############################################

-- @brief Returns an array with all the currently assigned recipient ids
local function _get_assigned_recipient_ids()
   local res = { }

   local cur_recipient_ids = ntop.getMembersCache(_get_recipient_ids_key())

   for _, cur_recipient_id in pairs(cur_recipient_ids) do
      cur_recipient_id = tonumber(cur_recipient_id)
      res[#res + 1] = cur_recipient_id
   end

   return res
end

-- ##############################################

local function _assign_recipient_id()
   local cur_recipient_ids = _get_assigned_recipient_ids()
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
      ntop.setMembersCache(_get_recipient_ids_key(), string.format("%d", next_recipient_id))
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
   for _, param in ipairs(endpoints.get_types()[endpoint_key].recipient_params) do
      -- param is a lua table so we access its elements
      local param_name = param["param_name"]
      if param_name then
         local optional = param["optional"]

         if recipient_params and recipient_params[param_name] and not safe_params[param_name] then
            safe_params[param_name] = recipient_params[param_name]
         elseif not optional then
	    return false, {status = "failed", error = {type = "missing_mandatory_param", missing_param = param_name}}
         end
      end
   end

   return true, {status = "OK", safe_params = safe_params}
end

-- ##############################################

-- @brief Set a configuration along with its params. Configuration name and params must be already sanitized
-- @param endpoint_id An integer identifier of the endpoint
-- @param endpoint_recipient_name A string with the recipient name
-- @param check_categories A Lua array with already-validated ids as found in `checks.check_categories` or nil to indicate all categories
-- @param minimum_severity An already-validated integer alert severity id as found in `alert_severities` or nil to indicate no minimum severity
-- @param safe_params A table with endpoint recipient params already sanitized
-- @return nil
local function _set_endpoint_recipient_params(endpoint_id, recipient_id, endpoint_recipient_name, check_categories, minimum_severity, host_pools_ids, interface_pools_ids, safe_params)
   -- Write the endpoint recipient config into another hash
   local k = _get_recipient_details_key(recipient_id)

   ntop.setCache(k, json.encode({endpoint_id = endpoint_id,
				 recipient_name = endpoint_recipient_name,
				 check_categories = check_categories,
				 minimum_severity = minimum_severity,
				 host_pools = host_pools_ids,
				 interface_pools = interface_pools_ids,
				 recipient_params = safe_params}))

   return recipient_id
end

-- ##############################################

-- @brief Add a new recipient of an existing endpoint configuration and returns its id
-- @param endpoint_id An integer identifier of the endpoint
-- @param endpoint_recipient_name A string with the recipient name
-- @param check_categories A Lua array with already-validated ids as found in `checks.check_categories` or nil to indicate all categories
-- @param minimum_severity An already-validated integer alert severity id as found in `alert_severities` or nil to indicate no minimum severity
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed", and the recipient id assigned to the newly added recipient. When "failed", the table contains another key "error" with an indication of the issue
function recipients.add_recipient(endpoint_id, endpoint_recipient_name, check_categories, minimum_severity, host_pools_ids, interface_pools_ids, recipient_params)
   local locked = _lock()
   local res = { 
      status = "failed",
      error = {
         type = "internal_error"
      }
   }

   if locked then
      local ec = endpoints.get_endpoint_config(endpoint_id)

      if ec["status"] == "OK" and endpoint_recipient_name then

	 -- Is the endpoint already existing?
	 local same_recipient = recipients.get_recipient_by_name(endpoint_recipient_name)
	 if same_recipient then
	    res = {
               status = "failed",
	       error = {
                  type = "endpoint_recipient_already_existing",
		  endpoint_recipient_name = endpoint_recipient_name
               }
	    }
	 else
	    local endpoint_key = ec["endpoint_key"]
	    local ok, status = check_endpoint_recipient_params(endpoint_key, recipient_params)

	    if ok then
	       local safe_params = status["safe_params"]

	       -- Assign the recipient id
	       local recipient_id = _assign_recipient_id()
	       -- Persist the configuration
	       _set_endpoint_recipient_params(endpoint_id, recipient_id, endpoint_recipient_name, check_categories, minimum_severity, host_pools_ids, interface_pools_ids, safe_params)

	       -- Finally, register the recipient in C so we can start enqueuing/dequeuing notifications
	       ntop.recipient_register(recipient_id, minimum_severity, 
                  table.concat(check_categories, ','),
                  table.concat(host_pools_ids, ','),
                  table.concat(interface_pools_ids, ',')
               )

	       -- Set a flag to indicate that a recipient has been created
	       if not ec.endpoint_conf.builtin and isEmptyString(ntop.getPref(recipients.FIRST_RECIPIENT_CREATED_CACHE_KEY)) then
		  ntop.setPref(recipients.FIRST_RECIPIENT_CREATED_CACHE_KEY, "1")
	       end

	       res = {
                  status = "OK", 
                  recipient_id = recipient_id
               }
            else
               res = status
	    end
	 end
      else
         res = {
            status = "failed",
            error = {
               type = "bad_endpoint",
            }
         }
      end

      _unlock()
   end

   return res
end

-- ##############################################

-- @brief Edit the recipient parameters of an existing endpoint configuration
-- @param recipient_id The integer recipient identificator
-- @param endpoint_recipient_name A string with the recipient name
-- @param check_categories A Lua array with already-validated ids as found in `checks.check_categories` or nil to indicate all categories
-- @param minimum_severity An already-validated integer alert severity id as found in `alert_severities` or nil to indicate no minimum severity
-- @param recipient_params A table with endpoint recipient params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function recipients.edit_recipient(recipient_id, endpoint_recipient_name, check_categories, minimum_severity, host_pools_ids, interface_pools_ids, recipient_params)
   local locked = _lock()
   local res = { status = "failed" }

   if locked then
      local rc = recipients.get_recipient(recipient_id)

      if not rc then
	 res = {status = "failed", error = {type = "endpoint_recipient_not_existing", endpoint_recipient_name = endpoint_recipient_name}}
      else
	 local ec = endpoints.get_endpoint_config(rc["endpoint_id"])

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
	       _set_endpoint_recipient_params(
		  rc["endpoint_id"],
		  recipient_id,
		  endpoint_recipient_name,
		  check_categories,
		  minimum_severity,
		  host_pools_ids,
		  interface_pools_ids,
		  safe_params)

	       -- Finally, register the recipient in C to make sure also the C knows about this edit
	       -- and periodic scripts can be reloaded
	       ntop.recipient_register(tonumber(recipient_id), minimum_severity, 
                  table.concat(check_categories, ','),
                  table.concat(host_pools_ids, ','),
                  table.concat(interface_pools_ids, ',')
               )

	       res = {status = "OK"}
	    end
	 end
      end

      _unlock()
   end

   return res
end

-- ##############################################

function recipients.delete_recipient(recipient_id)
   recipient_id = tonumber(recipient_id)
   local ret = false

   local locked = _lock()

   if locked then
      -- Make sure the recipient exists
      local cur_recipient_details = recipients.get_recipient(recipient_id)

      if cur_recipient_details then
	 -- Remove the key with all the recipient details (e.g., with members)
	 ntop.delCache(_get_recipient_details_key(recipient_id))

	 -- Remove the recipient_id from the set of all currently existing recipient ids
	 ntop.delMembersCache(_get_recipient_ids_key(), string.format("%d", recipient_id))

	 -- Finally, remove the recipient from C
	 ntop.recipient_delete(recipient_id)
	 ret = true
      end

      _unlock()
   end

   return ret
end

-- ##############################################

-- @brief Delete all recipients having the given `endpoint_id`
-- @param endpoint_id An integer identifier of the endpoint
-- @return nil
function recipients.delete_recipients_by_conf(endpoint_id)
   local ret = false

   local all_recipients = recipients.get_all_recipients()
   for _, recipient in pairs(all_recipients) do
      -- Use tostring for backwards compatibility
      if tostring(recipient.endpoint_id) == tostring(endpoint_id) then
	 recipients.delete_recipient(recipient.recipient_id)
      end
   end
end

-- ##############################################

-- @brief Get all recipients having the given `endpoint_conf_name`
-- @param endpoint_id An integer identifier of the endpoint
-- @return A lua array with recipients
function recipients.get_recipients_by_conf(endpoint_id, include_stats)
   local res = {}

   local all_recipients = recipients.get_all_recipients(false, include_stats)

   for _, recipient in pairs(all_recipients) do
      -- Use tostring for backward compatibility, to handle
      -- both integer and string endpoint_id
      if tostring(recipient.endpoint_id) == tostring(endpoint_id) then
	 res[#res + 1] = recipient
      end
   end

   return res
end

-- #################################################################

function recipients.test_recipient(endpoint_id, recipient_params)
   -- Get endpoint config

   local ec = endpoints.get_endpoint_config(endpoint_id)
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
      endpoint_id = ec["endpoint_id"],
      endpoint_conf_name = ec["endpoint_conf_name"],
      endpoint_conf = ec["endpoint_conf"],
      endpoint_key = ec["endpoint_key"],
      recipient_params = safe_params,
   }

   -- Get endpoint module
   local modules_by_name = endpoints.get_types()
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

function recipients.get_recipient(recipient_id, include_stats)
   local recipient_details
   local recipient_details_key = _get_recipient_details_key(recipient_id)

   -- Attempt at retrieving the recipient details key and at decoding it from JSON
   if recipient_details_key then
      local recipient_details_str = ntop.getCache(recipient_details_key)
      recipient_details = json.decode(recipient_details_str)

      if recipient_details then
	 -- Add the integer recipient id
	 recipient_details["recipient_id"] = tonumber(recipient_id)

    -- Add also the endpoint configuration name
    -- Use the endpoint id to get the endpoint configuration (use endpoint_conf_name for the old endpoints)
	 local ec = endpoints.get_endpoint_config(recipient_details["endpoint_id"] or recipient_details["endpoint_conf_name"])
	 recipient_details["endpoint_conf_name"] =  ec["endpoint_conf_name"]
	 recipient_details["endpoint_id"] =  ec["endpoint_id"]

	 -- Add user script categories. nil or empty user script categories read from the JSON imply ANY AVAILABLE category
	 if not recipient_details["check_categories"] or #recipient_details["check_categories"] == 0 then
	    if not recipient_details["check_categories"] then
	       recipient_details["check_categories"] = {}
	    end

	    local checks = require "checks"
	    for _, category in pairs(checks.check_categories) do
	       recipient_details["check_categories"][#recipient_details["check_categories"] + 1] = category.id
	    end
	 end

	 -- Add host pools
	 if not recipient_details["host_pools"] or #recipient_details["host_pools"] == 0 then
	    if not recipient_details["host_pools"] then
	       recipient_details["host_pools"] = {}
	    end

	    local pools = host_pools:get_all_pools()
	    for _, pool in pairs(pools) do
	       recipient_details["host_pools"][#recipient_details["host_pools"] + 1] = pool.pool_id
	    end
	 end

	 -- Add interface pools
	 if not recipient_details["interface_pools"] or #recipient_details["interface_pools"] == 0 then
	    if not recipient_details["interface_pools"] then
	       recipient_details["interface_pools"] = {}
	    end

	    local pools = interface_pools:get_all_pools()
	    for _, pool in pairs(pools) do
	       recipient_details["interface_pools"][#recipient_details["interface_pools"] + 1] = pool.pool_id
	    end
	 end

	 -- Add minimum alert severity. nil or empty minimum severity assumes a minimum severity of notice
	 if not tonumber(recipient_details["minimum_severity"]) then
	    recipient_details["minimum_severity"] = default_builtin_minimum_severity
	 end

	 if ec then
	    recipient_details["endpoint_conf"] = ec["endpoint_conf"]
	    recipient_details["endpoint_key"] = ec["endpoint_key"]

	    local modules_by_name = endpoints.get_types()
	    local cur_module = modules_by_name[recipient_details["endpoint_key"]]
	    if cur_module and cur_module.format_recipient_params then
	       -- Add a formatted output of recipient params
	       recipient_details["recipient_params_fmt"] = cur_module.format_recipient_params(recipient_details["recipient_params"])
	    else
	       -- A default
	       recipient_details["recipient_params_fmt"] = ""
	    end
	 end

         if include_stats then
	    -- Read stats from C
	    recipient_details["stats"] = ntop.recipient_stats(recipient_details["recipient_id"])
	 end
      end
   end

   -- Upon success, recipient details are returned, otherwise nil
   return recipient_details
end

-- ##############################################

function recipients.get_all_recipients(exclude_builtin, include_stats)
   local res = {}
   local cur_recipient_ids = _get_assigned_recipient_ids()

   for _, recipient_id in pairs(cur_recipient_ids) do
      local recipient_details = recipients.get_recipient(recipient_id, include_stats)

      if recipient_details and (not exclude_builtin or not recipient_details.endpoint_conf.builtin) then
	 res[#res + 1] = recipient_details
      end
   end

   return res
end

-- ##############################################

function recipients.get_recipient_by_name(name)
   local cur_recipient_ids = _get_assigned_recipient_ids()

   for _, recipient_id in pairs(cur_recipient_ids) do
      local recipient_details = recipients.get_recipient(recipient_id)

      if recipient_details and recipient_details["recipient_name"] and recipient_details["recipient_name"] == name then
	      return recipient_details
      end
   end

   return nil
end

-- ##############################################

local builtin_recipients_cache
function recipients.get_builtin_recipients()
   -- Currently, only sqlite is the builtin recipient
   -- created in startup.lua calling recipients.initialize()
   if not builtin_recipients_cache then
      local alert_store_db_recipient = recipients.get_recipient_by_name("builtin_recipient_alert_store_db")
      builtin_recipients_cache = { alert_store_db_recipient.recipient_id }
   end

   return builtin_recipients_cache
end

-- ##############################################

local function get_notification_category(notification, current_script)
   -- Category is first read from the current_script. If no current_script is found (e.g., for
   -- alerts cenerated from the C++ core such as start after anomalous termination), the category
   -- is guessed from the alert entity.
   local checks = require "checks"
   local entity_id = notification.entity_id

   local cur_category_id
   if current_script and current_script.category and current_script.category.id then
      -- Found in the script
      cur_category_id = current_script.category.id
   else
      --- Determined from the entity
      if entity_id == alert_entities.system.entity_id then
	 -- System alert entity becomes system
         cur_category_id = checks.check_categories.system.id
      else
	 -- All other entities fall into other category
	 cur_category_id = checks.check_categories.other.id
      end
   end

   return cur_category_id or checks.check_categories.other.id
end

-- ##############################################

-- @brief Dispatches a `notification` to all the interested recipients
-- @param notification An alert notification
-- @param current_script The user script which has triggered this notification - can be nil if the script is unknown or not available
-- @return nil
function recipients.dispatch_notification(notification, current_script)
   if(notification) then
      local notification_category = get_notification_category(notification, current_script)
 
      -- Using all recipients for the time being (TODO filter by pool selection)
      local recipients = recipients.get_all_recipients()

      if #recipients > 0 then
	 -- Use pcall to catch possible exceptions, e.g., (string expected, got light userdata)
	 local status, json_notification = pcall(function() return json.encode(notification) end)

	 -- If an exception occurred, print the notification and exit
	 if not status then
	    tprint({notification, json_notification})
	    return
	 end

	 for _, recipient in ipairs(recipients) do
            local recipient_ok = false

            if notification_category and recipient.check_categories ~= nil then
               -- Make sure the user script category belongs to the recipient user script categories
               for _, check_category in pairs(recipient.check_categories) do
                  if check_category == notification_category then
                     recipient_ok = true
                  end
               end
            else
               recipient_ok = true
            end

            if notification.severity and recipient.minimum_severity ~= nil and 
               notification.severity < recipient.minimum_severity then
               -- If the current alert severity is less than the minimum requested severity exclude the recipient
               recipient_ok = false
            end

            if recipient_ok then
               -- Enqueue alert
	       ntop.recipient_enqueue(recipient.recipient_id, json_notification, notification.score, notification_category)
            end
	 end

	 ::continue::
      end
   else
      --      traceError(TRACE_ERROR, TRACE_CONSOLE, "Internal error. Empty notification")
      --      tprint(debug.traceback())
   end
end

-- ##############################################

-- @brief Processes notifications dispatched to recipients
-- @param ready_recipients A table with recipients ready to export. Recipients who completed their work are removed from the table
-- @param now An epoch of the current time
-- @param periodic_frequency The frequency, in seconds, of this call
-- @param force_export A boolean telling to forcefully export dispatched notifications
-- @return nil
local function process_notifications(ready_recipients, now, deadline, periodic_frequency, force_export)
   -- Total budget available, which is a multiple of the periodic_frequency
   -- Budget in this case is the maximum number of notifications which can
   -- be processed during this call.
   local total_budget = 1000 * periodic_frequency
   -- To avoid having one recipient jeopardizing all the resources, the total
   -- budget is consumed in chunks, that is, recipients are iterated multiple times
   -- and, each time any recipient has a maximum budget for every iteration.
   local budget_per_iter = total_budget / #ready_recipients

   -- Put a cap of 1000 messages/iteration
   if(budget_per_iter > 1000) then
      budget_per_iter = 1000
   end
   
   -- Cycle until there are ready_recipients and total_budget left
   local cur_time = os.time()
   while #ready_recipients > 0 and total_budget >= 0 and cur_time <= deadline and (force_export or not ntop.isDeadlineApproaching()) do
      for i = #ready_recipients, 1, -1 do
	 local ready_recipient = ready_recipients[i]
	 local recipient = ready_recipient.recipient
	 local m = ready_recipient.mod

	 if do_trace then tprint("Dequeuing alerts for ready recipient: ".. recipient.recipient_name.. " recipient_id: "..recipient.recipient_id) end

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

-- @brief Check if it time to export notifications towards recipient identified with `recipient_id`, depending on its `xport_frequency`
-- @param recipient_id The integer recipient identifier
-- @param export_frequency The recipient export frequency in seconds
-- @param now The current epoch
-- @return True if it is time to export notifications towards the recipient, or False otherwise
local function check_endpoint_export(recipient_id, export_frequency, now)
   -- Read the epoch of the last time the recipient was used
   local last_use = ntop.recipient_last_use(recipient_id)
   local res = last_use + export_frequency <= now

   return res
end

-- #################################################################

-- @brief Processes notifications dispatched to recipients
-- @param now An epoch of the current time
-- @param periodic_frequency The frequency, in seconds, of this call
-- @param force_export A boolean telling to forcefully export dispatched notifications
-- @return nil
local cached_recipients
function recipients.process_notifications(now, deadline, periodic_frequency, force_export)
   if not areAlertsEnabled() then
      return
   end

   -- Dequeue alerts from the internal C queue
   local alert_utils = require "alert_utils"
   alert_utils.process_notifications_from_c_queue()

   -- Dequeue alerts enqueued into per-recipient queues from checks
   if not cached_recipients then
      -- Cache recipients to avoid re-reading them constantly
      -- NOTE: in case of recipient add/edit/delete, the vm executing this
      -- function is reloaded and thus, recipients, are re-cached automatically
      cached_recipients = recipients.get_all_recipients()
   end
   local modules_by_name = endpoints.get_types()
   local ready_recipients = {}

   -- Check, among all available recipients, those that are ready to export, depending on
   -- their EXPORT_FREQUENCY
   for _, recipient in pairs(cached_recipients) do
      local module_name = recipient.endpoint_key

      if modules_by_name[module_name] then
         local m = modules_by_name[module_name]
	 if force_export or check_endpoint_export(recipient.recipient_id, m.EXPORT_FREQUENCY, now) then
	    -- This recipient is ready for export...
	    local ready_recipient = {recipient = recipient, recipient_id = recipient.recipient_id, mod = m}

	    ready_recipients[#ready_recipients + 1] = ready_recipient
	 end
      end
   end

   process_notifications(ready_recipients, now, deadline, periodic_frequency, force_export)
end

-- ##############################################

-- @brief Cleanup all but builtin recipients
function recipients.cleanup()
   local all_recipients = recipients.get_all_recipients()
   for _, recipient in pairs(all_recipients) do
      recipients.delete_recipient(recipient.recipient_id)
   end

   recipients.initialize()
end

-- ##############################################

return recipients
