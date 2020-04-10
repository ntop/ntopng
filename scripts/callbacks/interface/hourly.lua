--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
local callback_utils = require "callback_utils"
local user_scripts = require("user_scripts")

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
  require('hourly')
end

-- ########################################################

local verbose = ntop.verboseTrace()
local ifstats = interface.getStats()
local _ifname = ifstats.name

-- ########################################################

user_scripts.runPeriodicScripts("hour")
