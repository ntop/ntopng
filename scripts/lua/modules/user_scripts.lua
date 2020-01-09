--
-- (C) 2019-20 - ntop.org
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
local ALL_HOOKS_CONFIG_KEY = "all"
local CONFIGSETS_KEY = "ntopng.prefs.user_scripts.configsets_v2"
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
    has_per_hook_config = true, -- Each hook has a separate configuration
  }, snmp_device = {
    parent_dir = "system",
    hooks = {"snmpDevice", "snmpDeviceInterface"},
    subdirs = {"snmp_device"},
  }, system = {
    parent_dir = "system",
    hooks = {"min", "5mins", "hour", "day"},
    subdirs = {"system"},
    has_per_hook_config = true, -- Each hook has a separate configuration
  }, syslog = {
    parent_dir = "system",
    hooks = {"handleEvent"},
    subdirs = {"syslog"},
  }
}

-- ##############################################

-- @brief Given a subdir, returns the corresponding script type
function user_scripts.getScriptType(search_subdir)
   for _, script_type in pairs(user_scripts.script_types) do
      for _, subdir in pairs(script_type.subdirs) do
	 if(subdir == search_subdir) then
	    return(script_type)
	 end
      end
   end

   -- Not found
   return(nil)
end

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
      scripts_benchmarks = {}
   end

   return(scripts_benchmarks)
end

-- ##############################################

local function init_user_script(user_script, mod_fname, full_path, plugin, script_type, subdir)
   user_script.key = mod_fname
   user_script.path = full_path
   user_script.subdir = subdir
   user_script.default_enabled = ternary(user_script.default_enabled == false, false, true --[[ a nil value means enabled ]])
   user_script.source_path = plugins_utils.getUserScriptSourcePath(user_script.path)
   user_script.plugin = plugin
   user_script.script_type = script_type
   user_script.edition = plugin.edition

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

	    if((not user_script.gui) or (not user_script.gui.i18n_title) or (not user_script.gui.i18n_description)) then
	       traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Module '%s' does not define a gui", mod_fname))
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
	    init_user_script(user_script, mod_fname, full_path, plugin, script_type, subdir)

	    return(user_script)
	 end
      end
   end

   return(nil)
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

function user_scripts.getSubdirTargetType(search_subdir)
   for _, subdir in pairs(available_subdirs) do
      if(subdir.id == search_subdir) then
	 return(subdir.target_type)
      end
   end

   return "none"
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

local function validateConfigsets(configsets)
   local cur_targets = {}

   -- Ensure that no duplicate target is set
   for _, configset in pairs(configsets) do
      for subdir, subdir_table in pairs(configset.targets) do
	 cur_targets[subdir] = cur_targets[subdir] or {}

	 for _, conf_target in ipairs(subdir_table) do
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

	    local existing_id = cur_targets[subdir][conf_target_normalized]

	    if(existing_id) then
	       return false, i18n("configsets.duplicate_target", {target = conf_target, confname1 = configsets[existing_id].name, confname2 = configset.name})
	    end

	    cur_targets[subdir][conf_target_normalized] = configset.id
	 end
      end
   end

   return true
end

-- ##############################################

local function saveConfigsets(configsets)
   local to_delete = ntop.getHashKeysCache(CONFIGSETS_KEY) or {}
   local rv, err = validateConfigsets(configsets)

   if(not rv) then
      return rv, err
   end

   for _, configset in pairs(configsets) do
      local k = string.format("%d", configset.id)
      local v = json.encode(configset)

      ntop.setHashCache(CONFIGSETS_KEY, k, v)
      to_delete[k] = nil
   end

   for confid in pairs(to_delete) do
      ntop.delHashCache(CONFIGSETS_KEY, confid)
   end

   -- Reload the periodic scripts as the configuration has changed
   ntop.reloadPeriodicScripts()

   return true
end

-- ##############################################

local cached_config_sets = nil

function user_scripts.getConfigsets()
   if cached_config_sets then
      return(cached_config_sets)
   end

   local configsets = ntop.getHashAllCache(CONFIGSETS_KEY) or {}
   local rv = {}

   for _, confset_json in pairs(configsets) do
      local confset = json.decode(confset_json)

      if confset then
	 rv[confset.id] = confset
      end
   end

   -- Cache to avoid loading them again
   cached_config_sets = rv
   return(rv)
end

-- ##############################################

function user_scripts.deleteConfigset(confid)
   confid = tonumber(confid)

   if(confid == user_scripts.DEFAULT_CONFIGSET_ID) then
      return false, "Cannot delete default configset"
   end

   local configsets = user_scripts.getConfigsets()

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   configsets[confid] = nil
   return saveConfigsets(configsets)
end

-- ##############################################

function user_scripts.renameConfigset(confid, new_name)
   if(confid == user_scripts.DEFAULT_CONFIGSET_ID) then
      return false, "Cannot rename default configset"
   end

   local configsets = user_scripts.getConfigsets()

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   local existing = findConfigSet(configsets, new_name)

   if existing then
      if(existing.id == confid) then
	 -- Renaming to the same name has no effect
	 return true
      end

      return false, i18n("configsets.error_exists", {name=new_name})
   end

   configsets[confid].name = new_name
   return saveConfigsets(configsets)
end

-- ##############################################

function user_scripts.cloneConfigset(confid, new_name)
   local configsets = user_scripts.getConfigsets()

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

   local rv, err = saveConfigsets(configsets)

   if(not rv) then
      return rv, err
   end

   return true, new_confid
end

-- ##############################################

function user_scripts.setConfigsetTargets(subdir, confid, targets)
   local configsets = user_scripts.getConfigsets()

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   if(confid == user_scripts.DEFAULT_CONFIGSET_ID) then
      return false, "Cannot set target on the default configuration"
   end

   -- Update the targets
   configsets[confid].targets[subdir] = targets

   return saveConfigsets(configsets)
end

-- ##############################################

-- @brief Update the configuration of a specific script in a configset
function user_scripts.updateScriptConfig(confid, script_key, subdir, new_config)
   local configsets = user_scripts.getConfigsets()

   if(configsets[confid] == nil) then
      return false, i18n("configsets.unknown_id", {confid=confid})
   end

   local config = configsets[confid].config

   config[subdir] = config[subdir] or {}
   config[subdir][script_key] = new_config

   return saveConfigsets(configsets)
end

-- ##############################################

function user_scripts.loadDefaultConfig()
   local ifid = getSystemInterfaceId()
   local configsets = user_scripts.getConfigsets()
   local default_conf = configsets[user_scripts.DEFAULT_CONFIGSET_ID]

   if default_conf then
      default_conf = default_conf.config or {}

      -- Drop possible nested values due to a previous bug
      default_conf.config = nil
   else
      default_conf = {}
   end

   for type_id, script_type in pairs(user_scripts.script_types) do
      for _, subdir in pairs(script_type.subdirs) do
	 local scripts = user_scripts.load(ifid, script_type, subdir, {return_all = true})

	 for key, usermod in pairs(scripts.modules) do
	    if((usermod.default_enabled ~= nil) or (usermod.default_value ~= nil)) then
	       default_conf[subdir] = default_conf[subdir] or {}
	       default_conf[subdir][key] = default_conf[subdir][key] or {}
	       local script_config = default_conf[subdir][key]
	       local hooks = ternary(script_type.has_per_hook_config, usermod.hooks, {[ALL_HOOKS_CONFIG_KEY]=1})

	       for hook in pairs(hooks) do
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
      end
   end

   configsets[user_scripts.DEFAULT_CONFIGSET_ID] = {
      id = user_scripts.DEFAULT_CONFIGSET_ID,
      name = i18n("policy_presets.default"),
      config = default_conf,
      targets = {},
   }

   saveConfigsets(configsets)
end

-- ##############################################

-- Returns true if a system script is enabled for some hook
function user_scripts.isSystemScriptEnabled(script_key)
   local configsets = user_scripts.getConfigsets()
   local default_config = user_scripts.getDefaultConfig(configsets, "system")
   local script_config = default_config[script_key]

   if(script_config) then
      for _, hook in pairs(script_config) do
	 if(hook.enabled) then
	    return(true)
	 end
      end
   end

   return(false)
end

-- ##############################################

local default_config = {
   enabled = false,
   script_conf = {},
}

-- @brief Retrieves the configuration of a specific script
function user_scripts.getScriptConfig(configset, script, subdir)
   local script_key = script.key
   local config = configset.config[subdir]

   if(config[script_key]) then
      -- A configuration was found
      return(config[script_key])
   end

   -- Default
   local rv = {}
   local hooks = ternary(script_type.has_per_hook_config, script.hooks, {[ALL_HOOKS_CONFIG_KEY]=1})

   for hook in pairs(script.hooks) do
      rv[hook] = default_config
   end

   return(rv)
end

-- ##############################################

-- @brief Retrieves the configuration of a specific hook of the target
-- @param target_config target configuration as returned by
-- user_scripts.getTargetConfig/user_scripts.getHostTargetConfigset
function user_scripts.getTargetHookConfig(target_config, script, hook)
   local script_conf = target_config[script.key]

   if not hook then
      -- See has_per_hook_config
      hook = ALL_HOOKS_CONFIG_KEY
   end

   if(not script_conf) then
      return(default_config)
   end

   return(script_conf[hook] or default_config)
end

-- ##############################################

local fast_target_lookup = nil

-- NOTE: this only works for exact searches. For hosts see user_scripts.getHostTargetConfigset
function user_scripts.getTargetConfig(configsets, subdir, target)
   if(fast_target_lookup == nil) then
      fast_target_lookup = {}

      for _, configset in pairs(configsets) do
	 for _, conf_target in pairs(configset.targets[subdir] or {}) do
	    fast_target_lookup[conf_target] = configset
	 end
      end
   end

   local conf = fast_target_lookup[target] or configsets[user_scripts.DEFAULT_CONFIGSET_ID]

   if(conf == nil) then
      return({})
   end

   return(conf.config[subdir] or {})
end

-- ##############################################

function user_scripts.getDefaultConfig(configsets, subdir)
   local conf = configsets[user_scripts.DEFAULT_CONFIGSET_ID]

   if(conf == nil) then
      return({})
   end

   return(conf.config[subdir] or {})
end

-- ##############################################

local host_confsets_ptree_initialized = false

-- Performs an IP based match by using a patricia tree
function user_scripts.getHostTargetConfigset(configsets, subdir, ip_target)
   if(not host_confsets_ptree_initialized) then
      -- Start with an empty ptree
      ntop.ptreeClear()

      for _, configset in pairs(configsets) do
	 for _, conf_target in pairs(configset.targets[subdir] or {}) do
	    ntop.ptreeInsert(conf_target, configset.id)
	 end
      end

      host_confsets_ptree_initialized = true
   end

   local match_id = ntop.ptreeMatch(ip_target) or user_scripts.DEFAULT_CONFIGSET_ID
   local conf = configsets[match_id]

   if(conf == nil) then
      return({})
   end

   return(conf.config[subdir] or {})
end

-- ##############################################

return(user_scripts)
