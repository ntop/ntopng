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

-- DEBUG: benchmarks local to the execution of this script
-- Will be removed once all the host.<method> calls will be performed
-- inside the custom scripts
local do_script_benchmark = false
local script_benchmark_begin_time
local script_benchmark_tot_clock = 0
local script_benchmark_tot_calls = 0

local available_modules = nil
local ifid = nil
local host_entity = alert_consts.alert_entities.host.entity_id

-- #################################################################

local function benchmark_begin()
   if do_benchmark then
      script_benchmark_begin_time = os.clock()
   end
end

-- #################################################################

local function benchmark_end()
   if do_benchmark then
      script_benchmark_tot_clock = script_benchmark_tot_clock + os.clock() - script_benchmark_begin_time
      script_benchmark_tot_calls = script_benchmark_tot_calls + 1
   end
end

-- #################################################################

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if(do_trace) then print("alert.lua:setup("..str_granularity..") called\n") end
   ifid = interface.getId()
   local ifname = interface.setActiveInterfaceId(ifid)

   -- Load the threshold checking functions
   available_modules = user_scripts.load(ifid, user_scripts.script_types.traffic_element, "host", {
      hook_filter = str_granularity,
      do_benchmark = do_benchmark,
   })
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   if do_script_benchmark and script_benchmark_tot_calls > 0 then
      traceError(TRACE_NORMAL,TRACE_CONSOLE, string.format("[tot_elapsed: %.4f][tot_num_calls: %u][avg time per call: %.4f]",
      							   script_benchmark_tot_clock,
							   script_benchmark_tot_calls,
							   script_benchmark_tot_clock / script_benchmark_tot_calls))
   end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

-- The function below is called once per host
function runScripts(granularity)
  if table.empty(available_modules.hooks[granularity]) then
    if(do_trace) then print("host:runScripts("..granularity.."): no modules, skipping\n") end
    return
  end

  local host_ip = host.getIp()
  local host_key   = hostinfo2hostkey({ip = host_ip.ip, vlan = host_ip.vlan}, nil, true --[[ force @[vlan] even when vlan is 0 --]])
  local granularity_id = alert_consts.alerts_granularities[granularity].granularity_id
  local suppressed_alerts = alerts_api.hasSuppressedAlerts(ifid, host_entity, host_key)

  if suppressed_alerts then
     releaseAlerts(granularity_id)
  end

  benchmark_begin()
  local cur_alerts = host.getAlerts(granularity_id)
  local is_localhost = host.getLocalhostInfo()["localhost"]
  benchmark_end()

  local entity_info = alerts_api.hostAlertEntity(host_ip.ip, host_ip.vlan)

  for mod_key, hook_fn in pairs(available_modules.hooks[granularity]) do
    local user_script = available_modules.modules[mod_key]
    local conf = user_scripts.getConfiguration(user_script, granularity, host_key, not is_localhost)

    if(conf.enabled) then
      if((not user_script.is_alert) or (not suppressed_alerts)) then
        hook_fn({
           granularity = granularity,
           alert_entity = entity_info,
           entity_info = host_ip,
           cur_alerts = cur_alerts,
           alert_config = conf.script_conf,
           user_script = user_script,
        })
      end
    end
  end

  -- cur_alerts now contains unprocessed triggered alerts, that is,
  -- those alerts triggered but then disabled or unconfigured (e.g., when
  -- the user removes a threshold from the gui)
  if #cur_alerts > 0 then
     alerts_api.releaseEntityAlerts(entity_info, cur_alerts)
  end
end

-- #################################################################

function releaseAlerts(granularity)
  local host_ip = host.getIp()
  local entity_info = alerts_api.hostAlertEntity(host_ip.ip, host_ip.vlan)

  alerts_api.releaseEntityAlerts(entity_info, host.getAlerts(granularity))
end
