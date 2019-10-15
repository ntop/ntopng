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

local CALLBACKS_DIR = dirs.installdir .. "/scripts/callbacks"
local PRO_CALLBACKS_DIR = dirs.installdir .. "/pro/scripts/callbacks"

-- Hook points for flow/periodic modules
-- NOTE: keep in sync with the Documentation
user_scripts.script_types = {
  flow = {
    parent_dir = "interface",
    hooks = {"protocolDetected", "statusChanged", "flowEnd", "periodicUpdate"},
  }, traffic_element = {
    parent_dir = "interface",
    hooks = {"min", "5mins", "hour", "day"},
  }, syslog = {
    parent_dir = "syslog",
    hooks = {"handleEvent"},
  }
}

-- ##############################################

-- Table to keep per-subdir then per-module then per-hook benchmarks
--
-- The structure is the following
--
-- table
-- flow table
-- flow.mud table
-- flow.mud.protocolDetected table
-- flow.mud.protocolDetected.tot_elapsed number 0.00031600000000021
-- flow.mud.protocolDetected.tot_num_calls number 4
-- flow.score table
-- flow.score.protocolDetected table
-- flow.score.protocolDetected.tot_elapsed number 0.00013700000000005
-- flow.score.protocolDetected.tot_num_calls number 4
-- flow.score.statusChanged table
-- flow.score.statusChanged.tot_elapsed number 0
-- flow.score.statusChanged.tot_num_calls number 0
local benchmarks = {}

-- ##############################################

function user_scripts.getSubdirectoryPath(script_type, subdir, is_pro)
  local prefix = ternary(is_pro, PRO_CALLBACKS_DIR, CALLBACKS_DIR)
  local path
  
  if not isEmptyString(subdir) and subdir ~= "." then
    path = string.format("%s/%s/%s", prefix, script_type.parent_dir, subdir)
  else
    path = string.format("%s/%s", prefix, script_type.parent_dir)
  end

  return os_utils.fixPath(path)
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

-- @brief Get the default configuration value for the given check module
-- and granularity.
-- @param user_script a user_script returned by user_scripts.load
-- @param granularity_str the target granularity
-- @return nil if there is not default value, the given value otherwise
function user_scripts.getDefaultConfigValue(user_script, granularity_str)
  if((user_script.default_values ~= nil) and (user_script.default_values[granularity_str] ~= nil)) then
    -- granularity specific default
    return(user_script.default_values[granularity_str])
  end

  -- global default
  return(user_script.default_value)
end

-- ##############################################

-- @brief Wrap any hook function to compute its execution time which is then added
-- to the benchmarks table.
--
-- @param subdir the modules subdir
-- @param mod_k the key of the user script
-- @param hook the name of the hook in the user script
-- @param hook_fn the hook function in the user script
--
-- @return function(...) wrapper ready to be called for the execution of hook_fn
local function benchmark_hook_fn(subdir, mod_k, hook, hook_fn)
   return function(...)
      local start  = os.clock()
      local result = {hook_fn(...)}
      local finish = os.clock()
      local elapsed = finish - start

      -- Update benchmark results by addin a function call and the elapsed time of this call
      benchmarks[subdir][mod_k][hook]["tot_num_calls"] = benchmarks[subdir][mod_k][hook]["tot_num_calls"] + 1
      benchmarks[subdir][mod_k][hook]["tot_elapsed"] = benchmarks[subdir][mod_k][hook]["tot_elapsed"] + elapsed

      -- traceError(TRACE_NORMAL,TRACE_CONSOLE, string.format("[%s][elapsed: %.2f][tot_elapsed: %.2f][tot_num_calls: %u]",
      --							   hook, elapsed,
      --							   benchmarks[subdir][mod_k][hook]["tot_elapsed"],
      --							   benchmarks[subdir][mod_k][hook]["tot_num_calls"]))

      return table.unpack(result)
   end
end

-- ##############################################

-- @brief Initializes benchmark facilities for any hook function
--
-- @param subdir the modules subdir
-- @param mod_k the key of the user script
-- @param hook the name of the hook in the user script
-- @param hook_fn the hook function in the user script
--
-- @return function(...) wrapper ready to be called for the execution of hook_fn
local function benchmark_init(subdir, mod_k, hook, hook_fn)
   -- Prepare the benchmark table fo the hook_fn which is being benchmarked
   if not benchmarks[subdir] then
      benchmarks[subdir] = {}
   end

   if not benchmarks[subdir][mod_k] then
      benchmarks[subdir][mod_k] = {}
   end

   if not benchmarks[subdir][mod_k][hook] then
      benchmarks[subdir][mod_k][hook] = {tot_num_calls = 0, tot_elapsed = 0}
   end

   -- Finally prepare and return the hook_fn wrapped with benchmark facilities
   return benchmark_hook_fn(subdir, mod_k, hook, hook_fn)
end

-- ##############################################

local function user_scripts_benchmarks_key(subdir, mod_k, hook)
   local ifid = interface.getId()

   return string.format("ntopng.cache.ifid_%d.user_scripts_benchmarks.subdir_%s.mod_%s.hook_%s", ifid, subdir, mod_k, hook)
end

-- ##############################################

-- @brief Save benchmarks results and possibly print them to stdout
--
-- @param to_stdout dump results also to stdout
function user_scripts.benchmark_dump(to_stdout)
   for subdir, modules in pairs(benchmarks) do
      for mod_k, hooks in pairs(modules) do
	 for hook, hook_benchmark in pairs(hooks) do
	    if hook_benchmark["tot_num_calls"] > 0 then
	       local k = user_scripts_benchmarks_key(subdir, mod_k, hook)
	       ntop.setCache(k, json.encode(hook_benchmark), 3600 --[[ 1 hour --]])

	       if to_stdout then
		  traceError(TRACE_NORMAL,TRACE_CONSOLE,
			     string.format("[%s] %s() [check: %s][elapsed: %.4f][num: %u][speed: %.4f]\n",
					   subdir, hook, mod_k, hook_benchmark["tot_elapsed"], hook_benchmark["tot_num_calls"],
					   hook_benchmark["tot_elapsed"] / hook_benchmark["tot_num_calls"]))
	       end
	    end
	 end
      end
   end
end

-- ##############################################

-- @brief Load benchmarks results 
--
-- @param subdir the modules subdir
-- @param mod_k the key of the user script
local function benchmark_load(subdir, mod_k, hook)
   local k = user_scripts_benchmarks_key(subdir, mod_k, hook)
   local res = ntop.getCache(k)

   if res and res ~= "" then
      local b = json.decode(res)

      if b and b["tot_num_calls"] > 0 and b["tot_elapsed"] > 0 then
	 b["avg_speed"] = b["tot_num_calls"] / b["tot_elapsed"]
      end

      return b
   end
end

-- ##############################################

-- @brief Load the check modules.
-- @params script_type one of user_scripts.script_types
-- @params ifid the interface ID
-- @params subdir the modules subdir
-- @params hook_filter if non nil, only load the check modules for the specified hook
-- @params ignore_disabled if true, also returns disabled check modules
-- @param do_benchmark if true, computes benchmarks for every hook
-- @return {modules = key->user_script, hooks = user_script->function}
function user_scripts.load(script_type, ifid, subdir, hook_filter, ignore_disabled, do_benchmark)
   local rv = {modules = {}, hooks = {}}
   local is_nedge = ntop.isnEdge()
   local alerts_disabled = (not areAlertsEnabled())

   local check_dirs = {
      user_scripts.getSubdirectoryPath(script_type, subdir),
      user_scripts.getSubdirectoryPath(script_type, subdir) .. "/alerts",
   }

   if ntop.isPro() then
      check_dirs[#check_dirs + 1] = user_scripts.getSubdirectoryPath(script_type, subdir, true --[[ pro ]])
      check_dirs[#check_dirs + 1] = user_scripts.getSubdirectoryPath(script_type, subdir, true --[[ pro ]]) .. "/alerts"
   end

   for _, hook in pairs(script_type.hooks) do
      rv.hooks[hook] = {}
   end

   for _, checks_dir in pairs(check_dirs) do
      package.path = checks_dir .. "/?.lua;" .. package.path

      local is_alert_path = string.ends(checks_dir, "alerts")

      for fname in pairs(ntop.readdir(checks_dir)) do
         if ends(fname, ".lua") then
            local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
            local user_script = require(mod_fname)
            local setup_ok = true

            traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Loading check module '%s'", mod_fname))

            if(user_script == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Loading '%s' failed", checks_dir.."/"..fname))
            end

            if(user_script.key == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing 'key' in check module '%s'", mod_fname))
               goto next_module
            end

            if(rv.modules[user_script.key]) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping duplicate module '%s'", user_script.key))
               goto next_module
            end

            if(user_script.nedge_exclude and is_nedge) then
               goto next_module
            end

            if(table.empty(user_script.hooks)) then
               traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("No 'hooks' defined in check module '%s'", user_script.key))
               -- This guarantees that the "hooks" field is always available
               user_script.hooks = {}
            end

            -- Augument with additional attributes
            user_script.enabled = user_scripts.isEnabled(ifid, subdir, user_script.key)
            user_script.is_alert = is_alert_path

            if(alerts_disabled and user_script.is_alert) then
               goto next_module
            end

            if((not user_script.enabled) and (not ignore_disabled)) then
               traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping disabled module '%s'", user_script.key))
               goto next_module
            end

            if(hook_filter ~= nil) then
               -- Only return modules which should be called for the specified hook
               if((user_script.hooks[hook_filter] == nil) and (user_script.hooks["all"] == nil)) then
                  traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for hook '%s'", user_script.key, hook_filter))
                  goto next_module
               end
            end

            -- If a setup function is available, call it
            if(user_script.setup ~= nil) then
               setup_ok = user_script.setup()
            end

            if(not setup_ok) then
               traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' as setup() returned %s", user_script.key, setup_ok))
               goto next_module
            end

	    user_script["benchmark"] = {}

            -- Populate hooks fast lookup table
            for hook, hook_fn in pairs(user_script.hooks) do
	       -- load previously computed benchmarks (if any)
	       -- benchmarks are loaded even if their computation is disabled with a do_benchmark ~= true
               if(hook == "all") then
                  -- Register for all the hooks
                  for _, hook in pairs(script_type.hooks) do
		     user_script["benchmark"][hook] = benchmark_load(subdir, user_script.key, hook)

		     if do_benchmark then
			rv.hooks[hook][user_script.key] = benchmark_init(subdir, user_script.key, hook, hook_fn)
		     else
			rv.hooks[hook][user_script.key] = hook_fn
		     end
                  end

                  -- no more hooks allowed
                  break
               elseif(rv.hooks[hook] == nil) then
                  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unknown hook '%s' in module '%s'", hook, user_script.key))
               else
		  user_script["benchmark"][hook] = benchmark_load(subdir, user_script.key, hook)

		  if do_benchmark then
		     rv.hooks[hook][user_script.key] = benchmark_init(subdir, user_script.key, hook, hook_fn)
		  else
		     rv.hooks[hook][user_script.key] = hook_fn
		  end
               end
            end

            rv.modules[user_script.key] = user_script
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

function user_scripts.flow_checkbox_input_builder(user_script)
   local input_id = string.format("enabled_%s", user_script.key)
   local built = build_on_off_toggle(input_id, user_script.enabled)

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

-- @brief Teardown function, to be called at the end of the VM
function user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
   for _, check in pairs(available_modules.modules) do
      if check.teardown then
         check.teardown()
      end
   end

   if do_benchmark then
      user_scripts.benchmark_dump(do_print_benchmark)
   end
end

-- ##############################################

return(user_scripts)
