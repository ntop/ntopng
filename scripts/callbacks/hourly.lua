--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "alert_utils"
require "rrd_utils"
local callback_utils = require "callback_utils"

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
  require("hourly")
end

local verbose = ntop.verboseTrace()
local ifnames = interface.getIfNames()

-- Scan "hour" alerts
callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
   scanAlerts("hour", ifstats)
end)

