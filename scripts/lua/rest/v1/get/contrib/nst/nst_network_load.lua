--
-- ###################################################################################
-- nst_network_load.lua (v2.15)
--
-- NST - 2014, 2015, 2016, 2017, 2018, 2020:
--     Dump selective statistic data for each configured ntopng
--     Network Interface as an array of JSON objects.
--
-- Usage Example:
--   curl --insecure --http0.9 --cookie "user=admin; password=admin" \
--     "https://127.0.0.1:3001/lua/nst_network_load.lua";
--
-- Usage Example (Silent):
--    curl --silent --insecure --http0.9 --cookie "user=admin; password=admin" \
--      "https://127.0.0.1:3001/lua/nst_network_load.lua";
--
-- ###################################################################################

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"

-- sendHTTPHeader('text/html')

-- ################################# FUNCTIONS ########################################
function dumpNtopngStatsData(netint)
  --
  -- Configure stats dump for Network Interface: 'netint'
  interface.select(netint)

  local ifstats = interface.getStats()
  local stats = interface.getFlowsStats()

  if (ifstats ~= nil) then
     uptime = ntop.getUptime()
     prefs = ntop.getPrefs()
     --
     -- Round up...
     hosts_pctg = math.floor(1+((ifstats.stats.hosts*100)/prefs.max_num_hosts))
     flows_pctg = math.floor(1+((ifstats.stats.flows*100)/prefs.max_num_flows))
     --
     num_flow_alerts = alert_utils.getNumAlerts("historical-flows", alert_utils.getTabParameters(_GET,"historical-flows"))
     --
     print('{"interface":"' .. netint .. '","packets":' .. ifstats.stats.packets .. ',"bytes":' .. ifstats.stats.bytes .. ',"drops":' .. ifstats.stats.drops .. ',"alerts":' .. num_flow_alerts ..',"num_flows":' .. ifstats.stats.flows ..',"num_hosts":' .. ifstats.stats.hosts .. ',"epoch":' .. os.time()..',"uptime":"' .. secondsToTime(uptime) .. '","hosts_pctg":' .. hosts_pctg .. ',"flows_pctg":' .. flows_pctg.. '}')
    return
  else
     --
     -- Dump an empty object if interface was not configured...
     print('{}')
    return
  end
end
-- ###################################################################################

-- ####################################### CODE ######################################
--
-- Dump stat data for each configured Network Interface...
ntopngcfgints = interface.getIfNames()
num = 0

print("[")
for id, int in pairs(ntopngcfgints) do
  if (num > 0) then
    print(",")
  else
    num = num + 1
  end
  dumpNtopngStatsData(int)
end
print("]")
