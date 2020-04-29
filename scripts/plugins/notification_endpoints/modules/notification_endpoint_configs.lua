--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local notification_endpoint_consts = plugins_utils.loadModule("notification_endpoints", "notification_endpoint_consts")
local json = require "dkjson"

-- #################################################################

local ENDPOINT_CONFIGS_KEY = "ntopng.prefs.notification_endpoint.endpoint_key_%s.configs"

-- #################################################################

local notification_endpoint_configs = {}

-- #################################################################

local function read_endpoint_config_raw(endpoint_key, endpoint_conf_name)
   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   local res = ntop.getHashCache(k, endpoint_conf_name)

   return res ~= '' and res or nil
end

-- #################################################################

local function check_endpoint_key(endpoint_key)
   if not notification_endpoint_consts.endpoint_types[endpoint_key] then
      return false, {status = "failed", error = {type = "endpoint_not_existing"}}
   end

   return true
end

-- #################################################################

local function check_endpoint_conf_name(endpoint_conf_name)
   if not endpoint_conf_name or endpoint_conf_name == "" then
      return false, {status = "failed", error = {type = "invalid_endpoint_conf_name"}}
   end

   return true
end

-- #################################################################

function notification_endpoint_configs.add_endpoint_config(endpoint_key, endpoint_conf_name, conf_params)
   local ok, status = check_endpoint_key(endpoint_key)
   if not ok then
      return status
   end

   ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_key, endpoint_conf_name)
   if ec then
      return {status = "failed", error = {type = "endpoint_config_already_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   if not conf_params or not type(conf_params) == "table" then
      return {status = "failed", error = {type = "invalid_conf_params"}}
   end

   -- Create a safe_params table with only expected params
   local safe_params = {}
   -- So iterate across all expected params of the current endpoint
   for _, param in ipairs(notification_endpoint_consts.endpoint_types[endpoint_key].conf_params) do
      -- param is a lua table so we access its elements
      local param_name = param["param_name"]
      local optional = param["optional"]

      if conf_params and conf_params[param_name] and not safe_params[param_name] then
	 safe_params[param_name] = conf_params[param_name]
      elseif not optional then
	 return {status = "failed", error = {type = "missing_mandatory_param", missing_param = param_name}}
      end
   end

   -- Set the config
   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   ntop.setHashCache(k, endpoint_conf_name, json.encode(safe_params))

   return {status = "OK"}
end

-- #################################################################

function notification_endpoint_configs.delete_endpoint_config(endpoint_key, endpoint_conf_name)
   local ok, status = check_endpoint_key(endpoint_key)
   if not ok then
      return status
   end

   ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_key, endpoint_conf_name)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_conf_name}}
   end


   -- Set the config
   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   ntop.delHashCache(k, endpoint_conf_name)

   return {status = "OK"}
end

-- #################################################################

function notification_endpoint_configs.get_endpoint_config(endpoint_key, endpoint_conf_name)
   local ok, status = check_endpoint_key(endpoint_key)
   if not ok then
      return status
   end

   ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_key, endpoint_conf_name)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   return {status = "OK", endpoint_key = endpoint_key, endpoint_conf_name = endpoint_conf_name, endpoint_conf =json.decode(ec)}
end

-- #################################################################

function notification_endpoint_configs.reset_endpoint_configs()
   local notification_endpoint_recipients = plugins_utils.loadModule("notification_endpoints", "notification_endpoint_recipients")

   for endpoint_key, endpoint in pairs(notification_endpoint_consts.endpoint_types) do
      local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
      local all_configs = ntop.getHashAllCache(k) or {}

      for conf_name, conf_params in pairs(all_configs) do
	 notification_endpoint_recipients.reset_endpoint_recipients(endpoint_key, conf_name)
      end

      ntop.delCache(k)
   end

   return {status = "OK"}
end

-- #################################################################

return notification_endpoint_configs
