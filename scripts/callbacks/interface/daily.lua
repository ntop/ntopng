--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"

local callback_utils = require "callback_utils"
local db_utils = require "db_utils"

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
   pcall(require, 'daily')
end

-- ########################################################

local verbose = ntop.verboseTrace()
local ifstats = interface.getStats()
local _ifname = ifstats.name

local mysql_retention = ntop.getCache("ntopng.prefs.mysql_retention")
if((mysql_retention == nil) or (mysql_retention == "")) then mysql_retention = "7" end
mysql_retention = os.time() - 86400*tonumber(mysql_retention)

local minute_top_talkers_retention = ntop.getCache("ntopng.prefs.minute_top_talkers_retention")
if((minute_top_talkers_retention == nil) or (minute_top_talkers_retention == "")) then minute_top_talkers_retention = "365" end

-- ########################################################

local interface_id = getInterfaceId(_ifname)
scanAlerts("day", ifstats)

ntop.deleteMinuteStatsOlderThan(interface_id, tonumber(minute_top_talkers_retention))

db_utils.harverstExpiredMySQLFlows(_ifname, mysql_retention, verbose)

callback_utils.harverstOldRRDFiles(_ifname)

if(interface.getInterfaceDumpDiskPolicy() == true) then
   ntop.deleteDumpFiles(interface_id)
end
