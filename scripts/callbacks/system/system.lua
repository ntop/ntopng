--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local alert_utils = require "alert_utils"

local alerts_api = require("alerts_api")
local checks = require("checks")
local alert_consts = require("alert_consts")

local do_benchmark = false         -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local available_modules = nil
local system_ts_enabled = nil
local system_config = nil
local configset = nil

-- #################################################################

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end

   interface.select(getSystemInterfaceId())
   ifid = interface.getId()
   local ifname = getInterfaceName(tostring(ifid))

   system_ts_enabled = areSystemTimeseriesEnabled()

   -- Load the threshold checking functions
   available_modules = checks.load(ifid, checks.script_types.system, "system", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })

   configset = checks.getConfigset()
   system_config = checks.getConfig(configset, "system")
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   checks.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

-- The function below is called once
function runScripts(granularity)
  if table.empty(available_modules.hooks[granularity]) then
    if(do_trace) then print("system:runScripts("..granularity.."): no modules, skipping\n") end
    return
  end

  -- NOTE: currently no deadline check is explicitly performed here.
  -- The "process:resident_memory" must always be written as it has the
  -- is_critical_ts flag set.

  local granularity_id = alert_consts.alerts_granularities[granularity].granularity_id
  local when = os.time()
  --~ local cur_alerts = host.getAlerts(granularity_id)

  for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
    local check = available_modules.modules[mod_key]
    local conf = checks.getTargetHookConfig(system_config, check, granularity)

    if(conf.enabled) then
       alerts_api.invokeScriptHook(
	  check, configset, hook_fn,
	  {
	     granularity = granularity,
	     alert_entity = alerts_api.interfaceAlertEntity(getSystemInterfaceId()),
	     check_config = conf.script_conf,
	     check = check,
	     when = when,
	     ts_enabled = system_ts_enabled,
	     --cur_alerts = cur_alerts
       })
    end
  end

  -- cur_alerts now contains unprocessed triggered alerts, that is,
  -- those alerts triggered but then disabled or unconfigured (e.g., when
  -- the user removes a threshold from the gui)
  --~ if #cur_alerts > 0 then
     --~ alerts_api.releaseEntityAlerts(entity_info, cur_alerts)
  --~ end
end
