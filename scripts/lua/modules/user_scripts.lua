--
-- (C) 2019 - ntop.org
--

-- User scripts provide a scriptable way to interact with the ntopng
-- core. Users can provide their own modules to trigger custom alerts,
-- export data, or perform periodic tasks.

local os_utils = require("os_utils")
local json = require("dkjson")
local plugins_utils = require("plugins_utils")

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
  syn_min = "field_units.syn_min",
}

local CALLBACKS_DIR = plugins_utils.PLUGINS_RUNTIME_PATH .. "/callbacks"
local NON_TRAFFIC_ELEMENT_CONF_KEY = "all"
local NON_TRAFFIC_ELEMENT_ENTITY = "no_entity"
local CONFIGSETS_KEY = "ntopng.prefs.user_scripts.configsets.subdir_%s"
user_scripts.DEFAULT_CONFIGSET_ID = 0

-- NOTE: the subdir id must be unique
-- target_type: when used with configsets, specifies the allowed target.
--   - cidr: IPv4/IPv6 address or CIDR (e.g. 192.168.0.0/16, 1.2.3.4)
--   - interface: a network interface name (e.g. eth0)
--   - network: a local network CIDR (e.g. 192.168.0.0/24)
--   - none: no targets allowed
local available_subdirs = {
   {
      id = "host",
      label = "hosts",
      target_type = "cidr",
   }, {
      id = "flow",
      label = "flows",
      target_type = "interface",
   }, {
      id = "interface",
      label = "interfaces",
      target_type = "interface",
   }, {
      id = "network",
      label = "networks",
      target_type = "network",
   }, {
      id = "snmp_device",
      label = "host_details.snmp",
      target_type = "cidr",
   }, {
      id = "system",
      label = "system",
      target_type = "none",
   }, {
      id = "syslog",
      label = "Syslog",
      target_type = "interface",
   }
}

-- Hook points for flow/periodic modules
-- NOTE: keep in sync with the Documentation
user_scripts.script_types = {
  flow = {
    parent_dir = "interface",
    hooks = {"protocolDetected", "statusChanged", "flowEnd", "periodicUpdate"},
    subdirs = {"flow"},
  }, traffic_element = {
    parent_dir = "interface",
    hooks = {"min", "5mins", "hour", "day"},
    subdirs = {"interface", "host", "network"},
  }, snmp_device = {
    parent_dir = "system",
    hooks = {"snmpDevice", "snmpDeviceInterface"},
    subdirs = {"snmp_device"},
  }, system = {
    parent_dir = "system",
    hooks = {"min", "5mins", "hour", "day"},
    subdirs = {"system"},
  }, syslog = {
    parent_dir = "system",
    hooks = {"handleEvent"},
    subdirs = {"syslog"},
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
  local prefix = CALLBACKS_DIR
  local path

  if not isEmptyString(subdir) and subdir ~= "." then
    path = string.format("%s/%s/%s", prefix, script_type.parent_dir, subdir)
  else
    path = string.format("%s/%s", prefix, script_type.parent_dir)
  end

  return os_utils.fixPath(path)
end

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
      local start  = ntop.getticks()
      local result = {hook_fn(...)}
      local finish = ntop.getticks()
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
   -- NOTE: 5min/hour/day are not monitored. They would collide in the user_scripts_benchmarks_key.
   if((hook ~= "5min") and (hook ~= "hour") and (hook ~= "day")) then
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
   else
      return(hook_fn)
   end
end

-- ##############################################

--~ schema_prefix: "flow_user_script" or "elem_user_script"
function user_scripts.ts_dump(when, ifid, verbose, schema_prefix, all_scripts)
   local ts_utils = require("ts_utils_core")

   for subdir, script_type in pairs(all_scripts) do
      local rv = user_scripts.getAggregatedStats(ifid, script_type, subdir)
      local total = {tot_elapsed = 0, tot_num_calls = 0}

      for modkey, stats in pairs(rv) do
	 ts_utils.append(schema_prefix .. ":duration", {ifid = ifid, user_script = modkey, subdir = subdir, num_ms = stats.tot_elapsed * 1000}, when, verbose)
	 ts_utils.append(schema_prefix .. ":num_calls", {ifid = ifid, user_script = modkey, subdir = subdir, num_calls = stats.tot_num_calls}, when, verbose)

	 total.tot_elapsed = total.tot_elapsed + stats.tot_elapsed
	 total.tot_num_calls = total.tot_num_calls + stats.tot_num_calls
      end

      ts_utils.append(schema_prefix .. ":total_stats", {ifid = ifid, subdir = subdir, num_ms = total.tot_elapsed * 1000, num_calls = total.tot_num_calls}, when, verbose)
   end
end

-- ##############################################

local function user_scripts_benchmarks_key(ifid, subdir)
   return string.format("ntopng.cache.ifid_%d.user_scripts_benchmarks.subdir_%s", ifid, subdir)
end

-- ##############################################

-- @brief Returns the benchmark stats, aggregating them by module
function user_scripts.getAggregatedStats(ifid, script_type, subdir)
   local bencmark = ntop.getCache(user_scripts_benchmarks_key(ifid, subdir))
   local rv = {}

   if(not isEmptyString(bencmark)) then
      bencmark = json.decode(bencmark)

      if(bencmark ~= nil) then
	 for scriptk, hooks in pairs(bencmark) do
	    local aggr_val = {tot_num_calls = 0, tot_elapsed = 0}

	    for _, hook_benchmark in pairs(hooks) do
	       aggr_val.tot_elapsed = aggr_val.tot_elapsed + hook_benchmark.tot_elapsed
	       aggr_val.tot_num_calls = hook_benchmark.tot_num_calls + aggr_val.tot_num_calls
	    end

	    if(aggr_val.tot_num_calls > 0) then
	       rv[scriptk] = aggr_val
	    end
	 end
      end
   end

   return(rv)
end

-- ##############################################

-- @brief Save benchmarks results and possibly print them to stdout
--
-- @param to_stdout dump results also to stdout
function user_scripts.benchmark_dump(ifid, to_stdout)
   -- Convert ticks to seconds
   for subdir, modules in pairs(benchmarks) do
      local rv = {}

      for mod_k, hooks in pairs(modules) do
	 for hook, hook_benchmark in pairs(hooks) do
	    if hook_benchmark["tot_num_calls"] > 0 then
	       hook_benchmark["tot_elapsed"] = hook_benchmark["tot_elapsed"] / ntop.gettickspersec()

	       rv[mod_k] = rv[mod_k] or {}
	       rv[mod_k][hook] = hook_benchmark

	       if to_stdout then
		  traceError(TRACE_NORMAL,TRACE_CONSOLE,
			     string.format("[%s] %s() [script: %s][elapsed: %.4f][num: %u][speed: %.4f]\n",
					   subdir, hook, mod_k, hook_benchmark["tot_elapsed"], hook_benchmark["tot_num_calls"],
					   hook_benchmark["tot_elapsed"] / hook_benchmark["tot_num_calls"]))
	       end
	    end
	 end
      end

      ntop.setCache(user_scripts_benchmarks_key(ifid, subdir), json.encode(rv), 3600 --[[ 1 hour --]])
   end
end

-- ##############################################

local function getScriptsDirectories(script_type, subdir)
   local check_dirs = {
      user_scripts.getSubdirectoryPath(script_type, subdir),
   }

   return(check_dirs)
end

-- ##############################################

-- @brief Lists available user scripts.
-- @params script_type one of user_scripts.script_types
-- @params subdir the modules subdir
-- @return a list of available module names
function user_scripts.listScripts(script_type, subdir)
   local check_dirs = getScriptsDirectories(script_type, subdir)
   local rv = {}

   for _, checks_dir in pairs(check_dirs) do
      for fname in pairs(ntop.readdir(checks_dir)) do
         if string.ends(fname, ".lua") then
            local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
            rv[#rv + 1] = mod_fname
         end
      end
   end

   return rv
end

-- ##############################################

function user_scripts.getLastBenchmark(ifid, subdir)
   local scripts_benchmarks = ntop.getCache(user_scripts_benchmarks_key(ifid, subdir))

   if(not isEmptyString(scripts_benchmarks)) then
      scripts_benchmarks = json.decode(scripts_benchmarks)
   else
      scripts_benchmarks = nil
   end

   return(scripts_benchmarks)
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

local function init_user_script(user_script, mod_fname, full_path, plugin, script_type, subdir, configs)
   user_script.key = mod_fname
   user_script.path = full_path
   user_script.subdir = subdir
   user_script.default_enabled = ternary(user_script.default_enabled == false, false, true --[[ a nil value means enabled ]])
   user_script.source_path = plugins_utils.getUserScriptSourcePath(user_script.path)
   user_script.plugin = plugin
   user_script.script_type = script_type
   user_script.edition = plugin.edition

   -- Load the configuration
   user_script.conf = configs[user_script.key] or {}

   -- TODO remove after gui migration
   if(user_script.gui and (user_script.gui.input_builder == nil)) then
      user_script.gui.input_builder = user_scripts.checkbox_input_builder
   end
   if(user_script.gui and user_script.gui.post_handler == nil) then
      user_script.gui.post_handler = user_scripts.getDefaultPostHandler(user_script.gui.input_builder) or user_scripts.checkbox_post_handler
   end
   -- end TODO

   if(user_script.gui and user_script.gui.input_builder and (not user_script.gui.post_handler)) then
      -- Try to use a default post handler
      user_script.gui.post_handler = user_scripts.getDefaultPostHandler(user_script.gui.input_builder)

      if(user_script.gui.post_handler == nil) then
	 traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Module '%s' is missing the gui.post_handler", user_script.key))
      end
   end

   -- Expand hooks
   if(user_script.hooks["all"] ~= nil) then
      local callback = user_script.hooks["all"]
      user_script.hooks["all"] = nil

      for _, hook in pairs(script_type.hooks) do
	 user_script.hooks[hook] = callback
      end
   end
end

-- ##############################################

-- @brief Load the user scripts.
-- @param ifid the interface ID
-- @param script_type one of user_scripts.script_types
-- @param subdir the modules subdir. *NOTE* this must be unique as it is used as a key.
-- @param options an optional table with the following supported options:
--  - hook_filter: if non nil, only load the user scripts for the specified hook
--  - do_benchmark: if true, computes benchmarks for every hook
--  - return_all: if true, returns all the scripts, even those with filters not matching the current configuration
--    NOTE: this can only be applied if the script type has the "has_no_entity" flag set.
--  - scripts_filter: a filter function(user_script) -> true, false. false will cause the script to be skipped.
-- @return {modules = key->user_script, hooks = user_script->function}
function user_scripts.load(ifid, script_type, subdir, options)
   local rv = {modules = {}, hooks = {}, conf = {}}
   local is_nedge = ntop.isnEdge()
   local is_windows = ntop.isWindows()
   local alerts_disabled = (not areAlertsEnabled())
   local old_ifid = interface.getId()
   local is_pro = ntop.isPro()
   local is_enterprise = ntop.isEnterprise()
   options = options or {}
   ifid = tonumber(ifid)

   -- Load additional schemas
   plugins_utils.loadSchemas(options.hook_filter)

   local hook_filter = options.hook_filter
   local do_benchmark = options.do_benchmark
   local return_all = options.return_all
   local scripts_filter = options.scripts_filter

   if(old_ifid ~= ifid) then
      interface.select(tostring(ifid)) -- required for interface.isPacketInterface() below
   end

   for _, hook in pairs(script_type.hooks) do
      rv.hooks[hook] = {}
   end

   local check_dirs = getScriptsDirectories(script_type, subdir)
   rv.conf = loadConfiguration(subdir)

   for _, checks_dir in pairs(check_dirs) do
      for fname in pairs(ntop.readdir(checks_dir)) do
         if string.ends(fname, ".lua") then
            local setup_ok = true
	    local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
	    local full_path = os_utils.fixPath(checks_dir .. "/" .. fname)
	    local plugin = plugins_utils.getUserScriptPlugin(full_path)

	    if(plugin == nil) then
	       traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Skipping unknown user script '%s'", mod_fname))
	       goto next_module
	    end

	    -- Recheck the edition as the demo mode may expire
	    if((plugin.edition == "pro" and (not is_pro)) or
	       ((plugin.edition == "enterprise" and (not is_enterprise)))) then
	       traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping user script '%s' with '%s' edition", mod_fname, plugin.edition))
	       goto next_module
	    end

            traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Loading user script '%s'", mod_fname))

            local user_script = dofile(full_path)

            if(type(user_script) ~= "table") then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Loading '%s' failed", full_path))
               goto next_module
            end

            if(rv.modules[mod_fname]) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping duplicate module '%s'", mod_fname))
               goto next_module
            end

            if((not return_all) and user_script.packet_interface_only and (not interface.isPacketInterface())) then
               traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for non packet interface", mod_fname))
               goto next_module
            end

            if((not return_all) and ((user_script.nedge_exclude and is_nedge) or (user_script.nedge_only and (not is_nedge)))) then
               goto next_module
            end

            if((not return_all) and (user_script.windows_exclude and is_windows)) then
               goto next_module
            end

            if(table.empty(user_script.hooks)) then
               traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("No 'hooks' defined in user script '%s', skipping", mod_fname))
               goto next_module
            end

	    if(user_script.l7_proto ~= nil) then
	       user_script.l7_proto_id = interface.getnDPIProtoId(user_script.l7_proto)

	       if(user_script.l7_proto_id == -1) then
		  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unknown L7 protocol filter '%s' in user script '%s', skipping", user_script.l7_proto, mod_fname))
		  goto next_module
	       end
	    end

            -- Augument with additional attributes
	    init_user_script(user_script, mod_fname, full_path, plugin, script_type, subdir, rv.conf)

	    if((not return_all) and alerts_disabled and user_script.is_alert) then
	       goto next_module
	    end

	    if(hook_filter ~= nil) then
	       -- Only return modules which should be called for the specified hook
	       if((user_script.hooks[hook_filter] == nil) and (user_script.hooks["all"] == nil)) then
		  traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for hook '%s'", user_script.key, hook_filter))
		  goto next_module
	       end
	    end

	    if(scripts_filter ~= nil) then
	       local script_ok = scripts_filter(user_script)

	       if(not script_ok) then
		  goto next_module
	       end
	    end

            -- If a setup function is available, call it
            if(user_script.setup ~= nil) then
               setup_ok = user_script.setup()
            end

            if((not return_all) and (not setup_ok)) then
               traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' as setup() returned %s", user_script.key, setup_ok))
               goto next_module
            end

	    -- Checks passed, now load the script information

            -- Populate hooks fast lookup table
            for hook, hook_fn in pairs(user_script.hooks) do
	       -- load previously computed benchmarks (if any)
	       -- benchmarks are loaded even if their computation is disabled with a do_benchmark ~= true
               if(rv.hooks[hook] == nil) then
                  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unknown hook '%s' in module '%s'", hook, user_script.key))
               else
		  if do_benchmark then
		     rv.hooks[hook][user_script.key] = benchmark_init(subdir, user_script.key, hook, hook_fn)
		  else
		     rv.hooks[hook][user_script.key] = hook_fn
		  end
               end
            end

	    if(rv.hooks["periodicUpdate"] ~= nil) then
	       -- Set the update frequency
	       local default_update_freq = 120		-- Default: every 2 minutes

	       if(user_script.periodic_update_seconds ~= nil) then
		  if((user_script.periodic_update_seconds % 30) ~= 0) then
		     traceError(TRACE_WARNING, TRACE_CONSOLE, string.format(
			"Update_periodicity '%s' is not multiple of 30 in '%s', using default (%u)",
			user_script.periodic_update_seconds, user_script.key, default_update_freq))
		     user_script.periodic_update_seconds = default_update_freq
		  end
	       else
		  user_script.periodic_update_seconds = default_update_freq
	       end

	       user_script.periodic_update_divisor = math.floor(user_script.periodic_update_seconds / 30)
	    end

            rv.modules[user_script.key] = user_script
         end

         ::next_module::
      end
   end

   if(old_ifid ~= ifid) then
      interface.select(tostring(old_ifid))
   end

   return(rv)
end

-- ##############################################

-- @brief Convenient method to only load a specific script
function user_scripts.loadModule(ifid, script_type, subdir, mod_fname)
   local check_dirs = getScriptsDirectories(script_type, subdir)

   for _, checks_dir in pairs(check_dirs) do
      local full_path = os_utils.fixPath(checks_dir .. "/" .. mod_fname .. ".lua")
      local plugin = plugins_utils.getUserScriptPlugin(full_path)

      if(ntop.exists(full_path) and (plugin ~= nil)) then
	 local user_script = dofile(full_path)

	 if(user_script ~= nil) then
	    local configs = loadConfiguration(subdir)

	    init_user_script(user_script, mod_fname, full_path, plugin, script_type, subdir, configs)

	    return(user_script)
	 end
      end
   end

   return(nil)
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

function user_scripts.checkbox_post_handler(submit_field)
   -- TODO remove after implementing the new gui
   return(nil)
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

-- ##############################################

-- For built-in input_builders, return the _POST handler to use
local input_builder_to_post_handler = {
   [user_scripts.threshold_cross_input_builder] = user_scripts.threshold_cross_post_handler,
}

function user_scripts.getDefaultPostHandler(input_builder)
   return(input_builder_to_post_handler[input_builder])
end

-- ##############################################

-- @brief Teardown function, to be called at the end of the VM
function user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
   for _, script in pairs(available_modules.modules) do
      if script.teardown then
         script.teardown()
      end
   end

   if do_benchmark then
      local ifid = interface.getId()
      user_scripts.benchmark_dump(ifid, do_print_benchmark)
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

function user_scripts.listSubdirs()
   local rv = {}

   for _, subdir in ipairs(available_subdirs) do
      local item = table.clone(subdir)
      item.label = i18n(item.label) or item.label

      rv[#rv + 1] = item
   end

   return(rv)
end

-- ##############################################

local function findConfigSet(configsets, name)
   for id, configset in pairs(configsets) do
      if(configset.name == name) then
	 return(configset)
      end
   end

   return(nil)
end

-- ##############################################

local function getNewConfigSetId(configsets)
   local max_id = -1

   for i in pairs(configsets) do
      max_id = math.max(max_id, tonumber(i))
   end

   return(max_id+1)
end

-- ##############################################

local function getConfigsetsKey(subdir)
   return(string.format(CONFIGSETS_KEY, subdir))
end

-- ##############################################

local function validateConfigsets(configsets)
   local cur_targets = {}

   -- Ensure that no duplicate target is set
   for _, configset in pairs(configsets) do
      for _, conf_target in ipairs(configset.targets) do
	 local is_v4 = isIPv4(conf_target)
	 local is_v6 = isIPv6(conf_target)
	 local conf_target_normalized = nil

	 if(is_v4 or is_v6) then
	    local address, prefix = splitNetworkPrefix(conf_target)
	    local max_prefixlen = ternary(is_v4, 32, 128)

	    if((prefix == nil) or (prefix >= max_prefixlen)) then
	       prefix = max_prefixlen
	    end

	    -- Normalize
	    conf_target_normalized = ntop.networkPrefix(address, prefix) .. "/" .. prefix
	 else
	    conf_target_normalized = conf_target
	 end

	 local existing_id = cur_targets[conf_target_normalized]

	 if(existing_id) then
	    return false, i18n("configsets.duplicate_target", {target = conf_target, confname1 = configsets[existing_id].name, confname2 = configset.name})
	 end

	 cur_targets[conf_target_normalized] = configset.id
      end
   end

   return true
end

-- ##############################################

local function saveConfigsets(subdir, configsets)
   local rv = json.encode(configsets)
   ntop.setPref(getConfigsetsKey(subdir), rv)

   local rv, err = validateConfigsets(configsets)

   if(not rv) then
      return rv, err
   end

   return true
end

-- ##############################################

function user_scripts.getConfigsets(subdir)
   local configsets = ntop.getPref(getConfigsetsKey(subdir)) or ""
   local rv = {}

   configsets = json.decode(configsets) or {}

   -- Convert the ID keys to number
   for _, confset in pairs(configsets) do
      rv[confset.id] = confset
   end

   return(rv)
end

-- ##############################################

function user_scripts.deleteConfigset(subdir, confid)
   confid = tonumber(confid)

   if(confid == user_scripts.DEFAULT_CONFIGSET_ID) then
      return false, "Cannot delete default configset"
   end

   local configsets = user_scripts.getConfigsets(subdir)

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   configsets[confid] = nil
   return saveConfigsets(subdir, configsets)
end

-- ##############################################

function user_scripts.renameConfigset(subdir, confid, new_name)
   local configsets = user_scripts.getConfigsets(subdir)

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   local existing = findConfigSet(configsets, new_name)

   if existing then
      return false, i18n("configsets.error_exists", {name=new_name})
   end

   configsets[confid].name = new_name
   return saveConfigsets(subdir, configsets)
end

-- ##############################################

function user_scripts.cloneConfigset(subdir, confid, new_name)
   local configsets = user_scripts.getConfigsets(subdir)

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   local existing = findConfigSet(configsets, new_name)

   if existing then
      return false, i18n("configsets.error_exists", {name=new_name})
   end

   local new_confid = getNewConfigSetId(configsets)

   configsets[new_confid] = table.clone(configsets[confid])
   configsets[new_confid].id = new_confid
   configsets[new_confid].name = new_name
   configsets[new_confid].targets = {}

   local rv, err = saveConfigsets(subdir, configsets)

   if(not rv) then
      return rv, err
   end

   return true, new_confid
end

-- ##############################################

function user_scripts.setConfigsetTargets(subdir, confid, targets)
   local configsets = user_scripts.getConfigsets(subdir)

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   if(confid == user_scripts.DEFAULT_CONFIGSET_ID) then
      return false, "Cannot set target on the default configuration"
   end

   -- Update the targets
   configsets[confid].targets = targets

   return saveConfigsets(subdir, configsets)
end

-- ##############################################

function user_scripts.updateScriptConfig(confid, script_key, subdir, new_config)
   local configsets = user_scripts.getConfigsets(subdir)

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   local config = configsets[confid].config

   config[script_key] = new_config

   return saveConfigsets(subdir, configsets)
end

-- ##############################################

function user_scripts.loadDefaultConfig()
   local ifid = getSystemInterfaceId()

   for type_id, script_type in pairs(user_scripts.script_types) do
      for _, subdir in pairs(script_type.subdirs) do
	 local configsets = user_scripts.getConfigsets(subdir)
	 local default_conf = configsets[user_scripts.DEFAULT_CONFIGSET_ID] or {}

	 local scripts = user_scripts.load(ifid, script_type, subdir, {return_all = true})

	 for key, usermod in pairs(scripts.modules) do
	    if((usermod.default_enabled ~= nil) or (usermod.default_value ~= nil)) then
	       default_conf[key] = default_conf[key] or {}
	       local script_config = default_conf[key]

	       for hook in pairs(usermod.hooks) do
		  -- Do not override an existing configuration
		  if(script_config[hook] == nil) then
		     script_config[hook] = {
			enabled = usermod.default_enabled or false,
			script_conf = usermod.default_value or {},
		     }
		  end
	       end
	    end
	 end

	 configsets[user_scripts.DEFAULT_CONFIGSET_ID] = {
	    id = user_scripts.DEFAULT_CONFIGSET_ID,
	    name = i18n("policy_presets.default"),
	    config = default_conf,
	    targets = {},
	 }

	 saveConfigsets(subdir, configsets)
      end
   end
end

-- ##############################################

function user_scripts.getConfigsetHooksConf(configset, script)
   local script_key = script.key

   if(configset.config[script_key]) then
      -- A configuration was found
      return(configset.config[script_key])
   end

   -- Default
   local rv = {}

   for hook in pairs(script.hooks) do
      rv[hook] = {
	 enabled = false,
	 script_conf = {},
      }
   end

   return(rv)
end

-- ##############################################

local fast_target_lookup = nil

-- NOTE: this only works for exact searches. For hosts see user_scripts.getHostTargetConfiset
function user_scripts.getTargetConfiset(configsets, target)
   if(fast_target_lookup == nil) then
      fast_target_lookup = {}

      for _, configset in pairs(configsets) do
	 for _, conf_target in pairs(configset.targets) do
	    fast_target_lookup[conf_target] = configset
	 end
      end
   end

   return(fast_target_lookup[target] or configsets[user_scripts.DEFAULT_CONFIGSET_ID])
end

-- ##############################################

local host_confsets_ptree_initialized = false

-- Performs an IP based match by using a patricia tree
function user_scripts.getHostTargetConfiset(configsets, ip_target)
   if(not host_confsets_ptree_initialized) then
      -- Start with an empty ptree
      ntop.ptreeClear()

      for _, configset in pairs(configsets) do
	 for _, conf_target in pairs(configset.targets) do
	    ntop.ptreeInsert(conf_target, configset.id)
	 end
      end

      host_confsets_ptree_initialized = true
   end

   local match_id = ntop.ptreeMatch(ip_target) or user_scripts.DEFAULT_CONFIGSET_ID
   return(configsets[match_id])
end

-- ##############################################

return(user_scripts)
