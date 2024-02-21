--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local do_am = ntop.getPrefs().active_monitoring
if (not do_am) then
  -- exit if am is disabled
  return
end

local ts_dump = require "ts_min_dump_utils"
local am_utils = require  "am_utils"

local hosts = am_utils.getHosts(nil, "hour")
am_utils.run_am_check(os.time(), hosts, "hour")
