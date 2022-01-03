--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local scripts_triggers = require "scripts_triggers"
local data_retention_utils = require "data_retention_utils"

-- ########################################################

local verbose = ntop.verboseTrace()
local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

local data_retention = data_retention_utils.getDataRetentionDays()

-- ###########################################

if scripts_triggers.isDumpFlowToSQLEnabled(ifstats) then
   local db_utils = require "db_utils"

   local mysql_retention = os.time() - 86400 * data_retention
   db_utils.harverstExpiredMySQLFlows(_ifname, mysql_retention, verbose)
end

