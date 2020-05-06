--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local json = require "dkjson"
local notification_endpoints = require("notification_endpoints")

-- #################################################################

local ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG = "ntopng.prefs.notification_endpoint.endpoint_recipient_to_endpoint_conf"
local ENDPOINT_RECIPIENTS_KEY = "ntopng.prefs.notification_endpoint.endpoint_config_%s.recipients"

-- #################################################################

local notification_recipients = {}

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
   for _, param in ipairs(notification_endpoints.get_types()[endpoint_key].recipient_params) do
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
   local ec = notification_endpoints.get_endpoint_config(endpoint_conf_name)

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

   local ec = notification_endpoints.get_endpoint_config(rc["endpoint_conf_name"])

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

   return {
      status = "OK",
      endpoint_conf_name = rc["endpoint_conf_name"],
      recipient_params = json.decode(rc["recipient_params"])
   }
end

-- #################################################################

function notification_recipients.get_recipients()
   local res = {}
   local all_recipients = ntop.getHashAllCache(ENDPOINT_RECIPIENT_TO_ENDPOINT_CONFIG)

   for recipient_name, config_name in pairs(all_recipients or {}) do
      res[#res + 1] = notification_recipients.get_recipient(recipient_name)
   end

   return res
end

-- #################################################################

function notification_recipients.delete_recipient(endpoint_recipient_name)
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

   return {status = "OK"}
end

-- #################################################################

function notification_recipients.delete_recipients(endpoint_conf_name)
   local ec = notification_endpoints.get_endpoint_config(endpoint_conf_name)

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

return notification_recipients
