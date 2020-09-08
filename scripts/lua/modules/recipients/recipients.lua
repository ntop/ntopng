--
-- (C) 2017-20 - ntop.org
--

local json = require "dkjson"
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

   if args then
      -- Initialization is only run if a subclass is being instanced, that is,
      -- when args is not nil
      this:_initialize()
   end

   return this
end

-- ##############################################

-- @brief Performs initialization operations at the time when the instance is created
function recipients:_initialize()
   -- Possibly create a default recipient (if not existing)
end

-- ##############################################

function recipients:_get_recipients_lock_key()
   local key = string.format("ntopng.cache.recipients.recipients_lock")

   return key
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

function recipients:_get_next_recipient_id_key()
   local key = string.format("%s.next_recipient_id", self:_get_recipients_prefix_key())

   return key
end

-- ##############################################

function recipients:_get_recipient_ids_key()
   local key = string.format("%s.recipient_ids", self:_get_recipients_prefix_key())

   return key
end

-- ##############################################

function recipients:_get_recipient_details_key(recipient_id)
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
   local ret = false

   local locked = self:_lock()

   if locked then
      -- Make sure the recipient exists
      local cur_recipient_details = self:get_recipient(recipient_id)

      if cur_recipient_details then
	 -- Remove the key with all the recipient details (e.g., with members, and configset_id)
	 ntop.delCache(self:_get_recipient_details_key(recipient_id))

	 -- Remove the recipient_id from the set of all currently existing recipient ids
	 ntop.delMembersCache(self:_get_recipient_ids_key(), string.format("%d", recipient_id))

	 -- Finally, remove the recipient from C
	 ntop.recipient_delete(recipient_id)
	 ret = true
      end

      self:_unlock()
   end

   return ret
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
      endpoint_conf = ec,
      recipient_params = safe_params,
   }

   -- Get endpoint module

   local modules_by_name = notification_configs.get_types()
   local module_name = recipient.endpoint_conf.endpoint_key
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

function recipients:get_all_recipients()
   local res = {}
   local cur_recipient_ids = self:_get_assigned_recipient_ids()

   for _, recipient_id in pairs(cur_recipient_ids) do
      local recipient_details = self:get_recipient(recipient_id)

      if recipient_details then
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
      ntop.delCache(self:_get_next_recipient_id_key())

      self:_unlock()
   end
end

-- ##############################################

return recipients
