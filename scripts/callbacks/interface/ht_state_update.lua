--
-- (C) 2019-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"
require "ts_5sec"
local ts_dump = require "ts_5sec_dump_utils"
local when = os.time()

local skip_user_scripts = false

-- ########################################################

local ht_stats = interface.getHashTablesStats()

local idle_flows   = ht_stats.FlowHash.hash_entry_states.hash_entry_state_idle
local active_flows = ht_stats.FlowHash.hash_entry_states.hash_entry_state_active
local idle_ratio_threshold = 66.
local idle_flows_high_threshold = 100000
local idle_flows_low_threshold  = 1000
local idle_ratio

if(active_flows == 0) then
   idle_ratio = 0
else
   idle_ratio = (100 * idle_flows) / active_flows
end

if(
   (idle_flows > idle_flows_high_threshold)
      or ((idle_ratio > idle_ratio_threshold) and (idle_flows > idle_flows_low_threshold))
) then
   skip_user_scripts = true
   io.write("[ht_state_update.lua] Skipping scripts on ".. interface.getName() ..": [idle ratio: "..idle_ratio.."]["..idle_flows.."/"..active_flows.."]\n")   
end

-- ########################################################

local periodic_ht_state_update_stats = interface.periodicHTStateUpdate(ntop.getDeadline(), skip_user_scripts)
ts_dump.run_5sec_dump(interface.getId(), when, periodic_ht_state_update_stats)

-- ########################################################

