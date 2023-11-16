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

-- Get the checks configuration
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

-- Save the checks configuration.
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

-- ##############################################

-- Get the configuration to use for a specific entity
-- @param user_script the user script, loaded with user_scripts.load
-- @param (optional) hook the hook function
-- @param (optional) entity_value the entity value
-- @param (optional) is_remote_host, for hosts only, indicates if the entity is a remote host
-- @return the script configuration as a table
function user_scripts.getConfiguration(user_script, hook, entity_value, is_remote_host)
   local rv = nil
   hook = hook or NON_TRAFFIC_ELEMENT_CONF_KEY
   entity_value = entity_value or NON_TRAFFIC_ELEMENT_ENTITY
   local conf = user_script.conf[hook]

   -- A configuration may not exist for the given hook
   if(conf ~= nil) then
      -- Search for this specific entity config
      rv = conf[entity_value]
   end

   if(rv == nil) then
      -- Search for a global/default configuration
      rv = user_scripts.getGlobalConfiguration(user_script, hook, is_remote_host)
   end

   if(rv.script_conf == nil) then
      -- Use the default
      rv.script_conf = user_script.default_value or {}
   end

   return(rv)
end

-- ##############################################

local function get_global_conf_key(is_remote_host)
  return(ternary(is_remote_host, "global_remote", "global"))
end

-- ##############################################

-- Get the global configuration to use for a all the entities of this user_script
-- @param user_script the user script, loaded with user_scripts.load
-- @param hook the hook function
-- @param is_remote_host, for hosts only, indicates if the entity is a remote host
-- @return the script configuration as a table
function user_scripts.getGlobalConfiguration(user_script, hook, is_remote_host)
   local conf = user_script.conf[hook]
   local rv = nil

   if(conf ~= nil) then
      rv = conf[get_global_conf_key(is_remote_host)]
   end

   if(rv == nil) then
      -- No Specific/Global configuration found, try defaults
      rv = user_scripts.getDefaultConfig(user_script, hook)
   end

   return(rv)
end

-- ##############################################

-- Delete the configuration of a specific element (e.g. a specific host)
function user_scripts.deleteSpecificConfiguration(subdir, available_modules, hook, entity_value)
   hook = hook or NON_TRAFFIC_ELEMENT_CONF_KEY
   entity_value = entity_value or NON_TRAFFIC_ELEMENT_ENTITY

   local scripts_conf = available_modules.conf

   for _, script in pairs(available_modules.modules) do
      delete_script_conf(scripts_conf, script.key, hook, entity_value)
   end

   reload_scripts_config(available_modules)
   saveConfiguration(subdir, scripts_conf)
end

-- ##############################################

-- Delete the configuration for all the elements in subdir (e.g. all the hosts)
function user_scripts.deleteGlobalConfiguration(subdir, available_modules, hook, remote_host)
   return(user_scripts.deleteSpecificConfiguration(subdir, available_modules, hook, get_global_conf_key(remote_host)))
end

-- ##############################################

-- For built-in input_builders, return the _POST handler to use
local input_builder_to_post_handler = {
   [user_scripts.threshold_cross_input_builder] = user_scripts.threshold_cross_post_handler,
}

function user_scripts.getDefaultPostHandler(input_builder)
   return(input_builder_to_post_handler[input_builder])
end

-- ##############################################

function user_scripts.checkbox_input_builder(gui_conf, submit_field, active)
   local on_value = "on"
   local off_value = "off"
   local value
   local on_color = "success"
   local off_color = "danger"
   submit_field = "enabled_" .. submit_field

   local on_active
   local off_active

   if active then

      value = on_value
      on_active  = "btn-"..on_color.." active"
      off_active = "btn-secondary"
   else
      value = off_value
      on_active  = "btn-secondary"
      off_active = "btn-"..off_color.." active"
   end

   return [[
  <div class="btn-group btn-toggle">
  <button type="button" onclick="]]..submit_field..[[_on_fn()" id="]]..submit_field..[[_on_id" class="btn btn-sm ]]..on_active..[[">On</button>
  <button type="button" onclick="]]..submit_field..[[_off_fn()" id="]]..submit_field..[[_off_id" class="btn btn-sm ]]..off_active..[[">Off</button>
  </div>
  <input type=hidden id="]]..submit_field..[[_input" name="]]..submit_field..[[" value="]]..value..[["/>
<script>


function ]]..submit_field..[[_on_fn() {
  var class_on = document.getElementById("]]..submit_field..[[_on_id");
  var class_off = document.getElementById("]]..submit_field..[[_off_id");
  class_on.removeAttribute("class");
  class_off.removeAttribute("class");
  class_on.setAttribute("class", "btn btn-sm btn-]]..on_color..[[ active");
  class_off.setAttribute("class", "btn btn-sm btn-secondary");
  $("#]]..submit_field..[[_input").val("]]..on_value..[[").trigger('change');
}

function ]]..submit_field..[[_off_fn() {
  var class_on = document.getElementById("]]..submit_field..[[_on_id");
  var class_off = document.getElementById("]]..submit_field..[[_off_id");
  class_on.removeAttribute("class");
  class_off.removeAttribute("class");
  class_on.setAttribute("class", "btn btn-sm btn-secondary");
  class_off.setAttribute("class", "btn btn-sm btn-]]..off_color..[[ active");
  $("#]]..submit_field..[[_input").val("]]..off_value..[[").trigger('change');
}
</script>
]]
end

-- ##############################################

function user_scripts.threshold_cross_input_builder(gui_conf, input_id, value)
  value = value or {}
  local gt_selected = ternary((value.operator or gui_conf.field_operator) == "gt", ' selected="selected"', '')
  local lt_selected = ternary((value.operator or gui_conf.field_operator) == "lt", ' selected="selected"', '')
  local input_op = "op_" .. input_id
  local input_val = "value_" .. input_id

  return(string.format([[<select name="%s">
  <option value="gt"%s ]] .. (ternary(gui_conf.field_operator == "lt", "hidden", "")) .. [[>&gt;</option>
  <option value="lt"%s ]] .. (ternary(gui_conf.field_operator == "gt", "hidden", "")) .. [[>&lt;</option>
</select> <input type="number" class="text-right form-control" min="%s" max="%s" step="%s" style="display:inline; width:12em;" name="%s" value="%s"/> <span>%s</span>]],
    input_op, gt_selected, lt_selected,
    gui_conf.field_min or "0", gui_conf.field_max or "", gui_conf.field_step or "1",
    input_val, value.threshold, i18n(gui_conf.i18n_field_unit))
  )
end

function user_scripts.threshold_cross_post_handler(input_id)
  local input_op = _POST["op_" .. input_id]
  local input_val = tonumber(_POST["value_" .. input_id])

  if(input_val ~= nil) then
    return {
      operator = input_op,
      threshold = input_val,
    }
  end
end
