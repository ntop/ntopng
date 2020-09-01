--
-- (C) 2017-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

local json = require "dkjson"
local os_utils = require "os_utils"
local lua_path_utils = require "lua_path_utils"
local recipients = require "recipients"

-- ##############################################

local recipients_lua_utils = {}

-- ##############################################

-- @brief Returns an array of recipient Lua class instances, for all available recipients
--        e.g., {sqlite_recipients:create(), ...}
--
local function all_recipient_instances_factory()
   local recipients_dir = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/recipients/")
   lua_path_utils.package_path_prepend(recipients_dir)
   local res = {}

   for recipient_file in pairs(ntop.readdir(recipients_dir)) do
      if recipient_file:match("_recipients%.lua$") then
	 local recipient_module_name = recipient_file:gsub(".lua", "")
	 local recipient_require = os_utils.fixPath(string.format("recipients.%s", recipient_module_name))

	 local recipient = require(recipient_require)

	 if recipient.create then
	    -- If it has a method create, then we can instantiate it and add it to the result
	    local instance = recipient:create()
	    res[#res + 1] = instance
	 end
      end
   end

   return res
end

-- ##############################################

local all_instances_cache

-- @brief Caches all available recipient instances to avoid reloading them every time
local function get_all_instances_cache()
   if not all_instances_cache then
      all_instances_cache = all_recipient_instances_factory()
   end

   return all_instances_cache
end

-- ##############################################

-- @brief Dispatches a trigger `notification` to every available recipient (trigger notifications are generated in `alerts_api.trigger`)
-- @param notification A JSON string with all the alert information
-- @return true If the dispatching has been successfull, false otherwise
function recipients_lua_utils.dispatch_trigger_notification(notification)
   local all_instances = get_all_instances_cache()
   local res = true

   for _, instance in pairs(all_instances) do
      res = res and instance:dispatch_trigger_notification(notification)
   end

   return res
end

-- ##############################################

-- @brief Dispatches a release `notification` to every available recipient (trigger notifications are generated in `alerts_api.release`)
-- @param notification A JSON string with all the alert information
-- @return true If the dispatching has been successfull, false otherwise
function recipients_lua_utils.dispatch_release_notification(notification)
   local all_instances = get_all_instances_cache()
   local res = true

   for _, instance in pairs(all_instances) do
      res = res and instance:dispatch_release_notification(notification)
   end

   return res
end

-- ##############################################

-- @brief Dispatches a store `notification` to every available recipient (trigger notifications are generated in `alerts_api.store`)
-- @param notification A JSON string with all the alert information
-- @return true If the dispatching has been successfull, false otherwise
function recipients_lua_utils.dispatch_store_notification(notification)
   local all_instances = get_all_instances_cache()
   local res = true

   for _, instance in pairs(all_instances) do
      res = res and instance:dispatch_store_notification(notification)
   end

   return res
end

-- ##############################################

-- @brief Processs notifications previously dispatched for every available recipient
function recipients_lua_utils.process_notifications(notification)
   local all_instances = get_all_instances_cache()
   local res = true

   for _, instance in pairs(all_instances) do
      res = res and instance:process_notifications(notification)
   end

   return res
end

-- ##############################################

return recipients_lua_utils
