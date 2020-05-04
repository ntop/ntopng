--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local json = require "dkjson"
local notification_endpoint_consts = plugins_utils.loadModule("notification_endpoints", "notification_endpoint_consts")
local notification_endpoint_configs = plugins_utils.loadModule("notification_endpoints", "notification_endpoint_configs")

-- #################################################################

local ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG = "ntopng.prefs.notification_endpoint.endpoint_recipient_to_endpoint_conf"
local ENDPOINT_RECIPIENTS_KEY = "ntopng.prefs.notification_endpoint.endpoint_config_%s.recipients"

-- #################################################################

local notification_endpoint_recipients = {}

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
   for _, param in ipairs(notification_endpoint_consts.endpoint_types[endpoint_key].recipient_params) do
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

function notification_endpoint_recipients.add_endpoint_recipient(endpoint_conf_name, endpoint_recipient_name, recipient_params)
   local ec = notification_endpoint_configs.get_endpoint_config(endpoint_conf_name)

   if ec["status"] ~= "OK" then
      return ec
   end

   local ok, status = check_endpoint_recipient_name(endpoint_recipient_name)
   if not ok then
      return status
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

function notification_endpoint_recipients.get_endpoint_recipients(endpoint_key, endpoint_conf_name, endpoint_recipient_name)
   local ec = notification_endpoint_configs.get_endpoint_config(endpoint_conf_name)

   if ec["status"] ~= "OK" then
      return ec
   end

   local ok, status = check_endpoint_recipient_name(endpoint_recipient_name)
   if not ok then
      return status
   end

   local k = string.format(ENDPOINT_RECIPIENTS_KEY, endpoint_conf_name)

   return {status = "OK", recipients = ntop.getHashAllCache(k)}
end

-- #################################################################

function notification_endpoint_recipients.reset_endpoint_recipients(endpoint_conf_name)
   local ec = notification_endpoint_configs.get_endpoint_config(endpoint_conf_name)

   if ec["status"] ~= "OK" then
      return ec
   end

   local k = string.format(ENDPOINT_RECIPIENTS_KEY, endpoint_conf_name)
   ntop.delCache(k)

   return {status = "OK"}
end

-- #################################################################

return notification_endpoint_recipients
