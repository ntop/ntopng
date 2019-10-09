--
-- (C) 2019 - ntop.org
--

-- Check modules provide a scriptable way to interact with the ntopng
-- core. Users can provide their own modules to trigger custom alerts,
-- export data, or perform periodic tasks.

local os_utils = require("os_utils")
local json = require("dkjson")

local user_scripts = {}

-- ##############################################

user_scripts.field_units = {
  seconds = "field_units.seconds",
  bytes = "field_units.bytes",
  flows = "field_units.flows",
  packets = "field_units.packets",
  mbits = "field_units.mbits",
  hosts = "field_units.hosts",
  syn_sec = "field_units.syn_sec",
  flow_sec = "field_units.flow_sec",
  percentage = "field_units.percentage",
}

local CHECK_MODULES_BASEDIR = dirs.installdir .. "/scripts/callbacks/interface"
local CHECK_MODULES_PRO_BASEDIR = dirs.installdir .. "/pro/scripts/callbacks/interface"

-- Hook points for flow/periodic modules
local FLOW_HOOKS = {"protocolDetected", "statusChanged", "flowEnd", "periodicUpdate"}
local PERIODIC_HOOKS = {"min", "5mins", "hour", "day"}

-- ##############################################

function user_scripts.getSubdirectoryPath(subdir)
  return os_utils.fixPath(CHECK_MODULES_BASEDIR .. "/" .. subdir)
end

-- ##############################################

local function getCheckModuleConfHash(ifid, subdir, module_key)
   return string.format("ntopng.prefs.user_scripts.conf.%s.ifid_%d.%s", subdir, ifid, module_key)
end

-- ##############################################

-- @brief Enables a check module
function user_scripts.enableModule(ifid, subdir, module_key)
   local hkey = getCheckModuleConfHash(ifid, subdir, module_key)
   ntop.delHashCache(hkey, "disabled")
end

-- ##############################################

-- @brief Disables a check module
function user_scripts.disableModule(ifid, subdir, module_key)
   local hkey = getCheckModuleConfHash(ifid, subdir, module_key)
   ntop.setHashCache(hkey, "disabled", "1")
end

-- ##############################################

-- @brief Checks if a check module is enabled.
-- @return true if disabled, false otherwise
-- @notes Modules are neabled by default. The user can manually turn them off.
function user_scripts.isEnabled(ifid, subdir, module_key)
   local hkey = getCheckModuleConfHash(ifid, subdir, module_key)
   return(ntop.getHashCache(hkey, "disabled") ~= "1")
end

-- ##############################################

local function flow_user_scripts_benchmarks_key(mod_k)
   local ifid = interface.getId()

   return string.format("ntopng.cache.ifid_%d.flow_user_scripts_benchmarks.mod_%s", ifid, mod_k)
end

-- ##############################################

-- Load previous benchmark infor
local function getFlowBenchmarks(mod_k)
   local k = flow_user_scripts_benchmarks_key(mod_k)
   -- ntop.delCache(k)
   local res = ntop.getHashAllCache(k)

   for mod_fn, benchmark in pairs(res or {}) do
      res[mod_fn] = json.decode(benchmark)
   end

   return res
end

-- ##############################################

-- @brief Save flow.lua benchmarks results
function user_scripts.storeFlowBenchmarks(benchmarks)
   for mod_k, modules in pairs(benchmarks or {}) do
      local k = flow_user_scripts_benchmarks_key(mod_k)


      for mod_fn, mod_benchmark in pairs(modules) do
         ntop.setHashCache(k, mod_fn, json.encode(mod_benchmark))
      end
   end
end

-- ##############################################

-- @brief Get the default configuration value for the given check module
-- and granularity.
-- @param check_module a check_module returned by user_scripts.load
-- @param granularity_str the target granularity
-- @return nil if there is not default value, the given value otherwise
function user_scripts.getDefaultConfigValue(check_module, granularity_str)
  if((check_module.default_values ~= nil) and (check_module.default_values[granularity_str] ~= nil)) then
    -- granularity specific default
    return(check_module.default_values[granularity_str])
  end

  -- global default
  return(check_module.default_value)
end

-- ##############################################

-- @brief Load the check modules.
-- @params ifid the interface ID
-- @params subdir the modules subdir
-- @params hook_filter if non nil, only load the check modules for the specified hook
-- @params ignore_disabled if true, also returns disabled check modules
-- @return {modules = key->check_module, hooks = check_module->function}
function user_scripts.load(ifid, subdir, hook_filter, ignore_disabled)
   local rv = {modules = {}, hooks = {}}
   local is_nedge = ntop.isnEdge()

   local check_dirs = {
      CHECK_MODULES_BASEDIR .. "/" .. subdir,
      CHECK_MODULES_BASEDIR .. "/" .. subdir .. "/alerts",
   }

   if ntop.isPro() then
      check_dirs[#check_dirs + 1] = CHECK_MODULES_PRO_BASEDIR .. "/" .. subdir
      check_dirs[#check_dirs + 1] = CHECK_MODULES_PRO_BASEDIR .. "/" .. subdir .. "/alerts"
   end

   -- Load hook table keys
   local available_hooks = ternary(subdir == "flow", FLOW_HOOKS, PERIODIC_HOOKS)

   for _, hook in pairs(available_hooks) do
      rv.hooks[hook] = {}
   end

   for _, checks_dir in pairs(check_dirs) do
      checks_dir = os_utils.fixPath(checks_dir)
      package.path = checks_dir .. "/?.lua;" .. package.path

      local is_alert_path = string.ends(checks_dir, "alerts")

      for fname in pairs(ntop.readdir(checks_dir)) do
         if ends(fname, ".lua") then
            local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
            local check_module = require(mod_fname)
            local setup_ok = true

            traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Loading check module '%s'", mod_fname))

            if(check_module == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Loading '%s' failed", checks_dir.."/"..fname))
            end

            if(check_module.key == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing 'key' in check module '%s'", mod_fname))
               goto next_module
            end

            if(rv.modules[check_module.key]) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping duplicate module '%s'", check_module.key))
               goto next_module
            end

            if(check_module.nedge_exclude and is_nedge) then
               goto next_module
            end

            if(table.empty(check_module.hooks)) then
               traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("No 'hooks' defined in check module '%s'", check_module.key))
               -- This guarantees that the "hooks" field is always available
               check_module.hooks = {}
            end

            -- Augument with additional attributes
            check_module.enabled = user_scripts.isEnabled(ifid, subdir, check_module.key)
            check_module.is_alert = is_alert_path

            if((not check_module.enabled) and (not ignore_disabled)) then
               traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping disabled module '%s'", check_module.key))
               goto next_module
            end

            if(hook_filter ~= nil) then
               -- Only return modules which should be called for the specified hook
               if((check_module.hooks[hook_filter] == nil) and (check_module.hooks["all"] == nil)) then
                  traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for hook '%s'", check_module.key, hook_filter))
                  goto next_module
               end
            end

            -- If a setup function is available, call it
            if(check_module.setup ~= nil) then
               setup_ok = check_module.setup()
            end

            if(not setup_ok) then
               traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' as setup() returned %s", check_module.key, setup_ok))
               goto next_module
            end

            check_module["benchmark"] = getFlowBenchmarks(check_module.key)

            -- Populate hooks fast lookup table
            for hook, hook_fn in pairs(check_module.hooks) do
               if(hook == "all") then
                  -- Register for all the hooks
                  for _, hook in pairs(available_hooks) do
                     rv.hooks[hook][check_module.key] = hook_fn
                  end

                  -- no more hooks allowed
                  break
               elseif(rv.hooks[hook] == nil) then
                  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unkown hook '%s' in module '%s'", hook, check_module.key))
               else
                  rv.hooks[hook][check_module.key] = hook_fn
               end
            end

            rv.modules[check_module.key] = check_module
         end

         ::next_module::
      end
   end

   return(rv)
end

-- ##############################################

function user_scripts.runPeriodicScripts(granularity)
   if(granularity == "min") then
      interface.checkInterfaceAlertsMin()
      interface.checkHostsAlertsMin()
      interface.checkNetworksAlertsMin()
   elseif(granularity == "5mins") then
      interface.checkInterfaceAlerts5Min()
      interface.checkHostsAlerts5Min()
      interface.checkNetworksAlerts5Min()
   elseif(granularity == "hour") then
      interface.checkInterfaceAlertsHour()
      interface.checkHostsAlertsHour()
      interface.checkNetworksAlertsHour()
   elseif(granularity == "day") then
      interface.checkInterfaceAlertsDay()
      interface.checkHostsAlertsDay()
      interface.checkNetworksAlertsDay()
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown granularity " .. granularity)
   end
end

-- ##############################################

local function build_on_off_toggle(submit_field, active)
   local on_value = "on"
   local off_value = "off"
   local value
   local on_color = "success"
   local off_color = "danger"

   local on_active
   local off_active

   if active then

      value = on_value
      on_active  = "btn-"..on_color.." active"
      off_active = "btn-default"
   else
      value = off_value
      on_active  = "btn-default"
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
  class_off.setAttribute("class", "btn btn-sm btn-default");
  $("#]]..submit_field..[[_input").val("]]..on_value..[[").trigger('change');
}

function ]]..submit_field..[[_off_fn() {
  var class_on = document.getElementById("]]..submit_field..[[_on_id");
  var class_off = document.getElementById("]]..submit_field..[[_off_id");
  class_on.removeAttribute("class");
  class_off.removeAttribute("class");
  class_on.setAttribute("class", "btn btn-sm btn-default");
  class_off.setAttribute("class", "btn btn-sm btn-]]..off_color..[[ active");
  $("#]]..submit_field..[[_input").val("]]..off_value..[[").trigger('change');
}
</script>
]]
end

-- ##############################################

function user_scripts.checkbox_input_builder(gui_conf, input_id, value)
   local built = build_on_off_toggle(input_id, value == 1)

   return built
end

-- ##############################################

function user_scripts.flow_checkbox_input_builder(check_module)
   local input_id = string.format("enabled_%s", check_module.key)
   local built = build_on_off_toggle(input_id, check_module.enabled)

   return built
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
    input_val, value.edge, i18n(gui_conf.i18n_field_unit))
  )
end

-- ##############################################

return(user_scripts)
