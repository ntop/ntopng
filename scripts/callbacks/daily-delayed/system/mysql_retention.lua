--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"

-- ########################################################

local verbose = ntop.verboseTrace()

-- ###########################################

if scripts_triggers.isDumpFlowToSQLEnabled(ifstats) then
   local db_utils = require "db_utils"
   local data_retention_utils = require "data_retention_utils"
   local iface_names = interface.getIfNames()
   local data_retention = data_retention_utils.getDataRetentionDays()
   local mysql_retention = os.time() - 86400 * data_retention
   
   for _,ifname in pairs(iface_names) do
      db_utils.harverstExpiredMySQLFlows(ifname, mysql_retention, verbose)
   end
end
