--
-- (C) 2019 - ntop.org
--
-- The functions below are called with a LuaC "flow" context set.
-- See user_scripts.load() documentation for information
-- on adding custom scripts.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "alert_utils"
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")
local flow_consts = require("flow_consts")
local json = require("dkjson")
local alerts_api = require("alerts_api")

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

local do_benchmark = true          -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls
local calculate_stats = false

local available_modules = nil
local benchmarks = {}

-- Keeps information about the current predominant alerted status
local alerted_status
local alerted_status_msg
local alerted_custom_severity
local predominant_status
local recalculate_predominant_status
local hosts_disabled_status

-- Save them as they are overridden
local c_flow_set_status = flow.setStatus
local c_flow_clear_status = flow.clearStatus

local stats = {
   num_invocations = 0, 	-- Total number of invocations of this module
   num_complete_scripts = 0,	-- Number of invoked scripts on flows with THW completed
   num_partial_scripts = 0,	-- Number of invoked scripts on flows with THW not-completed
   num_try_alerts = 0,  	-- Number of calls to triggerFlowAlert
   partial_scripts = {},	-- List of scripts invoked on flow with THW not-completed
}

-- #################################################################

local function addL4Callaback(l4_proto, hook_name, script_key, callback)
   local l4_scripts = available_modules.l4_hooks[l4_proto]

   if(l4_scripts == nil) then
      l4_scripts = {}
      available_modules.l4_hooks[l4_proto] = l4_scripts
   end

   l4_scripts[hook_name] = l4_scripts[hook_name] or {}
   l4_scripts[hook_name][script_key] = callback
end

-- The function below is called once (#pragma once)
function setup()
   if do_trace then print("flow.lua:setup() called\n") end

   local ifid = interface.getId()

   -- Load the disabled hosts status
   hosts_disabled_status = alerts_api.getAllHostsDisabledStatusBitmaps(ifid)

   available_modules = user_scripts.load(user_scripts.script_types.flow, ifid, "flow", nil, nil, do_benchmark)

   -- Reorganize the modules to optimize lookup by L4 protocol
   -- E.g. l4_hooks = {tcp -> {periodicUpdate -> {check_tcp_retr}}, other -> {protocolDetected -> {mud, score}}}
   available_modules.l4_hooks = {}

   for hook_name, hooks in pairs(available_modules.hooks) do
      -- available_modules.l4_hooks
      for script_key, callback in pairs(hooks) do
         local script = available_modules.modules[script_key]

         if(script.l4_proto ~= nil) then
            local l4_proto = l4_proto_to_id(script.l4_proto)

            if(l4_proto == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unknown l4_proto '%s' in module '%s', skipping", script.l4_proto, script_key))
            else
               addL4Callaback(l4_proto, hook_name, script_key, callback)
            end
         else
            -- No l4 filter is active for the specified module
            -- Attach the protocol to all the L4 protocols
            for _, l4_proto in pairs(l4_keys) do
               local l4_proto = l4_proto[3]

               if(l4_proto > 0) then
                  addL4Callaback(l4_proto, hook_name, script_key, callback)
               end
            end
         end
      end
   end
end

-- #################################################################

-- The function below is called once (#pragma once) right before
-- the lua virtual machine is destroyed
function teardown()
   if do_trace then
      print("flow.lua:teardown() called\n")
   end

   if(available_modules ~= nil) then
      user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
   end

   if(calculate_stats) then
      tprint(stats)
   end
end

-- #################################################################

-- @brief Store more information into the flow status. Such information
-- does not depend the specific flow status being triggered
-- @param l4_proto the flow L4 protocol ID
-- @param flow_status the status table to augument
local function augumentFlowStatusInfo(l4_proto, flow_status)
   flow_status["ntopng.key"] = flow.getKey()
   flow_status["hash_entry_id"] = flow.getHashEntryId()

   if(l4_proto == 1 --[[ ICMP ]]) then
      -- NOTE: this information is parsed by getFlowStatusInfo()
      flow_status["icmp"] = flow.getICMPStatusInfo()
   end
end

-- #################################################################

local function triggerFlowAlert(now, l4_proto)
   local cli_key = flow.getClientKey()
   local srv_key = flow.getServerKey()
   local cli_disabled_status = hosts_disabled_status[cli_key] or 0
   local srv_disabled_status = hosts_disabled_status[srv_key] or 0
   local status_id = alerted_status.status_id

   -- Ensure that this status was not disabled by the user on the client/server
   if(((cli_disabled_status ~= 0) and (ntop.bitmapIsSet(cli_disabled_status, status_id))) or
      ((srv_disabled_status ~= 0) and (ntop.bitmapIsSet(srv_disabled_status, status_id)))) then

      if do_trace then
         traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
            "Not triggering flow alert for status %u [cli_bitmap: %s/%d][srv_bitmap: %s/%d]",
            status_id, cli_key, cli_disabled_status, srv_key, srv_disabled_status))
      end

      return(false)
   end

   if do_trace then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("flow.triggerAlert(type=%s, severity=%s)",
         alertTypeRaw(alerted_status.alert_type.alert_id), alertSeverityRaw(alerted_status.alert_severity.severity_id)))
   end

   alerted_status_msg = alerted_status_msg or {}

   if(type(alerted_status_msg) == "table") then
      -- NOTE: porting this to C is not feasable as the lua table can contain
      -- arbitrary data
      augumentFlowStatusInfo(l4_proto, alerted_status_msg)

      -- Need to convert to JSON
      alerted_status_msg = json.encode(alerted_status_msg)
   end

   local triggered = flow.triggerAlert(status_id,
      alerted_status.alert_type.alert_id,
      alerted_custom_severity or alerted_status.alert_severity.severity_id,
      now, alerted_status_msg)

   return(triggered)
end

-- #################################################################

-- Function for the actual module execution. Iterates over available (and enabled)
-- modules, calling them one after one.
-- @param l4_proto the L4 protocol of the flow
-- @param master_id the L7 master protocol of the flow
-- @param app_id the L7 app protocol of the flow
-- @param mod_fn the callback to call
-- @return true if some module was called, false otherwise
local function call_modules(l4_proto, master_id, app_id, mod_fn, update_ctr)
   if calculate_stats then
      stats.num_invocations = stats.num_invocations + 1
   end

   if not(available_modules) then
      return
   end

   local all_modules = available_modules.modules
   local hooks = available_modules.l4_hooks[l4_proto]
   local rv = false
   local prev_predominant_status = flow_consts.getStatusInfo(flow.getPredominantStatus())

   -- Reset predominant status information
   alerted_status = nil
   alerted_status_msg = nil
   alerted_custom_severity = nil
   recalculate_predominant_status = false
   predominant_status = prev_predominant_status

   if(hooks ~= nil) then
      hooks = hooks[mod_fn]
   end

   if(hooks == nil) then
      if do_trace then print(string.format("No flow.lua modules, skipping %s(%d) for %s\n", mod_fn, l4_proto, shortFlowLabel(flow.getInfo()))) end
      return(false)
   end

   if(do_trace) then print(string.format("%s()[START]: bitmap=0x%x predominant=%d", mod_fn, flow.getStatus(), prev_predominant_status.status_id)) end

   local now = os.time()
   local info = nil

   if do_trace then
      info = flow.getInfo()
   end

   local twh_in_progress = ((l4_proto == 6 --[[TCP]]) and (not flow.isTwhOK()))

   for mod_key, hook_fn in pairs(hooks) do
      local script = all_modules[mod_key]

      if(mod_fn == "periodicUpdate") then
	 -- Check if the script should be invoked
	 if((update_ctr % script.periodic_update_divisor) ~= 0) then
	    if do_trace then
	       print(string.format("%s() [check: %s]: skipping periodicUpdate [ctr: %s, divisor: %s, frequency: %s]\n",
		  mod_fn, mod_key, update_ctr, script.periodic_update_divisor, script.periodic_update_seconds))
	    end

	    goto continue
	 end
      end

      -- Check if the script requires the flow to have successfully completed the three-way handshake
      if(script.three_way_handshake_ok and twh_in_progress) then
	 -- Check if the script wants the three way handshake completed
	 if do_trace then
	    print(string.format("%s() [check: %s]: skipping flow with incomplete three way handshake\n", mod_fn, mod_key))
	 end

	 goto continue
      end

      local script_l7 = script.l7_proto_id

      if((script_l7 ~= nil) and (master_id ~= script_l7) and (app_id ~= script_l7)) then
	 if do_trace then
	    print(string.format("%s() [check: %s]: skipping flow with proto=%s/%s [wants: %s]\n", mod_fn, mod_key, master_id, app_id, script_l7))
	 end

	 goto continue
      end

      if calculate_stats then
	 if twh_in_progress then
	    stats.num_partial_scripts = stats.num_partial_scripts + 1
	    stats.partial_scripts[mod_key] = 1
	 else
	    stats.num_complete_scripts = stats.num_complete_scripts + 1
	 end
      end

      if do_trace then
	 print(string.format("%s() [check: %s]: %s\n", mod_fn, mod_key, shortFlowLabel(info)))
      end

      hook_fn(now)
      rv = true

      ::continue::
   end

   if(recalculate_predominant_status) then
      -- The predominant status has changed and we've lost track of it
      -- This is the worst case, it must be recalculated manually
      predominant_status = flow_consts.getPredominantStatus(flow.getStatus())
   end

   if(do_trace) then print(string.format("%s()[END]: bitmap=0x%x predominant=%d", mod_fn, flow.getStatus(), predominant_status.status_id)) end

   if(prev_predominant_status ~= predominant_status) then
      -- The predominant status has changed, updated the flow
      flow.setPredominantStatus(predominant_status.status_id)
   end

   if((alerted_status ~= nil) and flow.canTriggerAlert()) then
      triggerFlowAlert(now, l4_proto)

      if calculate_stats then
	 stats.num_try_alerts = stats.num_try_alerts + 1
      end
   end

   return(rv)
end

-- #################################################################

-- @brief This provides an API that flow user_scripts can call in order to
-- set a flow status bit. The status_json of the predominant status is
-- saved for later use.
function flow.triggerStatus(status_id, status_json, custom_severity)
   local new_status = flow_consts.getStatusInfo(status_id)

   if((alerted_status == nil) or (new_status.prio > alerted_status.prio)) then
      -- The new alerted status as an higher priority
      alerted_status = new_status
      alerted_status_msg = status_json
      alerted_custom_severity = custom_severity -- possibly nil
   end

   -- Call the function below to handle the predominant status and update
   -- the flow status
   flow.setStatus(status_id)
end

-- #################################################################

-- NOTE: overrides the C flow.setStatus (now saved in c_flow_set_status)
function flow.setStatus(status_id)
   if c_flow_set_status(status_id) then
      -- The status has actually changed
      local new_status = flow_consts.getStatusInfo(status_id)

      if(new_status.prio > predominant_status.prio) then
         -- The new status as an higher priority
         predominant_status = new_status
      end
   end
end

-- #################################################################

-- NOTE: overrides the C flow.clearStatus (now saved in c_flow_clear_status)
function flow.clearStatus(status_id)
   if c_flow_clear_status(status_id) then
      -- The status has actually changed
      if(predominant_status.id == status_id) then
         -- The predominant status has been cleared, need to recalculate it
         recalculate_predominant_status = true
      end
   end
end

-- #################################################################

-- Given an L4 protocol, we must call both the hooks registered for that protocol and
-- the hooks registered for any L4 protocol (id 255)
function protocolDetected(l4_proto, master_id, app_id)
   call_modules(l4_proto, master_id, app_id, "protocolDetected")
end

-- #################################################################

function statusChanged(l4_proto, master_id, app_id)
   call_modules(l4_proto, master_id, app_id, "statusChanged")
end

-- #################################################################

function flowEnd(l4_proto, master_id, app_id)
   call_modules(l4_proto, master_id, app_id, "flowEnd")
end

-- #################################################################

function periodicUpdate(l4_proto, master_id, app_id, update_ctr)
   call_modules(l4_proto, master_id, app_id, "periodicUpdate", update_ctr)
end
