--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

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

-- A key to access a hash table containing mappings, for each endpoint_key, between every endpoint_conf_name and endpoint_params
--
-- Example:
-- notification endpoint mail has two configurations, `ntop_mail` and `customer_1_mail`, so the resulting entry
-- ntopng.prefs.notification_endpoint.endpoint_key_mail.configs is as follows:
-- ntop_mail -> {smtmp_server_name: "...", etc}
-- customer_1_mail -> {smtp_server_name: "...", etc}
--
local ENDPOINT_CONFIGS_KEY = "ntopng.prefs.notification_endpoint.endpoint_key_%s.configs"

-- A key to atomically generate integer endpoint ids
local ENDPOINT_NEXT_ID_KEY = "ntopng.prefs.notification_endpoint.next_endpoint_id"

-- #################################################################

local endpoints = {}

-- #################################################################

-- Key where it's saved a boolean indicating if the first endpoint has been created
endpoints.FIRST_ENDPOINT_CREATED_CACHE_KEY = "ntopng.prefs.endpoint_hints.endpoint_created"

-- #################################################################

function endpoints.get_types(exclude_builtin)
   local endpoint_types = {}

   -- Currently, we load all the available alert endpoints
   local available_endpoints = plugins_utils.getLoadedAlertEndpoints()

   -- Then, we actually consider vaid types for the notification configs
   -- only those modules that have their `endpoint_params` and `recipient_params`.
   -- Eventually, when the migration between alert endpoints and generic notification endpoints
   -- will be completed, all the available endpoints will have `endpoint_params` and `recipient_params`.
   for _, endpoint in ipairs(available_endpoints) do
      if endpoint.endpoint_params and endpoint.recipient_params and endpoint.endpoint_template and endpoint.recipient_template then
	 for _, k in pairs({"plugin_key", "template_name"}) do
	    if not endpoint.endpoint_template[k] or not endpoint.recipient_template[k] then
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

-- @brief Check if an endpoint configuration identified with `endpoint_id` exists
-- @param endpoint_conf_name A string with the configuration name
-- @return true if the configuration exists, false otherwise
local function is_endpoint_config_existing(endpoint_conf_name)
   local configs = endpoints.get_configs()

   for _, conf in pairs(configs) do
      if conf.endpoint_conf_name == endpoint_conf_name then
	 -- Another endpoint with the same name already existing
	 return true, conf
      end
   end

   -- No other endpoint exists with the same name
   return false
end

-- #################################################################

-- @brief Set a configuration along with its params. Configuration name and params must be already sanitized
-- @param endpoint_key A string with the notification endpoint key
-- @param endpoint_id An integer identifier of the endpoint
-- @param endpoint_conf_name A string with the configuration name
-- @param safe_params A table with endpoint configuration params already sanitized
-- @return nil
local function set_endpoint_config_params(endpoint_key, endpoint_id, endpoint_conf_name, safe_params)
   if tonumber(endpoint_id) then
      -- Format the integer identifier as a string representation of the same integer
      -- This is necessary as subsequent Redis cache sets work with strings and not integers
      endpoint_id = string.format("%d", endpoint_id)
   else
      -- backward compatibility: we can ignore the cast to id because the it's a string (old endpoint type id)
   end

   -- Write the endpoint conf_name and its key in a hash
   ntop.setHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_id, endpoint_key)

   -- Before storing the configuration as safe_params, we need to extend safe_params
   -- to also include the endpoint configuration name.
   -- This is necessary as endpoints are identified with integers in newer implementations
   -- so the name must be stored in the configuration
   safe_params["endpoint_conf_name"] = endpoint_conf_name
   -- Endpoint config is the merge of safe_params plus the endpoint_conf_name

   -- Write the endpoint config in another hash
   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   ntop.setHashCache(k, endpoint_id, json.encode(safe_params))
end

-- #################################################################

-- @brief Read the configuration parameters of an existing configuration
-- @param endpoint_id An integer identifier of the endpoint
-- @return A table with two keys: endpoint_key and endpoint_params or nil if the configuration isn't found
local function read_endpoint_config_raw(endpoint_id)
   if tonumber(endpoint_id) then
      -- Subsequent Redis keys access work with strings so, the integer must be converted to its string representation
      endpoint_id = string.format("%d", endpoint_id)
   else
      -- Old endpoint configs were strings, so there's nothing to do here
   end

   local endpoint_key = ntop.getHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_id)

   local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
   -- Endpoint params are saved as JSON
   local endpoint_params_json = ntop.getHashCache(k, endpoint_id)
   -- Decode params as a table
   local endpoint_params = json.decode(endpoint_params_json)

   if endpoint_params and endpoint_params ~= '' then
      return {
	 endpoint_key = endpoint_key,
	 endpoint_id = endpoint_id,
	 -- For backward compatibility, endpoint_id is returned as the endpoint_conf_name when not name is found inside endpoint_conf
	 endpoint_conf_name = endpoint_params.endpoint_conf_name or endpoint_id,
	 endpoint_params = endpoint_params
      }
   end
end

-- #################################################################

-- @brief Sanity checks for the endpoint key
-- @param endpoint_key A string with the notification endpoint key
-- @return true if the sanity checks are ok, false otherwise
local function check_endpoint_key(endpoint_key)
   if not endpoints.get_types()[endpoint_key] then
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
-- @param endpoint_params A table with endpoint configuration params that will be possibly sanitized
-- @return false with a description of the error, or true, with a table containing sanitized configuration params.
local function check_endpoint_config_params(endpoint_key, endpoint_params)
   if not endpoint_params or not type(endpoint_params) == "table" then
      return false, {status = "failed", error = {type = "invalid_endpoint_params"}}
   end

   -- Create a safe_params table with only expected params
   local endpoint = endpoints.get_types()[endpoint_key]
   local safe_params = {}
   -- So iterate across all expected params of the current endpoint
   for _, param in ipairs(endpoint.endpoint_params) do
      -- param is a lua table so we access its elements
      local param_name = param["param_name"]
      local optional = param["optional"]

      if endpoint_params and endpoint_params[param_name] and not safe_params[param_name] then
	 safe_params[param_name] = endpoint_params[param_name]
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
-- @param endpoint_params A table with endpoint configuration params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function endpoints.add_config(endpoint_key, endpoint_conf_name, endpoint_params)
   local ok, status = check_endpoint_key(endpoint_key)
   if not ok then
      return status
   end

   ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- Is the config already existing?
   local is_existing, existing_conf = is_endpoint_config_existing(endpoint_conf_name)
   if is_existing then
      return {status = "failed",
	      endpoint_id = existing_conf.endpoint_id,
	      endpoint_conf_name = existing_conf.endpoint_conf_name,

	      error = {
		 type = "endpoint_config_already_existing",
		 endpoint_conf_name = existing_conf.endpoint_conf_name,
	      }
      }
   end

   -- Are the submitted params those expected by the endpoint?
   ok, status = check_endpoint_config_params(endpoint_key, endpoint_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   if status.builtin then
      -- If the endpoint is a builtin endpoint, a special boolean safe param builtin is added to the configuration
      safe_params["builtin"] = true
   else
      if isEmptyString(ntop.getPref(endpoints.FIRST_ENDPOINT_CREATED_CACHE_KEY)) then
         -- set a flag to indicate that an endpoint has been created
         ntop.setPref(endpoints.FIRST_ENDPOINT_CREATED_CACHE_KEY, "1")
      end
   end

   -- Set the config

   -- Atomically generate and endpoint identificator
   local endpoint_id = ntop.incrCache(ENDPOINT_NEXT_ID_KEY)

   -- Save endpoint params, along with the newly generated identificator
   set_endpoint_config_params(endpoint_key, endpoint_id, endpoint_conf_name, safe_params)

   return {
      status = "OK",
      endpoint_id = endpoint_id -- This is the newly assigned enpoint it
   }
end

-- #################################################################

-- @brief Edit the configuration parameters of an existing endpoint
-- @param endpoint_id An integer identifier of the endpoint
-- @param endpoint_conf_name A string with the configuration name
-- @param endpoint_params A table with endpoint configuration params that will be possibly sanitized
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function endpoints.edit_config(endpoint_id, endpoint_conf_name, endpoint_params)

   local ok, status = check_endpoint_conf_name(endpoint_conf_name)
   if not ok then
      return status
   end

   -- TODO: remove when migration of edit_endpoint.lua is complete and passes the id
   if tonumber(endpoint_id) then
      endpoint_id = string.format("%d", endpoint_id)
   else
            -- backward compatibility: we can ignore the cast to id because the it's a string (old endpoint type id)
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_id)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_conf_name}}
   end

   -- Are the submitted params those expected by the endpoint?
   ok, status = check_endpoint_config_params(ec["endpoint_key"], endpoint_params)

   if not ok then
      return status
   end

   local safe_params = status["safe_params"]

   -- Overwrite the config
   set_endpoint_config_params(ec["endpoint_key"], ec["endpoint_id"], endpoint_conf_name, safe_params)

   return {status = "OK"}
end

-- #################################################################

-- @brief Delete the configuration parameters of an existing endpoint configuration
-- @param endpoint_id An integer identifier of the endpoint
-- @return A table with a key status which is either "OK" or "failed". When "failed", the table contains another key "error" with an indication of the issue
function endpoints.delete_config(endpoint_id)
   -- TODO: remove when migration of edit_endpoint.lua is complete and passes the id
   if tonumber(endpoint_id) then
      endpoint_id = string.format("%d", endpoint_id)
   end

   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_id)
   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_id}}
   end

   -- Delete the all the recipients associated to this config recipients
   local recipients = require "recipients"

   recipients.delete_recipients_by_conf(endpoint_id)

   -- Now delete the actual config
   local k = string.format(ENDPOINT_CONFIGS_KEY, ec["endpoint_key"])
   ntop.delHashCache(k, endpoint_id)
   ntop.delHashCache(ENDPOINT_CONFIG_TO_ENDPOINT_KEY, endpoint_id)

   return {status = "OK"}
end

-- #################################################################

-- @brief Retrieve the configuration parameters of an existing endpoint configuration
-- @param endpoint_id An integer identifier of the endpoint
-- @return A table with a key status which is either "OK" or "failed".
--         When "failed", the table contains another key "error" with an indication of the issue.
--         When "OK", the table contains "endpoint_conf_name", "endpoint_key", and "endpoint_conf" with the results
function endpoints.get_endpoint_config(endpoint_id)
   -- Is the config already existing?
   local ec = read_endpoint_config_raw(endpoint_id)

   if not ec then
      return {status = "failed", error = {type = "endpoint_config_not_existing", endpoint_conf_name = endpoint_id}}
   end

   -- Decode endpoint configuration params
   -- NOTE: in newer implementations, configuration params also contain the endpoint name
   --       in older implementations, the endpoint name was used also as endpoint id
   local endpoint_conf = ec["endpoint_params"]

   return {
      status = "OK",
      endpoint_id = endpoint_id,
      -- For backward compatibility, endpoint_id is returned as the endpoint_conf_name when not name is found inside endpoint_conf
      endpoint_conf_name = endpoint_conf["endpoint_conf_name"] or endpoint_id,
      endpoint_key = ec["endpoint_key"],
      endpoint_conf = endpoint_conf
   }
end

-- #################################################################

-- @brief Retrieve all the available configurations and configuration params
-- @param exclude_builtin Whether to exclude builtin configs. Default is false.
-- @return A lua array with a as many elements as the number of existing configurations.
--         Each element is the result of `endpoints.get_endpoint_config`
function endpoints.get_configs(exclude_builtin)
   local res = {}

   for endpoint_key, endpoint in pairs(endpoints.get_types()) do
      local k = string.format(ENDPOINT_CONFIGS_KEY, endpoint_key)
      local all_configs = ntop.getHashAllCache(k) or {}

      for endpoint_id, endpoint_params in pairs(all_configs) do
	 local ec = endpoints.get_endpoint_config(endpoint_id)

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
--         Each element is the result of `endpoints.get_endpoint_config`
--         with an extra key `recipients`.
function endpoints.get_configs_with_recipients(include_stats)
   local recipients = require "recipients"
   local configs = endpoints.get_configs()

   for _, conf in pairs(configs) do
      conf["recipients"] = recipients.get_recipients_by_conf(conf.endpoint_id, include_stats)
   end

   return configs
end

-- #################################################################

-- @brief Clear all the existing endpoint configurations
-- @return Always return a table {status = "OK"}
function endpoints.reset_configs()
   local all_configs = endpoints.get_configs()

   for _, endpoint_params in pairs(all_configs) do
      endpoints.delete_config(endpoint_params.endpoint_id)
   end

   return {status = "OK"}
end

-- #################################################################

-- @brief Restore a full set of configurations, exported with get_configs_with_recipients
-- including configuration params and associated recipients
function endpoints.add_configs_with_recipients(configs)
   local recipients = require "recipients"
   local rc = true

   -- Restore Endpoints
   for _, conf in ipairs(configs) do
      local endpoint_key = conf.endpoint_key
      local endpoint_conf_name = conf.endpoint_conf_name
      local endpoint_params = conf.endpoint_conf

      if endpoint_key and endpoint_conf_name and endpoint_params and conf.recipients and
         not endpoint_params.builtin then

         local ret = endpoints.add_config(endpoint_key, endpoint_conf_name, endpoint_params)

         if not ret or not ret.endpoint_id then
            rc = false
         else
            -- Restore Recipients
            for _, recipient_conf in ipairs(conf.recipients) do
               local endpoint_recipient_name = recipient_conf.recipient_name
               local check_categories = recipient_conf.check_categories
               local minimum_severity = recipient_conf.minimum_severity
               local recipient_params = recipient_conf.recipient_params

               ret = recipients.add_recipient(ret.endpoint_id, endpoint_recipient_name,
					      check_categories, minimum_severity,
					      false, -- Not necessary to bind to every pool: the restore takes care of tis automatically
					      recipient_params)

               if not ret or not ret.status or ret.status ~= "OK" then
                  rc = false
               end
            end
         end
      end
   end

   return rc
end

-- #################################################################

return endpoints
