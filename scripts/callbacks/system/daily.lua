--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local auth_sessions_utils = require "auth_sessions_utils"

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require('daily')
end

-- ########################################################

-- Delete JSON files older than a 30 days
-- TODO: make 30 configurable
harvestJSONTopTalkers(30)

auth_sessions_utils.midnightCheck()

if ntop.getPref("ntopng.prefs.midnight_stats_reset_enabled") == "1" then
   -- Reset host/mac statistics
   ntop.resetStats()
end

-- Run hourly scripts
ntop.checkSystemScriptsDay()
