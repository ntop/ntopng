--
-- (C) 2019-21 - ntop.org
--

-- Checks provide a scriptable way to interact with the ntopng
-- core. Users can provide their own modules to trigger custom alerts,
-- export data, or perform periodic tasks.


-- Hack to avoid include loops
if(pragma_once_checks == true) then
   -- avoid multiple inclusions
   return
end

pragma_once_checks = true

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"

local os_utils = require("os_utils")
local json = require("dkjson")
local plugins_utils = require("plugins_utils")
local alert_consts = require "alert_consts"
local http_lint = require("http_lint")
local ipv4_utils = require "ipv4_utils"
local pools_lua_utils = require "pools_lua_utils"
local alert_exclusions = require "alert_exclusions"

local info = ntop.getInfo()

local checks = {}

-- ##############################################

local filters_debug = false

-- ##############################################

checks.field_units = {
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
  contacts = "field_units.contacts",
  score = "field_units.score",
}

-- ##############################################

-- Operator functions associated to checks `operator`, which is specified
-- both inside checks default configuration values, as well as when checks
-- are configured from the UI.
--
checks.operator_functions = {
   gt --[[ greater than --]] = function(value, threshold) return value > threshold end,
   lt --[[ less than    --]] = function(value, threshold) return value < threshold end,
}

-- ##############################################

local NUM_FILTERED_KEY = "ntopng.cache.checks.exclusion_counter.subdir_%s.script_key_%s"
local REQUEST_PERIODIC_USER_SCRIPTS_RUN_KEY = "ntopng.cache.ifid_%i.checks.request.granularity_%s"
local NON_TRAFFIC_ELEMENT_CONF_KEY = "all"
local NON_TRAFFIC_ELEMENT_ENTITY = "no_entity"
local ALL_HOOKS_CONFIG_KEY = "all"
local CONFIGSET_KEY = "ntopng.prefs.checks.configset_v1" -- Keep in sync with ntop_defines.h CHECKS_CONFIG
checks.DEFAULT_CONFIGSET_ID = 0

-- NOTE: the subdir id must be unique
local available_subdirs = {
   {
      id = "host",
      label = "hosts",
      pools = "host_pools",
      filter = {
	 -- Default fields populated automatically when creating filters
	 default_fields   = { "ip", },
	 -- All possible filter fields
	 available_fields = {
	    ip = {
	       lint = http_lint.validateIpAddress,
	    },
	 },
      },
   }, {
      id = "interface",
      label = "interfaces",
      pools = "interface_pools",
      filter = {
	 default_fields = { "alert_entity_val" },
	 available_fields = {
	    alert_entity_val = {
	       lint = http_lint.validateInterface, -- An interface id
	       match = function(context, val)
		  -- Do the comparison
		  if not context or context.alert_entity ~= alert_consts.alertEntity("interface") then
		     return false
		  end

		  -- Match on the interface id
		  return tonumber(val) == tonumber(context.alert_entity_val)
	       end,
	       sqlite = function(val)
		  -- Keep in sync with SQLite database schema declared in AlertsManager.cpp
		  return string.format("(alert_entity = %u AND alert_entity_val = '%s')", alert_consts.alertEntity("interface"), val)
	       end,
	       find = function(alert, alert_json, filter, val)
		  return (alert[filter] and (alert[filter] == val))
	       end,
	    },
	 },
      },
   }, {
      id = "network",
      label = "networks",
      pools = "local_network_pools",
      filter = {
	 default_fields = { "alert_entity_val" },
	 available_fields = {
	    alert_entity_val = {
	       lint = http_lint.validateNetworkWithVLAN, -- A local network
	       match = function(context, val)
		  -- Do the comparison
		  if not context or context.alert_entity ~= alert_consts.alertEntity("network") then
		     return false
		  end

		  -- Match on the interface id
		  return val == context.alert_entity_val
	       end,
	       sqlite = function(val)
		  -- Keep in sync with SQLite database schema declared in AlertsManager.cpp
		  return string.format("(alert_entity = %u AND alert_entity_val = '%s')", alert_consts.alertEntity("network"), val)
	       end,
	       find = function(alert, alert_json, filter, val)
		  return (alert[filter] and (alert[filter] == val))
	       end,
	    },
	 },
      },
   }, {
      id = "snmp_device",
      label = "host_details.snmp",
      pools = "snmp_device_pools",
      filter = {
	 default_fields = { "alert_entity_val" },
	 available_fields = {
	    alert_entity_val = {
	       lint = http_lint.validateHost, -- The IP address of an SNMP device
	       match = function(context, val)
		  -- Do the comparison
		  if not context or context.alert_entity ~= alert_consts.alertEntity("snmp_device") then
		     return false
		  end

		  -- Match the SNMP device
		  return val == context.alert_entity_val
	       end,
	       sqlite = function(val)
		  -- Keep in sync with SQLite database schema declared in AlertsManager.cpp
		  return string.format("(alert_entity = %u AND alert_entity_val = '%s')", alert_consts.alertEntity("snmp_device"), val)
	       end,
	       find = function(alert, alert_json, filter, val)
		  return (alert[filter] and (alert[filter] == val))
	       end,
	    },
	 },
      },     
   }, {
      id = "flow",
      label = "flows",
      -- User script execution filters (field names are those that arrive from the C Flow.cpp)
      filter = {
	 -- Default fields populated automatically when creating filters
	 default_fields   = { "ip", },
	 -- All possible filter fields
	 available_fields = {
	    ip = {
	       lint = http_lint.validateIpAddress,
	    },
	 },
      },
      -- No pools for flows
   }, {
      id = "system",
      label = "system",
   }, {
      id = "syslog",
      label = "Syslog",
   }
}

-- Checks category consts
-- IMPORTANT keep it in sync with ntop_typedefs.h enum CheckCategory
checks.check_categories = {
   other = {
      id = 0,
      icon = "fas fa-scroll",
      i18n_title = "checks.category_other",
      i18n_descr = "checks.category_other_descr",
   },
   security = {
      id = 1,
      icon = "fas fa-shield-alt",
      i18n_title = "checks.category_security",
      i18n_descr = "checks.category_security_descr",
   },
   internals = {
      id = 2,
      icon = "fas fa-wrench",
      i18n_title = "checks.category_internals",
      i18n_descr = "checks.category_internals_descr",
   },
   network = {
      id = 3,
      icon = "fas fa-network-wired",
      i18n_title = "checks.category_network",
      i18n_descr = "checks.category_network_descr",
   },
   system = {
      id = 4,
      icon = "fas fa-server",
      i18n_title = "checks.category_system",
      i18n_descr = "checks.category_system_descr",
   }
}

-- Hook points for flow/periodic modules
-- NOTE: keep in sync with the Documentation
checks.script_types = {
  flow = {
    parent_dir = "interface",
    hooks = {"protocolDetected", "statusChanged", "flowEnd", "periodicUpdate"},
    subdirs = {"flow"},
    default_config_only = true, -- Only the default configset can be used
  }, traffic_element = {
    parent_dir = "interface",
    hooks = {"min", "5mins", "hour", "day"},
    subdirs = {"interface", "network"},
    has_per_hook_config = true, -- Each hook has a separate configuration
  }, host = {
    parent_dir = "interface",
    hooks = {"min", "5mins", "hour", "day"},
    subdirs = {"host"},
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
    default_config_only = true, -- Only the default configset can be used
  }, syslog = {
    parent_dir = "system",
    hooks = {"handleEvent"},
    subdirs = {"syslog"},
    default_config_only = true, -- Only the default configset can be used
  }
}

-- ##############################################


-- ##############################################

-- @brief Given a category found in a user script, this method checks whether the category is valid
-- and, if not valid, it assigns to the plugin a default category
local function checkCategory(category)
   if not category or not category["id"] then
      return checks.check_categories.other
   end

   for cat_k, cat_v in pairs(checks.check_categories) do
      if category["id"] == cat_v["id"] then
	 return cat_v
      end
   end

   return checks.check_categories.other
end

-- ##############################################

-- @brief Given a subdir, returns the corresponding script type
function checks.getScriptType(search_subdir)
   for _, script_type in pairs(checks.script_types) do
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

-- @brief Given a subdir, returns the corresponding numeric id
local function getSubdirId(subdir_name)
   for id, values in pairs(available_subdirs) do
      if values["id"] == subdir_name then
	 return id
      end
   end

   return -1
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

function checks.getSubdirectoryPath(script_type, subdir)
   local res = { }
   local prefix = plugins_utils.getRuntimePath() .. "/callbacks"
   local path

   if subdir == "host" or subdir == "flow" then
      -- host and flow have their callbacks defined under modules/ and implemented in C++
      path = string.format("%s/scripts/lua/modules/check_definitions/%s", dirs.installdir, subdir)
   elseif not isEmptyString(subdir) and subdir ~= "." then
      path = string.format("%s/%s/%s", prefix, script_type.parent_dir, subdir)
   else
      path = string.format("%s/%s", prefix, script_type.parent_dir)
   end

   res[#res + 1] = os_utils.fixPath(path)

   -- Add pro check_definitions if necessary
   if ntop.isPro() then
      if subdir == "flow" or subdir == "host" then
	 local pro_path = string.format("%s/pro/scripts/lua/modules/check_definitions/%s", dirs.installdir, subdir)
	 res[#res + 1] = os_utils.fixPath(pro_path)
      end
   end

   return res
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
   -- NOTE: 5min/hour/day are not monitored. They would collide in the checks_benchmarks_key.
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

--~ schema_prefix: "flow_check" or "elem_check"
function checks.ts_dump(when, ifid, verbose, schema_prefix, all_scripts)
   local ts_utils = require("ts_utils_core")

   for subdir, script_type in pairs(all_scripts) do
      local rv = checks.getAggregatedStats(ifid, script_type, subdir)
      local total = {tot_elapsed = 0, tot_num_calls = 0}

      for modkey, stats in pairs(rv) do
	 ts_utils.append(schema_prefix .. ":duration", {ifid = ifid, check = modkey, subdir = subdir, num_ms = stats.tot_elapsed * 1000}, when)
	 ts_utils.append(schema_prefix .. ":num_calls", {ifid = ifid, check = modkey, subdir = subdir, num_calls = stats.tot_num_calls}, when)

	 total.tot_elapsed = total.tot_elapsed + stats.tot_elapsed
	 total.tot_num_calls = total.tot_num_calls + stats.tot_num_calls
      end

      ts_utils.append(schema_prefix .. ":total_stats", {ifid = ifid, subdir = subdir, num_ms = total.tot_elapsed * 1000, num_calls = total.tot_num_calls}, when)
   end
end

-- ##############################################

local function checks_benchmarks_key(ifid, subdir)
   return string.format("ntopng.cache.ifid_%d.checks_benchmarks.subdir_%s", ifid, subdir)
end

-- ##############################################

-- @brief Returns the benchmark stats, aggregating them by module
function checks.getAggregatedStats(ifid, script_type, subdir)
   local bencmark = ntop.getCache(checks_benchmarks_key(ifid, subdir))
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
function checks.benchmark_dump(ifid, to_stdout)
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

      ntop.setCache(checks_benchmarks_key(ifid, subdir), json.encode(rv), 3600 --[[ 1 hour --]])
   end
end

-- ##############################################

-- @brief Lists available checks.
-- @params script_type one of checks.script_types
-- @params subdir the modules subdir
-- @return a list of available module names
function checks.listScripts(script_type, subdir)
   local check_dirs = checks.getSubdirectoryPath(script_type, subdir)
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

function checks.getLastBenchmark(ifid, subdir)
   local scripts_benchmarks = ntop.getCache(checks_benchmarks_key(ifid, subdir))

   if(not isEmptyString(scripts_benchmarks)) then
      scripts_benchmarks = json.decode(scripts_benchmarks)
   else
      scripts_benchmarks = {}
   end

   return(scripts_benchmarks)
end

-- ##############################################

-- @brief Tries and load a script template, returning a new instance (if found)
--        All templates loaded here must inherit from `check_template.lua`
local function loadAndCheckScriptTemplate(check, check_template)
   local res

   if not check_template then
      -- Default name
      check_template = "check_template"
   end

   -- First, try and load the template straight from the plugin templates
   local template_require

   if check.plugin then
      template_require = plugins_utils.loadTemplate(check.plugin.key, check_template)
   end

   -- Then, if no template is found inside the plugin, try and load the template from the ntopng templates
   -- in modules that can be shared across multiple plugins
   if not template_require then
      -- Attempt at locating the template class under modules (global to ntopng)
      local template_path = os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/check_templates/"..check_template..".lua")
      if ntop.exists(template_path) then
	 -- Require the template file
	 template_require = require("check_templates."..check_template)
      end
   end

   if template_require then
      -- Create an instance of the template
      res = template_require.new(check)
   end

   return res
end

-- ##############################################

local function init_check(check, mod_fname, full_path, plugin, script_type, subdir)
   check.key = mod_fname
   check.path = full_path
   check.subdir = subdir
   check.default_enabled = ternary(check.default_enabled == false, false, true --[[ a nil value means enabled ]])
   check.source_path = plugins_utils.getUserScriptSourcePath(check.path)
   check.plugin = plugin
   check.script_type = script_type
   check.edition = plugin and plugin.edition
   check.category = checkCategory(check.category)
   -- A user script is assumed to be able to generate alerts if it has a flag or an alert id specified
   check.num_filtered = tonumber(ntop.getCache(string.format(NUM_FILTERED_KEY, subdir, mod_fname))) or 0 -- math.random(1000,2000)

   if subdir == "host" then
      check.hooks = {min = true}
   end

   if check.gui then
      check.template = loadAndCheckScriptTemplate(check, check.gui.input_builder)

      if(check.template == nil) then
	 traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unknown template '%s' for user script '%s'", check.gui.input_builder, mod_fname))
      end

      -- Possibly localize the input title/description
      if check.gui.input_title then
	 check.gui.input_title = i18n(check.gui.input_title) or check.gui.input_title
      end
      if check.gui.input_description then
	 check.gui.input_description = i18n(check.gui.input_description) or check.gui.input_description
      end
   end

   -- Expand hooks
   if(check.hooks and check.hooks["all"] ~= nil) then
      local callback = check.hooks["all"]
      check.hooks["all"] = nil

      for _, hook in pairs(script_type.hooks) do
	 check.hooks[hook] = callback
      end
   end

   if not check.hooks then
      -- Flow checks no longer have hooks. They have callbacks in C++ that have replaced hooks
      check.hooks = {}
   end
end

-- ##############################################

local function loadAndCheckScript(mod_fname, full_path, plugin, script_type, subdir, return_all, scripts_filter, hook_filter)
   local setup_ok = true

   -- Recheck the edition as the demo mode may expire
   if plugin then
      if (plugin.edition == "pro" and not ntop.isPro())
         or ((plugin.edition == "enterprise_l" or plugin.edition == "enterprise_m") and not ntop.isEnterpriseM())
         or (plugin.edition == "enterprise_l" and not ntop.isEnterpriseL()) then
	 traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping user script '%s' with '%s' edition", mod_fname, plugin.edition))
	 return(nil)
      end
   end

   traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Loading user script '%s'", mod_fname))

   local check = dofile(full_path)

   if(type(check) ~= "table") then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Loading '%s' failed", full_path))
      return(nil)
   end

   if((not return_all) and check.packet_interface_only and (not interface.isPacketInterface())) then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for non packet interface", mod_fname))
      return(nil)
   end

   if((check.nedge_exclude and ntop.isnEdge()) or (check.nedge_only and (not ntop.isnEdge()))) then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for nEdge", mod_fname))
      return(nil)
   end

   if((not return_all) and (check.windows_exclude and ntop.isWindows())) then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' not supported on Windows", mod_fname))
      return(nil)
   end

   if(subdir ~= "flow" and subdir ~= "host" and table.empty(check.hooks)) then
      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("No 'hooks' defined in user script '%s', skipping", mod_fname))
      return(nil)
   end

   if(check.l7_proto ~= nil) then
      check.l7_proto_id = interface.getnDPIProtoId(check.l7_proto)

      if(check.l7_proto_id == -1) then
	 traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unknown L7 protocol filter '%s' in user script '%s', skipping", check.l7_proto, mod_fname))
	 return(nil)
      end
   end

   if((not check.gui) or (not check.gui.i18n_title) or (not check.gui.i18n_description)) then
      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Module '%s' does not define a gui", mod_fname))
   end

   -- Augument with additional attributes
   init_check(check, mod_fname, full_path, plugin, script_type, subdir)

   if(hook_filter ~= nil) then
      -- Only return modules which should be called for the specified hook
      if((check.hooks[hook_filter] == nil) and (check.hooks["all"] == nil)) then
	 traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' for hook '%s'", check.key, hook_filter))
	 return(nil)
      end
   end

   if(scripts_filter ~= nil) then
      local script_ok = scripts_filter(check)

      if(not script_ok) then
	 return(nil)
      end
   end

   -- If a setup function is available, call it
   if(check.setup ~= nil) then
      setup_ok = check.setup()
   end

   if((not return_all) and (not setup_ok)) then
      traceError(TRACE_DEBUG, TRACE_CONSOLE, string.format("Skipping module '%s' as setup() returned %s", check.key, setup_ok))
      return(nil)
   end

   return(check)
end

-- ##############################################

-- @brief Load the checks.
-- @param ifid the interface ID
-- @param script_type one of checks.script_types
-- @param subdir the modules subdir. *NOTE* this must be unique as it is used as a key.
-- @param options an optional table with the following supported options:
--  - hook_filter: if non nil, only load the checks for the specified hook
--  - do_benchmark: if true, computes benchmarks for every hook
--  - return_all: if true, returns all the scripts, even those with filters not matching the current configuration
--    NOTE: this can only be applied if the script type has the "has_no_entity" flag set.
--  - scripts_filter: a filter function(check) -> true, false. false will cause the script to be skipped.
-- @return {modules = key->check, hooks = check->function}
function checks.load(ifid, script_type, subdir, options)
   local rv = {modules = {}, hooks = {}, conf = {}}
   local old_ifid = interface.getId()
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

   local check_dirs = checks.getSubdirectoryPath(script_type, subdir)

   for _, checks_dir in pairs(check_dirs) do
      for fname in pairs(ntop.readdir(checks_dir)) do
         if string.ends(fname, ".lua") then
	    local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
	    local full_path = os_utils.fixPath(checks_dir .. "/" .. fname)
	    local plugin = plugins_utils.getUserScriptPlugin(full_path)

	    if not plugin then
	       --[[ host and flow don't have plugins, they are implemented in C++ so we call the C++ method to get their information --]]
	       if subdir == "host" then
		  plugin = ntop.getHostCheckInfo(mod_fname)
	       elseif subdir == "flow" then
		  plugin = ntop.getFlowCheckInfo(mod_fname)
	       else
		  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Skipping unknown user script '%s'", mod_fname))
		  goto next_module
	       end
	    end

	    if(rv.modules[mod_fname]) then
	       traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Skipping duplicate module '%s'", mod_fname))
	       goto next_module
	    end

	    local check = loadAndCheckScript(mod_fname, full_path, plugin, script_type, subdir, return_all, scripts_filter, hook_filter)

	    if(not check) then
	       goto next_module
	    end

	    -- Checks passed, now load the script information

            -- Populate hooks fast lookup table
            for hook, hook_fn in pairs(check.hooks or {}) do
	       -- load previously computed benchmarks (if any)
	       -- benchmarks are loaded even if their computation is disabled with a do_benchmark ~= true
               if(rv.hooks[hook] == nil) then
                  traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Unknown hook '%s' in module '%s'", hook, check.key))
               else
		  if do_benchmark then
		     rv.hooks[hook][check.key] = benchmark_init(subdir, check.key, hook, hook_fn)
		  else
		     rv.hooks[hook][check.key] = hook_fn
		  end
               end
            end

            rv.modules[check.key] = check
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
function checks.loadModule(ifid, script_type, subdir, mod_fname)
   local check_dirs = checks.getSubdirectoryPath(script_type, subdir)

   for _, checks_dir in pairs(check_dirs) do
      local full_path = os_utils.fixPath(checks_dir .. "/" .. mod_fname .. ".lua")
      local plugin = plugins_utils.getUserScriptPlugin(full_path)

      if ntop.exists(full_path) then
	 local check = loadAndCheckScript(mod_fname, full_path, plugin, script_type, subdir)

	 return check
      end
   end

   return(nil)
end

-- ##############################################

function checks.runPeriodicScripts()
   local requested = {}
   for granularity, _ in pairs(alert_consts.alerts_granularities) do
      local k = string.format(REQUEST_PERIODIC_USER_SCRIPTS_RUN_KEY, interface.getId(), granularity)

      if ntop.getCache(k) == "1" then
	 requested[granularity] = true
	 ntop.delCache(k)
      end
   end

   if table.len(requested) > 0 then
      interface.checkInterfaceAlerts(requested["min"], requested["5mins"], requested["hour"], requested["day"])
      interface.checkNetworksAlerts(requested["min"], requested["5mins"], requested["hour"], requested["day"])
   end
end

-- ##############################################

function checks.schedulePeriodicScripts(granularity)
   if alert_consts.alerts_granularities[granularity] then
      local k = string.format(REQUEST_PERIODIC_USER_SCRIPTS_RUN_KEY, interface.getId(), granularity)
      ntop.setCache(k, "1")
   end
end

-- ##############################################

-- @brief Teardown function, to be called at the end of the VM
function checks.teardown(available_modules, do_benchmark, do_print_benchmark)
   for _, script in pairs(available_modules.modules) do
      if script.teardown then
         script.teardown()
      end
   end

   if do_benchmark then
      local ifid = interface.getId()
      checks.benchmark_dump(ifid, do_print_benchmark)
   end
end

-- ##############################################

function checks.listSubdirs()
   local rv = {}

   for _, subdir in ipairs(available_subdirs) do
      local item = table.clone(subdir)
      item.label = i18n(item.label) or item.label

      rv[#rv + 1] = item
   end

   return(rv)
end

-- ##############################################

-- @brief Reload checks with their existing configurations.
--        Method called as part of plugins reload (during startup or when plugins are reloaded)
-- @param is_load Boolean, indicating whether callback onLoad/onUnload should be called
-- @return nil
function checks.loadUnloadUserScripts(is_load)
   -- Read configset
   local configset = checks.getConfigset()

   -- For each subdir available, (i.e., host, flow, interface, ...)
   for _, subdir in ipairs(checks.listSubdirs()) do
      -- Load all the available checks for this subdir
      local scripts = checks.load(interface.getId(), checks.getScriptType(subdir.id), subdir.id, {return_all = true})

      for name, script in pairsByKeys(scripts.modules) do
	 -- Call user script callbacks for
	 -- each available configuration existing for the user script
	 if not configset.config then
	    traceError(TRACE_ERROR,TRACE_CONSOLE, string.format("Configuration is missing"))
	    return
	 end

	 if not configset.config[subdir.id] then
	    traceError(TRACE_ERROR,TRACE_CONSOLE, string.format("Missing subdir '%s' from config", subdir.id))
	    return
	 end

	 if not configset.config[subdir.id][script.key] then
	    -- Configuration can be empty (for example the first time a user script is added)
	    traceError(TRACE_NORMAL,TRACE_CONSOLE,
		       string.format("Script '%s' configuration is missing from subdir '%s'. New user script?", script.key, subdir.id))
	 else
	    local s = configset.config[subdir.id][script.key]

	    if(s ~= nil) then
	       for hook, hook_config in pairs(s) do
	          -- For each configuration there are multiple hooks.
	          -- Some hooks can be enabled, whereas some other hooks can be disabled:
	          -- methods onLoad/onUnload are only called for hooks that are enabled.
	          if script and hook_config.enabled then
	             -- onLoad/onUnload methods are ONLY called for checks that are enabled
		     if is_load and script.onLoad then
		        -- This is a load operation
		        script.onLoad(hook, hook_config)
		     elseif not is_load and script.onUnload then
		        -- This is an unload operation
		        script.onUnload(hook, hook_config)
		     end
		  end
	       end
	    end
	 end
      end
   end
end

-- ##############################################

local function saveConfigset(configset)
   local v = json.encode(configset)
   ntop.setCache(CONFIGSET_KEY, v)

   -- Reload the periodic scripts as the configuration has changed
   ntop.reloadPeriodicScripts()

   -- Reload flow and host callbacks executed in C++
   ntop.reloadFlowChecks()
   ntop.reloadHostChecks()

   return true
end

-- ##############################################

local cached_config_set = nil

-- Return the default config set
-- Note: Other config sets are deprecated
function checks.getConfigset()
   if not cached_config_set then
      cached_config_set = json.decode(ntop.getCache(CONFIGSET_KEY))
   end

   return cached_config_set
end

-- ##############################################

function checks.createOrReplaceConfigset(configset)
   -- Skip configurations other then the only one supported (others are deprecated)
   if configset.id and configset.id ~= checks.DEFAULT_CONFIGSET_ID then
      return false
   end

   -- Unbind recipients
   local existing = checks.getConfigset()
   if existing then
      pools_lua_utils.unbind_all_recipient_id(existing.id)
   end

   -- Clone config
   configset = table.clone(configset)
   configset.id = checks.DEFAULT_CONFIGSET_ID

   -- Save config
   local rv = saveConfigset(configset)
   if not rv then
      return rv
   end

   return true
end

-- ##############################################

local function filterIsEqual(applied_config, new_filter)
   local ctr = 1

   if applied_config == nil then
      applied_config = {}
      
      return ctr
   end

   for counter, filter in pairs(applied_config) do
      if table.compare(filter, new_filter) then
         return 0
      end

      ctr = ctr + 1
   end 

   return ctr
end

-- ##############################################

-- @brief Update the configuration of a specific script in a configset
function checks.updateScriptConfig(script_key, subdir, new_config, additional_filters)
   local configset = checks.getConfigset()
   local script_type = checks.getScriptType("flow")
   new_config = new_config or {}
   local applied_config = {}

   local script_type = checks.getScriptType(subdir)
   local script = checks.loadModule(interface.getId(), script_type, subdir, script_key)

   if(script) then
      -- Try to validate the configuration
      for hook, conf in pairs(new_config) do
	 local valid = true
         local rv_or_err = ""

	 if(conf.enabled == nil) then
	    return false, "Missing 'enabled' item"
	 end

	 if(conf.script_conf == nil) then
	    return false, "Missing 'script_conf' item"
	 end

	 if conf.enabled then
	    valid, rv_or_err = script.template:parseConfig(conf.script_conf)
	 else
	    -- Assume the config is valid when the script is disabled to simplify the check
	    valid = true
	    rv_or_err = conf.script_conf
	 end

	 if(not valid) then
	    return false, rv_or_err
	 end

	 -- The validator may have changed the configuration
	 conf.script_conf = rv_or_err
	 applied_config[hook] = conf
      end
   end

   local config = configset.config

   -- Creating the filters conf if necessary
   if not configset["filters"] then
      configset["filters"] = {}
   end
   if not configset["filters"][subdir] then
      configset["filters"][subdir] = {}
   end
   if not configset["filters"][subdir][script_key] then
      configset["filters"][subdir][script_key] = {}
   end

   local filter_conf = configset["filters"][subdir][script_key]

   ------------------------------------

   config[subdir] = config[subdir] or {}

   if script then
      local prev_config = config[subdir][script_key]

      -- Perform hook callbacks for config changes, or enable/disable
      for hook, hook_config in pairs(prev_config) do
	 local hook_applied_config = applied_config[hook]

	 if hook_applied_config then
	    if script.onDisable and hook_config.enabled and not hook_applied_config.enabled then
	       -- Hook previously disabled has been enabled
	       script.onDisable(hook, hook_applied_config, confid)
	    elseif script.onEnable and not hook_config.enabled and hook_applied_config.enabled then
	       -- Hook previously enabled has now been disabled
	       script.onEnable(hook, hook_applied_config, confid)
	    elseif script.onUpdateConfig and not table.compare(hook_config, applied_config[hook]) then
	       -- Configuration for the hook has changed
	       script.onUpdateConfig(hook, hook_applied_config, confid)
	    end
	 end
      end
   end

   -- Updating the filters
   if script.alert_id and additional_filters and (subdir == "host" or subdir == "flow") then
      if subdir == "host" then
	 local current_filters = alert_exclusions.host_alerts_get_excluded_hosts(script.alert_id)

	 -- Add new filters
	 for _, new_filter in pairs(additional_filters["new_filters"] or {}) do
	    local new_ip = new_filter["ip"]

	    if not current_filters[new_ip] then
	       -- Not an already-added filter
	       alert_exclusions.disable_host_alert(new_ip, script.alert_id)
	    else
	       -- Filter was already added, nothing to do
	       current_filters[new_ip] = nil
	    end
	 end

	 -- Here we have leftovers, that is, previously added filters that should
	 -- be removed as they don't appear in the new filters
	 for current_ip, _ in pairs(current_filters or {}) do
	    alert_exclusions.enable_host_alert(current_ip, script.alert_id)
	 end
      elseif subdir == "flow" then
	 local current_filters = alert_exclusions.flow_alerts_get_excluded_hosts(script.alert_id)

	 -- Add new filters (see above for hosts)
	 for _, new_filter in pairs(additional_filters["new_filters"] or {}) do
	    local new_ip = new_filter["ip"]

	    if not current_filters[new_ip] then
	       -- Not an already-added filter
	       alert_exclusions.disable_flow_alert(new_ip, script.alert_id)
	    else
	       -- Filter was already added, nothing to do
	       current_filters[new_ip] = nil
	    end
	 end

	 -- See above for flows
	 for current_ip, _ in pairs(current_filters or {}) do
	    alert_exclusions.enable_flow_alert(current_ip, script.alert_id)
	 end
      end
   elseif additional_filters then
      local new_filter_conf = filter_conf
      
      if not new_filter_conf["filter"] then
	 new_filter_conf["filter"] = {}
      end
      
      if not new_filter_conf["filter"]["current_filters"] then
	 new_filter_conf["filter"]["current_filters"] = {}
	 new_filter_conf["filter"]["current_filters"] = (checks.getDefaultFilters(interface.getId(), subdir, script_key))["current_filters"] or {}
      end

      -- If filter reset requested, clear all the filters
      if additional_filters["reset_filters"] == "true" then
	 new_filter_conf["filter"]["current_filters"] = {}
      end

      if table.len(additional_filters) == 0 then
	 new_filter_conf["filter"]["current_filters"] = {}
      else
	 -- There can be multiple filters, so cycle through them
	 for _, new_filter in pairs(additional_filters["new_filters"]) do
	    local add_params = filterIsEqual(new_filter_conf["filter"]["current_filters"], new_filter)
	    if add_params > 0 then
	       new_filter_conf["filter"]["current_filters"][add_params] = new_filter
	    end
	 end
      end

      -- Updating the configuration
      configset["filters"][subdir][script_key] = new_filter_conf
   end
   
   if table.len(applied_config) > 0 then
      -- Set the new configuration
      config[subdir][script_key] = applied_config
   end
      
   return saveConfigset(configset)
end

-- ##############################################

-- @brief Toggles script `script_key` configuration on or off depending on `enable` for configuration `configset`
--        Hooks onDisable and onEnable are called.
-- @param configset A user script configuration, obtained with checks.getConfigset()
-- @param script_key The string script identifier
-- @param subdir The string identifying the sub directory (e.g., flow, host, ...)
-- @param enable A boolean indicating whether the script shall be toggled on or off
local function toggleScriptConfigset(configset, script_key, subdir, enable)
   local script_type = checks.getScriptType(subdir)
   local script = checks.loadModule(interface.getId(), script_type, subdir, script_key)

   if not script then
      return false, i18n("configsets.unknown_check", {check=script_key})
   end

   local config = checks.getScriptConfig(configset, script, subdir)
   
   if config then
      for hook, hook_config in pairs(config) do
	 -- Remember the previous toggle
	 local prev_hook_config = hook_config.enabled
	 -- Save the new toggle
	 hook_config.enabled = enable

	 if script.onDisable and prev_hook_config and not enable then
	    -- Hook has been enabled for the user script
	    script.onDisable(hook, hook_config)
	 elseif script.onEnable and not prev_hook_config and enable then
	    -- Hook has been disabled for the user script
	    script.onEnable(hook, hook_config)
	 end
      end
   end

   if not configset["config"][subdir][script_key] then
      configset["config"][subdir][script_key] = {}
      configset["config"][subdir][script_key] = config
   end				    

   return true
end

-- ##############################################

function checks.toggleScript(script_key, subdir, enable)
   local configset = checks.getConfigset()

   -- Toggle the configuration (result is put in `configset`)
   local res, err = toggleScriptConfigset(configset, script_key, subdir, enable)
   if not res then
      return res, err
   end

   -- If the toggle has been successful, write the new configset and return
   return saveConfigset(configset)
end

-- ##############################################

function checks.toggleAllScripts(subdir, enable)
   local configset = checks.getConfigset()

   -- Toggle the configuration (result is put in `configset`)
   local scripts = checks.load(getSystemInterfaceId(), checks.getScriptType(subdir), subdir)

   for script_name, script in pairs(scripts.modules) do
      -- Toggle each script individually
      local res, err = toggleScriptConfigset(configset, script.key, subdir, enable)
      if not res then
	 return res, err
      end
   end

   -- If the toggle has been successful for all scripts, write the new configset and return
   return saveConfigset(configset)
end

-- ##############################################

-- @brief Returns the factory checks configuration
--        Any user-submitted conf param is ignored
function checks.getFactoryConfig()
   local ifid = getSystemInterfaceId()
   local default_conf = {}

   for type_id, script_type in pairs(checks.script_types) do
      for _, subdir in pairs(script_type.subdirs) do
	 local scripts = checks.load(ifid, script_type, subdir, {return_all = true})

	 for key, usermod in pairs(scripts.modules) do
	    default_conf[subdir] = default_conf[subdir] or {}
	    default_conf[subdir][key] = default_conf[subdir][key] or {}
	    local script_config = default_conf[subdir][key]
	    local hooks = ternary(script_type.has_per_hook_config, usermod.hooks, {[ALL_HOOKS_CONFIG_KEY]=1})

	    for hook in pairs(hooks) do
	       script_config[hook] = {
		  enabled = usermod.default_enabled or false,
		  script_conf = usermod.default_value or {},
	       }
	    end
	 end
      end
   end

   local res = {
      id = checks.DEFAULT_CONFIGSET_ID,
      name = i18n("policy_presets.default"),
      config = default_conf,
   }

   return res
end

-- ##############################################

-- @brief Migrate old configurations, if any
function checks.migrateOldConfig()

   -- Check if there is a v3 already
   local configset_v3 = ntop.getCache(CONFIGSET_KEY)
   if isEmptyString(configset_v3) then

      -- Check if there is a v2
      local CONFIGSETS_KEY_V2 = "ntopng.prefs.checks.configsets_v2"
      local configsets_v2 = ntop.getHashAllCache(CONFIGSETS_KEY_V2)
      if configsets_v2 then

         -- Migrate v2 to v3
         local default_confset_json = configsets_v2["0"]
	 if default_confset_json then
            ntop.setCache(CONFIGSET_KEY, default_confset_json)
         end

	 -- Remove v2
         ntop.delCache(CONFIGSETS_KEY_V2)
      end
   end

end

-- ##############################################

-- @brief Initializes a default configuration for checks
-- @param overwrite If true, a possibly existing configuration is overwritten with default values
function checks.initDefaultConfig()
   local ifid = getSystemInterfaceId()

   -- Current (possibly not-existing, not yet created configset)
   local configset = checks.getConfigset() or {}
   -- Default per user-script configuration
   local default_conf = configset.config or {}
   -- Default per user-script filters
   local default_filters = configset.filters or {}

   for type_id, script_type in pairs(checks.script_types) do
      for _, subdir in pairs(script_type.subdirs) do
	 local scripts = checks.load(ifid, script_type, subdir, {return_all = true})

	 for key, usermod in pairs(scripts.modules) do
	    -- Cleanup exclusion counters
	    ntop.delCache(string.format(NUM_FILTERED_KEY, subdir, key))

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

	    if usermod.filter and usermod.filter.default_filters then
	       default_filters[subdir] = default_filters[subdir] or {}

	       if not default_filters[subdir][key] then
		  -- Do not override filter of an existing configuration
		  default_filters[subdir][key] = usermod.filter.default_filters
	       end
	    end
	 end
      end
   end
   
   -- This is the new configset with all defaults
   local configset = {
      config = default_conf,
      filters = default_filters,
   }

   saveConfigset(configset)  
end

-- ##############################################

function checks.resetConfigset()
   cached_config_set = nil
   ntop.delCache(CONFIGSET_KEY)
   checks.initDefaultConfig()

   return(true)
end

-- ##############################################

-- Returns true if a system script is enabled for some hook
function checks.isSystemScriptEnabled(script_key)
   -- Verify that the script is currently available
   local k = "ntonpng.cache.checks.available_system_modules." .. script_key
   local available = ntop.getCache(k)

   if(isEmptyString(available)) then
      local m = checks.loadModule(getSystemInterfaceId(), checks.script_types.system, "system", script_key)
      available = (m ~= nil)

      ntop.setCache(k, ternary(available, "1", "0"))
   else
      available = ternary(available == "1", true, false)
   end

   if(not available) then
      return(false)
   end

   -- Here the configuration is update with the exclusion list for the alerts
   local configset = checks.getConfigset()
   local default_config = checks.getConfig(configset, "system")
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
function checks.getScriptConfig(configset, script, subdir)
   local script_key = script.key
   local config = configset.config[subdir]

   if(config[script_key]) then
      -- A configuration was found
      return(config[script_key])
   end

   -- Default
   local rv = {}
   local script_type = checks.getScriptType(subdir)
   local hooks = ternary(script_type.has_per_hook_config, script.hooks, {[ALL_HOOKS_CONFIG_KEY]=1})

   for hook in pairs(script.hooks or {}) do
      rv[hook] = default_config
   end

   return(rv)
end

-- ##############################################

-- @brief Retrieves the configuration of a specific hook of the target
-- @param target_config target configuration as returned by
-- checks.getTargetConfig/checks.getHostTargetConfigset
function checks.getTargetHookConfig(target_config, script, hook)
   local script_conf = target_config[script.key or script]

   if not hook then
      -- See has_per_hook_config
      hook = ALL_HOOKS_CONFIG_KEY
   end

   if(not script_conf) then
      return(default_config)
   end

   local conf = script_conf[hook] or default_config
   local default_values = script.default_value or {}
	
   -- Each new default value will be added to the conf.script_conf table
   -- in this way if future values need to be added here there won't be problems
   for key, value in pairs(default_values) do
      if not conf.script_conf[key] then
         conf.script_conf[key] = value
      end
   end

   local default_filter_table = script.filter or {}
   local default_filter_suppression = {}

   -- Checking if filters are configured by default
   if default_filter_table then
      conf.script_conf["filter"] = {}
      default_filter_suppression = default_filter_table.default_filter or {}
   end
   

   return conf
end

-- ##############################################

-- @brief Retrieve a `subdir` configuration from the configset identified with `confset_id` from all the available `configsets` passed
function checks.getConfig(configset, subdir)
   if configset and configset["config"] and configset["config"][subdir] then
      return configset["config"][subdir]
   end

   return {}, nil
end

-- ##############################################

-- @brief Retrieve `subdir` filters from the configset
function checks.getFilters(configset, subdir)
   if configset and configset["filters"] and configset["filters"][subdir] then
      return configset["filters"][subdir]
   end

   return {}, nil
end

-- ##############################################

function checks.getScriptEditorUrl(script)
   if(script.edition == "community" and script.source_path) then
       local plugin_file_path = string.sub(script.source_path, string.len(dirs.scriptdir) + 1)
       local plugin_path = string.sub(script.plugin.path, string.len(dirs.scriptdir) + 1)
       return(string.format("%s/lua/code_viewer.lua?plugin_file_path=%s&plugin_path=%s", ntop.getHttpPrefix(), plugin_file_path, plugin_path))
   end

   return(nil)
end

-- ##############################################

-- @brief Returns the list of the default filters of a specific alert
function checks.getFilterPreset(alert, alert_info)
   local alert_generation = alert_info["alert_generation"]
   
   if not alert_generation then
      return ''
   end

   local subdir           = alert_generation["subdir"]
   local subdir_id        = getSubdirId(subdir)

   if subdir_id == -1 then
      return ''
   end

   if not available_subdirs[subdir_id]["filter"] then
      return ''
   end

   local filter_to_use = {}

   if available_subdirs[subdir_id]["filter"]["default_fields"] then
      filter_to_use = available_subdirs[subdir_id]["filter"]["default_fields"]
   end

   local filter_table = {}
   local index        = 1

   for _, field in pairs(filter_to_use) do
      -- Check for field existance in the alert
      local field_val = alert[field]

      -- If the filed does not exist, try and look it up inside `alert_info`, that is,
      -- a decoded JSON table containing variable alert data.
      if not field_val then
	 field_val = alert_info[field]
      end

      if field_val then
	 -- Forming the string e.g. srv_addr=1.1.1.1
	 filter_table[index] = field .. "=" .. field_val
	 index = index + 1
      end
   end

   -- Creating the required string to print into the GUI
   return table.concat(filter_table, ",")
end

-- #################################

-- @bief Given an already validated filter, returns a SQLite WHERE clause matching all filter fields
-- @param configset A user script configuration, obtained with checks.getConfigset()
-- @param subdir the modules subdir
-- @param check The string script identifier
-- @param filter An already validated user script filter
-- @return A string with the SQLite WHERE clause
function checks.prepareFilterSQLiteWhere(subdir, check, filter)
   -- Access the alert_json using SQLite `json_` functions to properly filter with fields
   local filters_where = {}

   -- This is to match elements inside the alert_json
   local script_where = {
      string.format("json_extract(alert_json, '$.alert_generation.subdir') = '%s'", subdir),
      string.format("json_extract(alert_json, '$.alert_generation.script_key') = '%s'", check),
   }

   -- Now prepare each SQLite statement for every field
   local subdir_id = getSubdirId(subdir)

   -- Retrieving the available filters for the subdir. e.g. flow subdir
   local available_fields = available_subdirs[subdir_id]["filter"]["available_fields"]

   for field_key, field_val in pairs(filter) do
      if available_fields[field_key] and available_fields[field_key]["sqlite"] then
	 local sqlite = available_fields[field_key]["sqlite"](field_val)
	 filters_where[#filters_where + 1] = sqlite
      end
   end

   -- Concatenate
   local where = table.merge(filters_where, script_where)
   -- And merge everything with ANDs
   where = table.concat(where, " AND ")

   return where
end

-- #################################

function checks.parseFilterParams(additional_filters, subdir, reset_filters)
   local separator   = ";"
   local filter_list = {}
   local param_list  = {}

   -- Empty string given, error
   if isEmptyString(additional_filters) then
      return false, i18n("invalid_filters.empty")
   end
   
   -- Sanity Check, Sometimes js puts a "_" or a ";" at the end of the string so removes them
   if additional_filters:match("(.*)_$") or additional_filters:match("(.*);$") then
      additional_filters = additional_filters:sub(1, -2)
   end

   additional_filters = additional_filters:gsub(" ", "")

   if reset_filters == true then
      filter_list["reset_filters"] = "true"
   end

   filter_list["new_filters"] = {}
   param_list = filter_list["new_filters"]
   
   -- Splitting on the ";" - ";" is used to remove "\n" from js
   local ex_list = split(additional_filters, separator)
   local subdir_id = getSubdirId(subdir)
   
   if subdir_id == -1 then
      return false, i18n("invalid_filters.invalid_subdir")
   end

   -- Retrieving the available filters for the subdir. e.g. flow subdir
   local available_fields = available_subdirs[subdir_id]["filter"]["available_fields"]

   for filter_num, filter in pairs(ex_list) do
      separator  = ","
      -- Splitting the filters
      local parameters = split(filter, separator)

      for _,field in pairs(parameters) do
	 if field ~= "" then
	    separator        = "="
	    -- Splitting filter name and filter value
	    local field_key_value = split(field, separator)

	    -- Checking that for each filter a key and a value is given
	    if not table.len(field_key_value) == 2 then
	       return false, i18n("invalid_filters.few_args", {args=field})
	    end

	    local field_key   = field_key_value[1]
	    local field_value = field_key_value[2]

	    -- Getting the http_lint for the selected param, if no param is found
	    -- then the filter is not correct

	    if not available_fields[field_key] or not available_fields[field_key]["lint"] or not available_fields[field_key]["lint"](field_value) then
	       return false, i18n("invalid_filters.incorrect_args", {args=field})
	    end

	    if not param_list[filter_num] then
	       param_list[filter_num] = {}
	    end

	    -- Already added this param before, so 2 identical arguments given
	    if param_list[filter_num][field_key] then
	       return false, i18n("invalid_filters.double_arg", {args=field})
	    end

	    param_list[filter_num][field_key] = field_value
	 end
      end
   end

   return true, filter_list
end

-- ##############################################

-- @brief This function is going to check if the user script needs to be excluded
--        from the list, due to not having filters or not
function checks.excludeScriptFilters(alert, alert_json, script_key, subdir)
   local configset = checks.getConfigset()

   -- Getting the configuration
   local config = configset["filters"]

   if not config then
      return false
   end

   -- Security checks
   local conf = config[subdir]

   if not conf then
      return false
   end

   conf = conf[script_key]

   if not conf then
      return false
   end
   
   local applied_filter_config = {}
   local subdir_id = getSubdirId(subdir)
   
   -- Checking if the script has the field "filter.current_filters"
   if conf["filter"] then
      applied_filter_config = conf["filter"]["current_filters"]
   end

   if not applied_filter_config then
      return false
   end
   
   -- Cycling through the filters
   for _, values in pairs(applied_filter_config) do
      local done = true
      -- Getting the keys and values of the filters. e.g. filter=src_port, value=3900
      for filter, value in pairs(values) do
	 -- Possible strange pattern, so using the function find,
	 -- defined into the available field to check the presence of the data
	 local find_value = available_subdirs[subdir_id]["filter"]["available_fields"][filter]["find"]
	 if not find_value(alert, alert_json, filter, value) then
	    -- The alert has a different value for that filter
	    done = false
	    goto continue2
	 end
	 ::continue::
      end
      
      -- if 
      if done then
	 return true
      end

      ::continue2::
   end

   -- all the filters are correct, exclude the alert
   return false
end

-- ##############################################

function checks.getDefaultFilters(ifid, subdir, script_key)

   local script_type = checks.getScriptType(subdir)
   local script = checks.loadModule(ifid, script_type, subdir, script_key)
   local filters = {}
   filters["current_filters"] = {}

   if script["filter"] and script["filter"]["default_filters"] then
      filters["current_filters"] = script["filter"]["default_filters"] 
   end

   return filters
end


-- ##############################################

local function printUserScriptsTable()
   local ifid = interface.getId()

    for _, info in ipairs(checks.listSubdirs()) do
        local scripts = checks.load(ifid, checks.getScriptType(info.id), info.id, {return_all = true})

        for name, script in pairsByKeys(scripts.modules) do
            local available = ""
            local filters = {}
            local hooks = {}

            -- Hooks
            for hook in pairsByKeys(script.hooks) do
              hooks[#hooks + 1] = hook
            end
            hooks = table.concat(hooks, ", ")

            -- Filters
            if(script.l4_proto) then filters[#filters + 1] = "l4_proto=" .. script.l4_proto end
            if(script.l7_proto) then filters[#filters + 1] = "l7_proto=" .. script.l7_proto end
            if(script.packet_interface_only) then filters[#filters + 1] = "packet_interface" end
            if(script.three_way_handshake_ok) then filters[#filters + 1] = "3wh_completed" end
            if(script.local_only) then filters[#filters + 1] = "local_only" end
            if(script.nedge_only) then filters[#filters + 1] = "nedge=true" end
	    if(script.nedge_exclude) then filters[#filters + 1] = "nedge=false" end
            filters = table.concat(filters, ", ")

            if (name == "my_custom_script") then
              goto skip
            end

            -- Availability
            if(script.edition == "enterprise_m") then
              available = "Enterprise M"
            elseif(script.edition == "enterprise_l") then
              available = "Enterprise L"
            elseif(script.edition == "pro") then
              available = "Pro"
            else
              available = "Community"
            end

            local edit_url = checks.getScriptEditorUrl(script)

            if(edit_url) then
              edit_url = ' <a title="'.. i18n("plugins_overview.action_view") ..'" href="'.. edit_url ..'" class="btn btn-sm btn-secondary" ><i class="fas fa-eye"></i></a>'
            end

            print(string.format(([[
                <tr>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td class="text-end">%u</td>
                    <td class="text-center">%s</td></tr>
                ]]), name, info.label, available, hooks, filters, script.num_filtered, edit_url or ""))
            ::skip::
          end
    end
end


-- #######################################################

function checks.printUserScripts()
   print([[
            <div class='col-12 my-3'>
                <table class='table table-bordered table-striped' id='user-scripts'>
                    <thead>
                        <tr>
                            <th>]].. i18n("plugins_overview.script") ..[[</th>
                            <th>]].. i18n("plugins_overview.type") ..[[</th>
                            <th>]].. i18n("availability") ..[[</th>
                            <th>]].. i18n("plugins_overview.hooks") ..[[</th>
                            <th>]].. i18n("plugins_overview.filters") ..[[</th>
                            <th>]].. i18n("plugins_overview.filtered") ..[[</th>
                            <th>]].. i18n("action") ..[[</th>
                        </tr>
                    </thead>
                    <tbody>]])
   printUserScriptsTable()
   print([[
                    </tbody>
                </table>
        </div>
    <link href="]].. ntop.getHttpPrefix() ..[[/css/dataTables.bootstrap5.min.css" rel="stylesheet"/>
    <script type='text/javascript'>

    $(document).ready(function() {

        const addFilterDropdown = (title, values, column_index, datatableFilterId, tableApi) => {

            const createEntry = (val, callback) => {
                const $entry = $(`<li class='dropdown-item pointer'>${val}</li>`);
                $entry.click(function(e) {

                    $dropdownTitle.html(`<i class='fas fa-filter'></i> ${val}`);
                    $menuContainer.find('li').removeClass(`active`);
                    $entry.addClass(`active`);
                    callback(e);
                });

                return $entry;
            }

            const dropdownId = `${title}-filter-menu`;
            const $dropdownContainer = $(`<div id='${dropdownId}' class='dropdown d-inline'></div>`);
            const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-bs-toggle='dropdown' type='button'></button>`);
            const $dropdownTitle = $(`<span>${title}</span>`);
            $dropdownButton.append($dropdownTitle);

            const $menuContainer = $(`<ul class='dropdown-menu' id='${title}-filter'></ul>`);
            values.forEach((val) => {
                const $entry = createEntry(val, (e) => {
                    tableApi.columns(column_index).search(val).draw(true);
                });
                $menuContainer.append($entry);
            });

            const $allEntry = createEntry(']].. i18n('all') ..[[', (e) => {
                $dropdownTitle.html(`${title}`);
                $menuContainer.find('li').removeClass(`active`);
                tableApi.columns().search('').draw(true);
            });
            $menuContainer.prepend($allEntry);

            $dropdownContainer.append($dropdownButton, $menuContainer);
            $(datatableFilterId).prepend($dropdownContainer);
        }

        const $userScriptsTable = $('#user-scripts').DataTable({
            pagingType: 'full_numbers',
            initComplete: function(settings) {

                const table = settings.oInstance.api();
                const types = [... new Set(table.columns(1).data()[0].flat())];
                const availability = [... new Set(table.columns(2).data()[0].flat())];

                addFilterDropdown(']].. i18n("availability") ..[[', availability, 2, "#user-scripts_filter", table);
                addFilterDropdown(']].. i18n("plugins_overview.type") ..[[', types, 1, "#user-scripts_filter", table);
            },
            pageLength: 25,
            language: {
                info: "]].. i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'}) ..[[",
                search: "]].. i18n('search') ..[[:",
                infoFiltered: "",
                paginate: {
                    previous: '&lt;',
                    next: '&gt;',
                    first: '«',
                    last: '»'
                },
            },
        });

    });

    </script>
]])

end

-- ##############################################

return(checks)
