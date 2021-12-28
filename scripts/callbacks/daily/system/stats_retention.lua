--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local scripts_triggers    = require "scripts_triggers"
local auth_sessions_utils = require "auth_sessions_utils"

-- ########################################################

-- Delete JSON files older than a 30 days
-- TODO: make 30 configurable
harvestJSONTopTalkers(30)

-- Delete user session
auth_sessions_utils.midnightCheck()

-- Reset host/mac statistics
if scripts_triggers.midnightStatsResetEnabled() then
   ntop.resetStats()
end
