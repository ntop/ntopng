--
-- (C) 2019 - ntop.org
--

-- Check modules provide a scriptable way to interact with the ntopng
-- core. Users can provide their own modules to trigger custom alerts,
-- export data, or perform periodic tasks.

local os_utils = require("os_utils")
local json = require("dkjson")

local check_modules = {}

-- ##############################################

local CHECK_MODULES_BASEDIR = dirs.installdir .. "/scripts/callbacks/interface"
local CHECK_MODULES_PRO_BASEDIR = dirs.installdir .. "/pro/scripts/callbacks/interface"

-- Hook points for flow/periodic modules
local FLOW_HOOKS = {"protocolDetected", "statusChanged", "idle", "periodicUpdate"}
local PERIODIC_HOOKS = {"min", "5mins", "hour", "day"}

-- ##############################################

function check_modules.getSubdirectoryPath(subdir)
  return os_utils.fixPath(CHECK_MODULES_BASEDIR .. "/" .. subdir)
end

-- ##############################################

local function getCheckModuleConfHash(ifid, subdir, module_key)
   return string.format("ntopng.prefs.check_modules.conf.%s.ifid_%d.%s", subdir, ifid, module_key)
end

-- ##############################################

-- @brief Enables a check module
function check_modules.enableModule(ifid, subdir, module_key)
   local hkey = getCheckModuleConfHash(ifid, subdir, module_key)
   ntop.delHashCache(hkey, "disabled")
end

-- ##############################################

-- @brief Disables a check module
function check_modules.disableModule(ifid, subdir, module_key)
   local hkey = getCheckModuleConfHash(ifid, subdir, module_key)
   ntop.setHashCache(hkey, "disabled", "1")
end

-- ##############################################

-- @brief Checks if a check module is enabled.
-- @return true if disabled, false otherwise
-- @notes Modules are neabled by default. The user can manually turn them off.
function check_modules.isEnabled(ifid, subdir, module_key)
   local hkey = getCheckModuleConfHash(ifid, subdir, module_key)
   return(ntop.getHashCache(hkey, "disabled") ~= "1")
end

-- ##############################################

local function flow_check_modules_benchmarks_key(mod_k)
   local ifid = interface.getId()

   return string.format("ntopng.cache.ifid_%d.flow_check_modules_benchmarks.mod_%s", ifid, mod_k)
end

-- ##############################################

-- Load previous benchmark infor
local function getFlowBenchmarks(mod_k)
   local k = flow_check_modules_benchmarks_key(mod_k)
   -- ntop.delCache(k)
   local res = ntop.getHashAllCache(k)

   for mod_fn, benchmark in pairs(res or {}) do
      res[mod_fn] = json.decode(benchmark)
   end

   return res
end

-- ##############################################

-- @brief Save flow.lua benchmarks results
function check_modules.storeFlowBenchmarks(benchmarks)
   for mod_k, modules in pairs(benchmarks or {}) do
      local k = flow_check_modules_benchmarks_key(mod_k)


      for mod_fn, mod_benchmark in pairs(modules) do
         ntop.setHashCache(k, mod_fn, json.encode(mod_benchmark))
      end
   end
end

-- ##############################################

-- @brief Get the default configuration value for the given check module
-- and granularity.
-- @param check_module a check_module returned by check_modules.load
-- @param granularity_str the target granularity
-- @return nil if there is not default value, the given value otherwise
function check_modules.getDefaultConfigValue(check_module, granularity_str)
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
function check_modules.load(ifid, subdir, hook_filter, ignore_disabled)
   local rv = {modules = {}, hooks = {}}
   local is_nedge = ntop.isnEdge()

   local check_dirs = {
      CHECK_MODULES_BASEDIR .. "/" .. subdir,
   }

   if ntop.isPro() then
      check_dirs[#check_dirs + 1] = CHECK_MODULES_PRO_BASEDIR .. "/" .. subdir
   end

   -- Load hook table keys
   local available_hooks = ternary(subdir == "flow", FLOW_HOOKS, PERIODIC_HOOKS)

   for _, hook in pairs(available_hooks) do
      rv.hooks[hook] = {}
   end

   for _, checks_dir in pairs(check_dirs) do
      checks_dir = os_utils.fixPath(checks_dir)
      package.path = checks_dir .. "/?.lua;" .. package.path

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

            check_module.enabled = check_modules.isEnabled(ifid, subdir, check_module.key)

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

function check_modules.runPeriodicScripts(granularity)
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

return(check_modules)
