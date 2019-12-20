--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

local do_benchmark = true          -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local available_modules = nil
local system_ts_enabled = nil
local system_config = nil

-- #################################################################

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end

   interface.select(getSystemInterfaceId())
   ifid = interface.getId()
   local ifname = getInterfaceName(tostring(ifid))

   system_ts_enabled = (ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0")

   -- Load the threshold checking functions
   available_modules = user_scripts.load(ifid, user_scripts.script_types.system, "system", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })

   local configsets = user_scripts.getConfigsets("system")
   system_config = configsets[user_scripts.DEFAULT_CONFIGSET_ID]
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

-- The function below is called once
function runScripts(granularity)
  if table.empty(available_modules.hooks[granularity]) then
    if(do_trace) then print("system:runScripts("..granularity.."): no modules, skipping\n") end
    return
  end

  local granularity_id = alert_consts.alerts_granularities[granularity].granularity_id
  local suppressed_alerts = false
  local when = os.time()
  --~ local cur_alerts = host.getAlerts(granularity_id)
  -- TODO use system_config

  for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
    local user_script = available_modules.modules[mod_key]
    local conf = user_scripts.getConfiguration(user_script, granularity)

    if(conf.enabled) then
      if((not user_script.is_alert) or (not suppressed_alerts)) then
        hook_fn({
           granularity = granularity,
           alert_config = conf.script_conf,
           user_script = user_script,
           when = when,
           ts_enabled = system_ts_enabled,
	   --cur_alerts = cur_alerts
        })
      end
    end
  end

  -- cur_alerts now contains unprocessed triggered alerts, that is,
  -- those alerts triggered but then disabled or unconfigured (e.g., when
  -- the user removes a threshold from the gui)
  --~ if #cur_alerts > 0 then
     --~ alerts_api.releaseEntityAlerts(entity_info, cur_alerts)
  --~ end
end
