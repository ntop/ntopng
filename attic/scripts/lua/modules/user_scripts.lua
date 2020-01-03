-- ##############################################

-- @brief Get the default configuration for the given user script
-- and granularity.
-- @param user_script a user_script returned by user_scripts.load
-- @param granularity_str the target granularity
-- @return a table with the default configuration
function user_scripts.getDefaultConfig(user_script, granularity_str)
   local conf = {script_conf = {}, enabled = user_script.default_enabled}

  if((user_script.default_values ~= nil) and (user_script.default_values[granularity_str] ~= nil)) then
    -- granularity specific default
    conf.script_conf = user_script.default_values[granularity_str] or {}
  else
    conf.script_conf = user_script.default_value or {}
  end

  return(conf)
end

-- ##############################################

local function getConfigurationKey(subdir)
   -- NOTE: strings needed by user_scripts.deleteConfigurations
   -- NOTE: The configuration must not be saved under a specific ifid, since we
   -- allow global interfaces configurations
   return(string.format("ntopng.prefs.user_scripts.conf.%s", subdir))
end

-- ##############################################

-- Get the user scripts configuration
-- @param subdir: the subdir
-- @return a table
-- {[hook] = {entity_value -> {enabled=true, script_conf = {a = 1}, }, ..., default -> {enabled=false, script_conf = {}, }}, ...}
-- @note debug with: redis-cli get ntopng.prefs.user_scripts.conf.interface | python -m json.tool
local function loadConfiguration(subdir)
   local key = getConfigurationKey(subdir)
   local value = ntop.getPref(key)

   if(not isEmptyString(value)) then
      value = json.decode(value) or {}
   else
      value = {}
   end

   return(value)
end

-- ##############################################

-- Save the user scripts configuration.
-- @param subdir: the subdir
-- @param config: the configuration to save
local function saveConfiguration(subdir, config)
   local key = getConfigurationKey(subdir)

   if(table.empty(config)) then
      ntop.delCache(key)
   else
      local value = json.encode(config)
      ntop.setPref(key, value)
   end

   -- Reload the periodic scripts as the configuration has changed
   ntop.reloadPeriodicScripts()
end

-- ##############################################

function user_scripts.deleteConfigurations()
   deleteCachePattern(getConfigurationKey("*"))
end

-- ##############################################

-- This needs to be called whenever the available_modules.conf changes
-- It updates the single scripts config
local function reload_scripts_config(available_modules)
   local scripts_conf = available_modules.conf

   for _, script in pairs(available_modules.modules) do
      script.conf = scripts_conf[script.key] or {}
   end
end

-- ##############################################

local function delete_script_conf(scripts_conf, key, hook, conf_key)
   if(scripts_conf[key] and scripts_conf[key][hook]) then
      scripts_conf[key][hook][conf_key] = nil

      -- Cleanup empty tables
      if table.empty(scripts_conf[key][hook]) then
	 scripts_conf[key][hook] = nil

	 if table.empty(scripts_conf[key]) then
	    scripts_conf[key] = nil
	 end
      end
   end
end


-- ##############################################

function user_scripts.handlePOST(subdir, available_modules, hook, entity_value, remote_host)
   if(table.empty(_POST)) then
      return
   end

   hook = hook or NON_TRAFFIC_ELEMENT_CONF_KEY
   entity_value = entity_value or NON_TRAFFIC_ELEMENT_ENTITY

   local scripts_conf = available_modules.conf

   for _, user_script in pairs(available_modules.modules) do
      -- There are 3 different configurations:
      --  - specific_config: the configuration specific of an host/interface/network
      --  - global_config: the configuration specific for all the (local/remote) hosts, interfaces, networks
      --  - default_config: the default configuration, specified by the user script
      -- They follow the follwing priorities:
      -- 	[lower] specific_config > global_config > default [upper]
      --
      -- Moreover:
      --   - specific_config is only set if it differs from the global_config
      --   - global_config is only set if it differs from the default_config
      --

      -- This is used to represent the previous config in order of priority in order
      -- to determine if the current config differs from its default.
      local upper_config = user_scripts.getDefaultConfig(user_script, hook)

      -- NOTE: we must process the global_config before the specific_config
      for _, prefix in ipairs({"global_", ""}) do
	 local k = prefix .. user_script.key
	 local is_global = (prefix == "global_")
	 local enabled_k = "enabled_" .. k
	 local is_enabled = _POST[enabled_k]
	 local conf_key = ternary(is_global, get_global_conf_key(remote_host), entity_value)
	 local script_conf = nil

	 if(user_script.gui and (user_script.gui.post_handler ~= nil)) then
	    script_conf = user_script.gui.post_handler(k)
	 end

	 if(is_enabled == nil) then
	    -- TODO remove this after changing the gui to support a separate on/off field
	    -- For backward compatibility, an empty configuration means that the script is disabled

	    if(user_script.gui and (user_script.gui.post_handler ~= nil) and (subdir ~= "flow")) then
	       is_enabled = not table.empty(script_conf)
	    else
	       is_enabled = user_script.default_enabled
	    end
	 else
	    is_enabled = (is_enabled == "on")
	 end

	 local cur_config = {
	    enabled = is_enabled,
	    script_conf = script_conf,
	 }

	 if(not table.compare(upper_config, cur_config)) then
	    -- Configuration differs
	    scripts_conf[user_script.key] = scripts_conf[user_script.key] or {}
	    scripts_conf[user_script.key][hook] = scripts_conf[user_script.key][hook] or {}
	    scripts_conf[user_script.key][hook][conf_key] = cur_config
	 else
	    -- Use the default
	    delete_script_conf(scripts_conf, user_script.key, hook, conf_key)
	 end

	 -- Needed for specific_config vs global_config comparison
	 upper_config = cur_config
      end
   end

   reload_scripts_config(available_modules)
   saveConfiguration(subdir, scripts_conf)
end
