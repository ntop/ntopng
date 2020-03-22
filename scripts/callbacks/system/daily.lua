--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local auth_sessions_utils = require "auth_sessions_utils"
local blog_ntop = require("blog_ntop")

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

blog_ntop.fetchLatestPosts()

-- Run hourly scripts
ntop.checkSystemScriptsDay()
