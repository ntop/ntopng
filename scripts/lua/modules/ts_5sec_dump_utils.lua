-- ########################################################

local ts_utils = require("ts_utils_core")
local user_scripts = require("user_scripts")
local ts_dump = {}

-- ########################################################

function ts_dump.iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   for ht_name, ht_stats in pairs(periodic_ht_state_update_stats) do
      local num_calls = 0
      local num_ms = 0

      if ht_stats["stats"] then
	 if ht_stats["stats"]["num_calls"] then
	    num_calls = ht_stats["stats"]["num_calls"]
	 end
	 if ht_stats["stats"]["tot_duration_ms"] then
	    num_ms = ht_stats["stats"]["tot_duration_ms"]
	 end
      end

     ts_utils.append("ht:lua_calls", {ifid = ifid, hash_table = ht_name, num_ms = num_ms, num_calls = num_calls}, when, verbose)
   end
end

-- ########################################################

function ts_dump.update_user_scripts_stats(when, ifid, verbose)
  local all_scripts = {
    flow = user_scripts.listScripts(user_scripts.script_types.flow, "flow"),
    host = user_scripts.listScripts(user_scripts.script_types.traffic_element, "host"),
    interface = user_scripts.listScripts(user_scripts.script_types.traffic_element, "interface"),
    network = user_scripts.listScripts(user_scripts.script_types.traffic_element, "network"),
    syslog = user_scripts.listScripts(user_scripts.script_types.syslog, "syslog"),
  }

  for subdir, rv in pairs(all_scripts) do
    local total = {tot_elapsed = 0, tot_num_calls = 0}

    for _, modkey in pairs(rv) do
      local stats = user_scripts.getAccumulatedStats(ifid, subdir, modkey)

      if(stats) then
        ts_utils.append("user_script:duration", {ifid = ifid, user_script = modkey, subdir = subdir, num_ms = stats.tot_elapsed * 1000}, when, verbose)
	ts_utils.append("user_script:num_calls", {ifid = ifid, user_script = modkey, subdir = subdir, num_calls = stats.tot_num_calls}, when, verbose)

        total.tot_elapsed = total.tot_elapsed + stats.tot_elapsed
        total.tot_num_calls = total.tot_num_calls + stats.tot_num_calls
      end
    end

    ts_utils.append("user_script:total_stats", {ifid = ifid, subdir = subdir, num_ms = total.tot_elapsed * 1000, num_calls = total.tot_num_calls}, when, verbose)
  end
end

-- ########################################################

function ts_dump.run_5sec_dump(ifid, periodic_ht_state_update_stats)
   local iface_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.ifid_"..ifid..".interface_rrd_creation") ~= "false")
      and (ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0")
   local when = os.time()

   if not iface_rrd_creation_enabled then
      return
   end

   ts_dump.iface_update_periodic_ht_state_update_stats(when, ifid, periodic_ht_state_update_stats)
   ts_dump.update_user_scripts_stats(when, ifid, verbose)
end

-- ########################################################

return ts_dump
