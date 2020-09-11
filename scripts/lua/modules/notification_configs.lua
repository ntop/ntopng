--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local json = require "dkjson"

-- #################################################################

-- A key to access a hash table containing mappings between endpoint_conf_name and endpoint_key
-- endpoint_key s are defined inside ./endpoint lua files, such as email.lua
--
-- Example:
-- ntop_mail -> mail
-- customer_1_mail -> mail
-- crew_es -> elasticsearch
--
local ENDPOINT_CONFIG_TO_ENDPOINT_KEY = "ntopng.prefs.notification_endpoint.endpoint_conf_name_endpoint_key"

-- A key to access a hash table containing mappings, for each endpoint_key, between every endpoint_conf_name and conf_params
--
-- Example:
-- notification endpoint mail has two configurations, `ntop_mail` and `customer_1_mail`, so the resulting entry
-- ntopng.prefs.notification_endpoint.endpoint_key_mail.configs is as follows:
-- ntop_mail -> {smtmp_server_name: "...", etc}
-- customer_1_mail -> {smtp_server_name: "...", etc}
--
local ENDPOINT_CONFIGS_KEY = "ntopng.prefs.notification_endpoint.endpoint_key_%s.configs"

-- #################################################################

local notification_configs = {}

-- #################################################################

function notification_configs.get_types(exclude_builtin)
   local endpoint_types = {}

   -- Currently, we load all the available alert endpoints
   local available_endpoints = plugins_utils.getLoadedAlertEndpoints()

   -- Then, we actually consider vaid types for the notification configs
   -- only those modules that have their `conf_params` and `recipient_params`.
   -- Eventually, when the migration between alert endpoints and generic notification endpoints
   -- will be completed, all the available endpoints will have `conf_params` and `recipient_params`.
   for _, endpoint in ipairs(available_endpoints) do
      if endpoint.conf_params and endpoint.recipient_params and endpoint.conf_template and endpoint.recipient_template then
	 for _, k in pairs({"plugin_key", "template_name"}) do
	    if not endpoint.conf_template[k] or not endpoint.recipient_template[k] then
	       goto continue
	    end
	 end

	 -- See if only non-builtin endpoints have been requested (e.g., to populate UI fields)
	 if not exclude_builtin or not endpoint.builtin then
	    endpoint_types[endpoint.key] = endpoint
	 end
      end

      ::continue::
   end

   return endpoint_types
end

-- #################################################################

-- @brief Check if an endpoint configuration with name `endpoint_conf_name` exists
-- @param endpoint_conf_name A string with the configuration name
-- @return true if the configuration exists, false otherwise
local function is_endpoint_config_existing(endpoint_conf_name)
   if not endpoint_conf_name or endpoint_conf_name == "" then
      return false
   end

   local res = ntop.getHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_conf_name)

   if res == nil or res == '' then
      return false
   end

   return true
end

-- #################################################################

-- @brief Set a configuration along with its params. Configuration name and params must be already sanitized
-- @param endpoint_key A string with the notification endpoint key
-- @param endpoint_conf_name A string with the configuration name
-- @param safe_params A table with endpoint configuration params already sanitized
-- @return nil
local function set_endpoint_config_params(endpoint_key, endpoint_conf_name, safe_params)
   -- Write the endpoint conf_name and its key in a hash
   ntop.setHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_conf_name, endpoint_key)
   -- Write the endpoint config in another hash
   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   ntop.setHashCache(k, endpoint_conf_name, json.encode(safe_params))
end

-- #################################################################

-- @brief Read the configuration parameters of an existing configuration
-- @param endpoint_conf_name A string with the configuration name
-- @return A table with two keys: endpoint_key and conf_params or nil if the configuration isn't found
local function read_endpoint_config_raw(endpoint_conf_name)
   local endpoint_key = ntop.getHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_conf_name)

   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   local conf_params = ntop.getHashCache(k, endpoint_conf_name)

   if conf_params and conf_params ~= '' then
      return {endpoint_key = endpoint_key, conf_params = conf_params}
   end
end

-- #################################################################

-- @brief Sanity checks for the endpoint key
-- @param endpoint_key A string with the notification endpoint key
-- @return true if the sanity checks are ok, false otherwise
local function check_endpoint_key(endpoint_key)
   if not notification_configs.get_types()[endpoint_key] then
      return false, {status = "failed", error = {type = "endpoint_not_existing"}}
   end

   return true
end

-- #################################################################

-- @brief Sanity checks for the endpoint configuration name
-- @param endpoint_conf_name A string with the configuration name
-- @return true if the sanity checks are ok, false otherwise
local function check_endpoint_conf_name(endpoint_conf_name)
   if not endpoint_conf_name or endpoint_conf_name == "" then
      return false, {status = "failed", error = {type = "invalid_endpoint_conf_name"}}
   end

   return true
end

-- #################################################################

-- @brief Sanity checks for the endpoint configuration parameters
-- @param endpoint_key A string with the notification endpoint key
-- @param conf_params A table with endpoint configuration params that will be possibly sanitized
-- @return false with a description of the error, or true, with a table containing sanitized configuration params.
local function check_endpoint_config_params(endpoint_key, conf_params)
   if not conf_params or not type(conf_params) == "table" then
      return false, {status = "failed", error = {type = "invalid_conf_params"}}
   end

   -- Create a safe_params table with only expected params
   local endpoint = notification_configs.get_types()[endpoint_key]
   local safe_params = {}
   -- So iterate across all expected params of the current endpoint
   for _, param in ipairs(endpoint.conf_params) do
      -- param is a lua table so we access its elements
      local param_name = param["param_name"]
      local optional = param["optional"]

      if conf_params and conf_params[param_name] and not safe_params[param_name] then
	 safe_params[param_name] = conf_params[param_name]
      elseif not optional then
	 return false, {status = "failed", error = {type = "missing_mandatory_param", missing_param = param_name}}
      end
   end

   return true, {status = "OK", safe_params = safe_params, builtin = endpoint.builtin or false}
end

-- #################################################################

-- @brief Add a new configuration endpoint
-- @param endpoint_key A string with the notification endpoint key
-- @param endpoint_conf_name A string with the configuration name
-- @param conf_params A table with endpoint configuration params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function notification_configs.add_config(endpoint_key, endpoint_conf_name, conf_params)
   local ok, status = check_endpoint_key(endpoint_key)
   if not ok then
      return status
   end

   ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   if is_endpoint_config_existing(endpoint_conf_name) then
      return {status = "failed", error = {type = "endpoint_config_already_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   -- Are the submitted params those expected by the endpoint?
   ok, status = check_endpoint_config_params(endpoint_key, conf_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   if status.builtin then
      -- If the endpoint is a builtin endpoint, a special boolean safe param builtin is added to the configuration
      safe_params["builtin"] = true
   end

   -- Set the config
   set_endpoint_config_params(endpoint_key, endpoint_conf_name, safe_params)

   return {status = "OK"}
end

-- #################################################################

-- @brief Edit the configuration parameters of an existing endpoint
-- @param endpoint_conf_name A string with the configuration name
-- @param conf_params A table with endpoint configuration params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function notification_configs.edit_config(endpoint_conf_name, conf_params)
   local ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_conf_name)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   -- Are the submitted params those expected by the endpoint?
   ok, status = check_endpoint_config_params(ec["endpoint_key"], conf_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   -- Overwrite the config
   set_endpoint_config_params(ec["endpoint_key"], endpoint_conf_name, safe_params)

   return {status = "OK"}
end

-- #################################################################

-- @brief Delete the configuration parameters of an existing endpoint configuration
-- @param endpoint_conf_name A string with the configuration name
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function notification_configs.delete_config(endpoint_conf_name)
   local ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_conf_name)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   -- Delete the all the recipients associated to this config recipients
   local recipients = require "recipients"
   local recipients_instance = recipients:create()
   recipients_instance:delete_recipients_by_conf(endpoint_conf_name)

   -- Now delete the actual config
   local k = string.format(ENDPOINT_CONFIGS_KEY, ec["endpoint_key"])
   ntop.delHashCache(k, endpoint_conf_name)
   ntop.delHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_conf_name)

   return {status = "OK"}
end

-- #################################################################

-- @brief Retrieve the configuration parameters of an existing endpoint configuration
-- @param endpoint_conf_name A string with the configuration name
-- @return A table with a key status which is either "OK" or "failed".
--         When "failed", the table contains another key "error" with an indication of the issue.
--         When "OK", the table contains "endpoint_conf_name", "endpoint_key", and "endpoint_conf" with the results
function notification_configs.get_endpoint_config(endpoint_conf_name)
   local ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_conf_name)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   return {
      status = "OK",
      endpoint_conf_name = endpoint_conf_name,
      endpoint_key = ec["endpoint_key"],
      endpoint_conf = json.decode(ec["conf_params"])
   }
end

-- #################################################################

-- @brief Retrieve all the available configurations and configuration params
-- @param exclude_builtin Whether to exclude builtin configs. Default is false.
-- @return A lua array with a as many elements as the number of existing configurations.
--         Each element is the result of `notification_configs.get_endpoint_config`
function notification_configs.get_configs(exclude_builtin)
   local res = {}

   for endpoint_key, endpoint in pairs(notification_configs.get_types()) do
      local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
      local all_configs = ntop.getHashAllCache(k) or {}

      for conf_name, conf_params in pairs(all_configs) do
	 local ec = notification_configs.get_endpoint_config(conf_name)

	 if not exclude_builtin or not ec.endpoint_conf.builtin then
	    res[#res + 1] = ec
	 end
      end
   end

   return res
end

-- #################################################################

-- @brief Retrieve all the available configurations, configuration params, and associated recipients
-- @return A lua array with as many elements as the number of existing configurations.
--         Each element is the result of `notification_configs.get_endpoint_config`
--         with an extra key `recipients`.
function notification_configs.get_configs_with_recipients()
   local recipients = require "recipients"
   local recipients_instance = recipients:create()
   local configs = notification_configs.get_configs()

   for conf_name, conf in pairs(configs) do
      conf["recipients"] = recipients_instance:get_recipients_by_conf(conf.endpoint_conf_name)
   end

   return configs
end

-- #################################################################

-- @brief Clear all the existing endpoint configurations
-- @return Always return a table {status = "OK"}
function notification_configs.reset_configs()
   for endpoint_key, endpoint in pairs(notification_configs.get_types()) do
      if not endpoint.builtin then
	 local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
	 local all_configs = ntop.getHashAllCache(k) or {}

	 for conf_name, conf_params in pairs(all_configs) do
	    notification_configs.delete_config(conf_name)
	 end

	 ntop.delCache(k)
      end
   end

   return {status = "OK"}
end

-- #################################################################

return notification_configs
